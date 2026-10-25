import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'renewal_editor.dart';
import 'reminder_preview_card.dart';
import 'reminder_draft_card.dart';
import 'control_assessment_card.dart';
import 'control_response_card.dart';
import 'operational_panel.dart';
import 'vencira_select.dart';

/// Una anotación es una póliza externa, no una ficha CRM (whitepaper §6).
class VenciraRenewalDetailScreen extends StatefulWidget {
  const VenciraRenewalDetailScreen({super.key, required this.api,
      required this.workspace, required this.renewalId});
  final VenciraApi api;
  final VenciraWorkspace workspace;
  final String renewalId;

  @override
  State<VenciraRenewalDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<VenciraRenewalDetailScreen> {
  VenciraRenewal? _renewal;
  VenciraFollowUp? _manualFollowUp;
  bool _followUpLoading = false;
  bool _followUpLoaded = false;
  bool _followUpError = false;
  List<VenciraInsurer> _insurers = [];
  VenciraHistoryPage? _history;
  int _page = 1;
  bool _loading = true;
  bool _error = false;
  bool _unauthorized = false;
  bool _historyLoading = false;
  bool _historyError = false;
  bool _saving = false;
  int _generation = 0;
  AppLocalizations get _t => AppLocalizations.of(context)!;
  bool get _historyAvailable => kIsWeb && MediaQuery.sizeOf(context).width >= 800;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _refresh() async {
    final token = ++_generation;
    // Mantener los campos montados durante la recarga de la misma ficha.
    setState(() { _loading = true; _error = false; _unauthorized = false; });
    try {
      final value = await widget.api.fetchRenewalDetail(widget.workspace.id, widget.renewalId);
      if (!mounted || token != _generation) return;
      setState(() { _renewal = value; _loading = false; });
      await _loadManualFollowUp(token);
      try {
        final insurers = await widget.api.fetchInsurers(widget.workspace.id);
        if (mounted && token == _generation) {
          setState(() => _insurers = insurers);
        }
      } catch (_) {
        // No inventar nombre de aseguradora si falla la consulta.
      }
    } on VenciraUnauthorized {
      if (!mounted || token != _generation) return;
      setState(() { _loading = false; _unauthorized = true; _renewal = null; });
    } catch (_) {
      if (!mounted || token != _generation) return;
      setState(() { _loading = false; _error = true; });
    }
  }


  Future<void> _loadManualFollowUp(int token) async {
    if (!mounted) return;
    setState(() { _followUpLoading = true; _followUpError = false; });
    try {
      final value = await widget.api.fetchManualFollowUp(
        widget.workspace.id, widget.renewalId);
      if (!mounted || token != _generation) return;
      setState(() { _manualFollowUp = value; _followUpLoaded = true; _followUpLoading = false; });
    } on VenciraUnauthorized {
      if (!mounted || token != _generation) return;
      setState(() { _unauthorized = true; _followUpLoading = false; });
    } catch (_) {
      if (!mounted || token != _generation) return;
      setState(() { _followUpError = true; _followUpLoading = false; });
    }
  }

  Future<void> _chooseManualDate() async {
    if (_saving) return;
    final offset = await showModalBottomSheet<int>(
      context: context, showDragHandle: true, useSafeArea: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(_t.detailText01),
            subtitle: Text(_t.detailText02)),
          ListTile(leading: const Icon(Icons.wb_twilight_outlined),
            title: Text(_t.detailText03),
            onTap: () => Navigator.of(sheet).pop(1)),
          ListTile(leading: const Icon(Icons.event_outlined),
            title: Text(_t.detailText04),
            onTap: () => Navigator.of(sheet).pop(3)),
          ListTile(leading: const Icon(Icons.calendar_month_outlined),
            title: Text(_t.detailText05),
            onTap: () => Navigator.of(sheet).pop(7)),
          ListTile(leading: const Icon(Icons.date_range_outlined),
            title: Text(_t.detailText06),
            onTap: () => Navigator.of(sheet).pop(0)),
          const SizedBox(height: 10),
        ]),
      ),
    );
    if (!mounted || offset == null) return;
    final now = DateTime.now();
    DateTime day;
    if (offset == 0) {
      final picked = await showDatePicker(
        context: context,
        firstDate: DateTime(2000), lastDate: DateTime(2100, 12, 31),
        initialDate: _manualFollowUp?.scheduledFor ??
            DateTime(now.year, now.month, now.day + 1),
      );
      if (!mounted || picked == null) return;
      day = DateTime(picked.year, picked.month, picked.day);
    } else {
      // Constructor civil: sumar días del calendario, no bloques de 24h (DST).
      day = DateTime(now.year, now.month, now.day + offset);
    }
    await _saveManualDate(day);
  }

  Future<void> _saveManualDate(DateTime day) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await widget.api.scheduleManualFollowUp(
          widget.workspace.id, widget.renewalId, day);
      if (!mounted) return;
      setState(() { _manualFollowUp = result; _followUpError = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        _t.detailText07)));
      if (_history != null) await _loadHistory(1);
    } on VenciraUnauthorized {
      if (mounted) setState(() => _unauthorized = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resolveManual(String action) async {
    final row = _manualFollowUp;
    if (row == null || _saving) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(action == 'complete'
            ? _t.detailText08
            : _t.detailText09),
        content: Text(_t.detailText10),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: Text(_t.detailText11)),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.api.resolveManualFollowUp(
        widget.workspace.id, widget.renewalId, row.id, action);
      if (!mounted) return;
      setState(() => _manualFollowUp = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        action == 'complete'
          ? _t.detailText12
          : _t.detailText13)));
      if (_history != null) await _loadHistory(1);
    } on VenciraUnauthorized {
      if (mounted) setState(() => _unauthorized = true);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _manualFollowUpCard(String locale) {
    final colors = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.bookmark_added_outlined,
            color: const Color(0xFF956DC0), size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(_t.detailText14,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        SizedBox(height: 3, child: _followUpLoading && _followUpLoaded
          ? const LinearProgressIndicator() : null),
        if (_followUpLoading && !_followUpLoaded)
          const LinearProgressIndicator()
        else if (_followUpError)
          OutlinedButton(onPressed: () => _loadManualFollowUp(_generation),
            child: Text(_t.retry))
        else ...[
          Text(_manualFollowUp == null
            ? _t.detailText15
            : _t.detailText16 +
              DateFormat.yMd(locale).format(_manualFollowUp!.scheduledFor),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const ValueKey('schedule-follow-up'),
            onPressed: _saving ? null : _chooseManualDate,
            icon: const Icon(Icons.event_available_outlined),
            label: Text(_manualFollowUp == null
              ? _t.detailText17
              : _t.detailText18),
          ),
          if (_manualFollowUp != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton.icon(
                key: const ValueKey('complete-follow-up'),
                onPressed: _saving ? null : () => _resolveManual('complete'),
                icon: const Icon(Icons.check_rounded),
                label: Text(_t.detailText19),
              ),
              TextButton.icon(
                key: const ValueKey('cancel-follow-up'),
                onPressed: _saving ? null : () => _resolveManual('cancel'),
                icon: const Icon(Icons.close_rounded),
                label: Text(_t.cancel),
              ),
            ]),
          ],
          const SizedBox(height: 5),
          Text(_t.detailText20,
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    ));
  }

  Future<void> _loadHistory(int page) async {
    if (!_historyAvailable) return;
    setState(() { _page = page; _historyLoading = true; _historyError = false; });
    try {
      final value = await widget.api.fetchRenewalHistory(
          widget.workspace.id, widget.renewalId, page: page);
      if (!mounted) return;
      setState(() { _history = value; _historyLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _historyLoading = false; _historyError = true; });
    }
  }

  Future<void> _edit() async {
    final current = _renewal;
    if (current == null || _saving) return;
    List<VenciraModalityOption> options;
    try {
      options = await widget.api.fetchModalities(widget.workspace.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.modalityChangeFailed)));
      return;
    }
    List<VenciraInsurer> insurers;
    try {
      insurers = await widget.api.fetchInsurers(widget.workspace.id);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.insurerLoadError)));
      return;
    }
    if (!mounted) return;
    final input = await showDialog<VenciraRenewalInput>(context: context,
      builder: (_) => VenciraRenewalEditor(
        existing: current, modalities: options, insurers: insurers,
        api: widget.api, workspaceId: widget.workspace.id));
    if (!mounted || input == null) return;
    setState(() => _saving = true);
    try {
      await widget.api.updateRenewal(widget.workspace.id, current.id, input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_t.saved)));
      await _refresh();
      // No se reconstruye un historial si no se ha solicitado.
      if (mounted && _history != null) await _loadHistory(1);
    } on VenciraUnauthorized {
      if (mounted) setState(() { _renewal = null; _unauthorized = true; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// El contacto se ha realizado fuera de VENCIRA. Solo registramos
  /// una transición auditable; jamás se envía un mensaje desde esta acción.
  Future<void> _changeContactStatus() async {
    final current = _renewal;
    if (current == null || _saving ||
        !const ['pending', 'contacted'].contains(current.status)) return;
    final next = current.status == 'pending' ? 'contacted' : 'pending';
    final isContact = next == 'contacted';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isContact
            ? _t.detailCaption01
            : _t.detailCaption02),
        content: Text(isContact
            ? _t.detailCaption03
            : _t.detailCaption04),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_t.detailCaption05),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _saving = true);
    try {
      final updated = await widget.api.changeRenewalStatus(
        widget.workspace.id, current.id, next,
      );
      if (!mounted) return;
      setState(() => _renewal = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(isContact
            ? _t.detailCaption06
            : _t.detailCaption07),
      ));
      await _refresh();
      if (mounted && _history != null) await _loadHistory(1);
    } on VenciraUnauthorized {
      if (mounted) setState(() { _renewal = null; _unauthorized = true; });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _outcomeLabel(String kind) => switch (kind) {
    'won' => _t.detailText21,
    'declined' => _t.detailText22,
    'undecided' => _t.detailText23,
    'discarded' => _t.detailText24,
    'restored' => _t.detailText25,
    _ => kind,
  };

  Future<DateTime?> _outcomeFollowDate() async {
    final offset = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(title: Text(_t.detailText26)),
          ListTile(title: Text(_t.detailText03),
            leading: const Icon(Icons.wb_twilight_outlined),
            onTap: () => Navigator.of(sheet).pop(1)),
          ListTile(title: Text(_t.detailText04),
            leading: const Icon(Icons.event_outlined),
            onTap: () => Navigator.of(sheet).pop(3)),
          ListTile(title: Text(_t.detailText05),
            leading: const Icon(Icons.calendar_month_outlined),
            onTap: () => Navigator.of(sheet).pop(7)),
          ListTile(title: Text(_t.detailText27),
            leading: const Icon(Icons.date_range_outlined),
            onTap: () => Navigator.of(sheet).pop(0)),
        ]),
      ),
    );
    if (!mounted || offset == null) return null;
    final now = DateTime.now();
    if (offset != 0) {
      return DateTime(now.year, now.month, now.day + offset);
    }
    final initial = DateTime(now.year, now.month, now.day + 1);
    return showDatePicker(
      context: context, firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31), initialDate: initial,
    );
  }

  Future<void> _chooseOutcome({bool restoring = false}) async {
    final renewal = _renewal;
    if (_saving || renewal == null) return;
    String? kind;
    if (restoring) {
      kind = 'restored';
    } else {
      kind = await showModalBottomSheet<String>(
        context: context, useSafeArea: true, showDragHandle: true,
        isScrollControlled: true,
        builder: (sheet) => SafeArea(child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(_t.detailText28),
              subtitle: Text(_t.detailText29)),
            for (final choice in const [
              ('won', Icons.verified_outlined),
              ('declined', Icons.event_repeat_outlined),
              ('undecided', Icons.schedule_outlined),
              ('discarded', Icons.inventory_2_outlined),
            ])
              ListTile(
                key: ValueKey('outcome-' + choice.$1),
                title: Text(_outcomeLabel(choice.$1)),
                leading: Icon(choice.$2),
                onTap: () => Navigator.of(sheet).pop(choice.$1),
              ),
          ],
        )),
      );
    }
    if (!mounted || kind == null) return;
    DateTime? day;
    if (kind == 'undecided') {
      day = await _outcomeFollowDate();
      if (!mounted || day == null) return;
    }
    final selected = kind;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(_outcomeLabel(selected)),
        content: Text(switch (selected) {
          'won' => _t.detailText30,
          'declined' => _t.detailText31,
          'undecided' => _t.detailText32,
          'discarded' => _t.detailText33,
          _ => _t.detailText34,
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(_t.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(_t.detailText11)),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.api.applyOutcome(
        widget.workspace.id, renewal.id, selected,
        scheduledFor: day,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_t.detailText35)));
      await _refresh();
      if (mounted && _history != null) await _loadHistory(1);
    } on VenciraUnauthorized {
      if (mounted) setState(() {
        _renewal = null;
        _unauthorized = true;
      });
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _outcomeCard(VenciraRenewal renewal) {
    final archived = renewal.archiveOutcome.isNotEmpty;
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t.detailText36,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (archived) ...[
            Text(_t.detailText37 +
                _outcomeLabel(renewal.archiveOutcome)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const ValueKey('restore-outcome'),
              onPressed: _saving ? null : () => _chooseOutcome(restoring: true),
              icon: const Icon(Icons.unarchive_outlined),
              label: Text(_outcomeLabel('restored')),
            ),
          ] else ...[
            Text(_t.detailText38,
              style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const ValueKey('choose-outcome'),
              onPressed: _saving ? null : _chooseOutcome,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(_t.detailText39),
            ),
          ],
        ],
      ),
    ));
  }

  String _entryLabel(String? value) => switch (value) {
    'clients' => _t.entryClients,
    'prospects' => _t.entryProspects,
    _ => _t.entryUnknown,
  };

  String _modalityLabel(String value) => switch (value) {
    'autos' => _t.modAutos,
    'motos' => _t.modMotos,
    'patinetes' => _t.modPatinetes,
    'hogar' => _t.modHogar,
    'comercio' => _t.modComercio,
    'decesos' => _t.modDecesos,
    'salud' => _t.modSalud,
    'vida' => _t.modVida,
    'accidentes' => _t.modAccidentes,
    'rc' => _t.modRc,
    'comunidades' => _t.modComunidades,
    'otros' => _t.modOtros,
    '' => _t.notDefined,
    _ => value,
  };

  String _status(String value) => switch (value) {
    'pending' => _t.pending,
    'contacted' => _t.contacted,
    'closed' => _t.closed,
    _ => _t.unknown,
  };

  String _field(String value) => switch (value) {
    'customer_reference' => _t.reference,
    'expires_on' => _t.expiryDate,
    'notice_deadline_on' => _t.noticeDate,
    'status' => _t.status,
    'assigned_to_id' => _t.detailAssignment,
    'manual_follow_up' => _t.detailText40,
    'outcome' => _t.detailText36,
    'archived_at' => _t.detailText41,
    'archive_outcome' => _t.detailText42,
    _ => _t.detailOtherChange,
  };

  String _auditSubtitle(VenciraHistoryEvent event, String locale) {
    final rawOutcome = event.metadata['outcome'];
    final kind = rawOutcome is Map ? rawOutcome['kind'] : null;
    return DateFormat.yMd(locale).add_Hm().format(event.timestamp.toLocal()) +
        ' · ' + (event.actor ?? _t.detailActorUnavailable) +
        (kind is String ? '\\n' + _outcomeLabel(kind) : '') +
        (event.fields.isEmpty
            ? '' : '\\n' + event.fields.map(_field).join(', '));
  }

  Widget _historySection(String locale) {
    if (_historyLoading && _history == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_historyError) return Column(children: [
      Text(_t.detailHistoryError),
      TextButton(onPressed: () => _loadHistory(_page), child: Text(_t.retry)),
    ]);
    final result = _history;
    if (result == null) return OutlinedButton.icon(
      onPressed: () => _loadHistory(1), icon: const Icon(Icons.history),
      label: Text(_t.detailHistoryLoad),
    );
    if (result.events.isEmpty) return Text(_t.detailHistoryEmpty);
    return Column(children: [
      SizedBox(height: 3, child: _historyLoading
        ? const LinearProgressIndicator() : null),
      ...result.events.map((event) => ListTile(
        leading: const Icon(Icons.history),
        title: Text(event.action == 'created' ?
          _t.detailHistoryCreated : _t.detailHistoryUpdated),
        subtitle: Text(_auditSubtitle(event, locale)),
      )),
      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton(onPressed: _page > 1 && !_historyLoading
          ? () => _loadHistory(_page - 1) : null,
            child: Text(_t.previous)),
        Text(_t.page + ' ' + _page.toString()),
        OutlinedButton(onPressed: result.hasNext && !_historyLoading
          ? () => _loadHistory(_page + 1) : null,
            child: Text(_t.next)),
      ]),
    ]);
  }


  Widget _sectionCard(IconData icon, String title, List<Widget> fields) {
    final colors = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 19, color: colors.primary),
          const SizedBox(width: 10),
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Divider(color: colors.outlineVariant),
        const SizedBox(height: 6),
        ...fields,
      ]),
    ));
  }

  Widget _info(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 3),
      Text(value, style: Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w500)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final renewal = _renewal;
    return Scaffold(
      appBar: AppBar(title: Text(_t.detailTitle), actions: [
        IconButton(tooltip: _t.refresh,
          onPressed: _saving ? null : _refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SizedBox(height: 3, child: _loading && renewal != null
              ? const LinearProgressIndicator() : null),
          if (_unauthorized)
            Text(_t.loginRequired)
          else if (_error)
            Column(children: [
              Text(_t.detailLoadError),
              TextButton(onPressed: _refresh, child: Text(_t.retry)),
            ])
          else if (_loading && renewal == null)
            const Center(child: CircularProgressIndicator())
          else if (renewal != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  renewal.fullName.isNotEmpty
                      ? renewal.fullName : renewal.reference,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700),
                ),
                if (renewal.fullName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(renewal.reference, style: Theme.of(context)
                      .textTheme.bodySmall),
                ],
                const SizedBox(height: 12),
                VenciraStatusBadge(status: renewal.status,
                  label: _status(renewal.status)),
              ]),
            ),
            if (renewal.fullName.isNotEmpty ||
                renewal.nickname.isNotEmpty ||
                renewal.phone.isNotEmpty ||
                renewal.email.isNotEmpty)
              _sectionCard(Icons.person_outline_rounded,
                _t.detailCaption08, [
                  if (renewal.fullName.isNotEmpty)
                    _info(_t.detailInfoName, renewal.fullName),
                  if (renewal.nickname.isNotEmpty)
                    _info(_t.detailInfoNickname, renewal.nickname),
                  if (renewal.phone.isNotEmpty)
                    _info(_t.personPhoneLabel, renewal.phone),
                  if (renewal.email.isNotEmpty)
                    _info(_t.personEmailLabel, renewal.email),
              ]),
            _sectionCard(Icons.description_outlined,
              _t.detailCaption09, [
                if (renewal.policyNumber.isNotEmpty)
                  _info(_t.personPolicyLabel, renewal.policyNumber),
                _info(_t.entryLabel, _entryLabel(renewal.entry)),
                _info(_t.modalityLabel, _modalityLabel(renewal.modality)),
                _info(_t.insurerLabel, renewal.insurerId == null
                  ? _t.notDefined : _insurers
                      .where((item) => item.id == renewal.insurerId)
                      .map((item) => item.name)
                      .firstOrNull ?? _t.insurerLegacy),
            ]),
            _sectionCard(Icons.event_note_outlined,
              _t.detailCaption10, [
                _info(_t.expiryDate,
                  DateFormat.yMd(locale).format(renewal.expiresOn)),
                if (renewal.noticeDeadlineOn != null)
                  _info(_t.noticeDate,
                    DateFormat.yMd(locale).format(renewal.noticeDeadlineOn!)),
            ]),
            if (renewal.notes.isNotEmpty)
              _sectionCard(Icons.notes_outlined,
                _t.detailCaption11, [
                  _info(_t.detailCaption12,
                    renewal.notes),
              ]),
            if (renewal.status == 'pending' ||
                renewal.status == 'contacted') ...[
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.assignment_turned_in_outlined,
                          size: 20, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _t.detailCaption13,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _t.detailCaption14,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (renewal.status == 'pending')
                        FilledButton.tonalIcon(
                          key: const ValueKey('mark-contacted'),
                          onPressed: _saving ? null : _changeContactStatus,
                          icon: const Icon(Icons.forum_outlined),
                          label: Text(_t.detailCaption15),
                        )
                      else
                        OutlinedButton.icon(
                          key: const ValueKey('restore-pending'),
                          onPressed: _saving ? null : _changeContactStatus,
                          icon: const Icon(Icons.undo_rounded),
                          label: Text(_t.detailCaption02),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (renewal.status != 'closed') ...[
              const SizedBox(height: 12),
              _manualFollowUpCard(locale),
            ],
            if (renewal.status != 'closed' ||
                renewal.archiveOutcome.isNotEmpty) ...[
              const SizedBox(height: 12),
              _outcomeCard(renewal),
            ],
            if (renewal.archiveOutcome.isEmpty) ...[
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _saving ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(_t.editRenewal)),
            ],
            if (renewal.status != 'closed' &&
                renewal.archiveOutcome.isEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: ExpansionTile(
                  key: ValueKey('reminder-preview-expand-' + renewal.id),
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(_t.detailCaption16),
                  subtitle: Text(_t.detailCaption17),
                  // La vista previa solo consulta la API después de abrirla.
                  // No alterar la posición ni el comportamiento de los
                  // controles de seguimiento/manuales ya existentes.
                  children: [
                    VenciraReminderPreviewCard(
                      api: widget.api,
                      workspaceId: widget.workspace.id,
                      renewalId: renewal.id,
                    ),
                    VenciraReminderDraftCard(
                      api: widget.api,
                      workspaceId: widget.workspace.id,
                      renewalId: renewal.id,
                    ),
                    VenciraControlAssessmentCard(
                      api: widget.api,
                      workspaceId: widget.workspace.id,
                      renewalId: renewal.id,
                    ),
                    VenciraControlResponseCard(
                      api: widget.api,
                      workspaceId: widget.workspace.id,
                      renewalId: renewal.id,
                    ),
                    VenciraOperationalPanel(
                      api: widget.api,
                      workspaceId: widget.workspace.id,
                      renewalId: renewal.id,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(_t.detailPrototypeWarning,
              style: Theme.of(context).textTheme.bodySmall),
            if (_historyAvailable) ...[
              const SizedBox(height: 22),
              Text(_t.detailHistoryTitle, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _historySection(locale),
            ],
          ],
        ]),
      ))),
    );
  }
}
