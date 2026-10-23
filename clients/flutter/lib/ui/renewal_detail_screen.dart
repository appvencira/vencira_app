import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'renewal_editor.dart';
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
    setState(() { _loading = true; _error = false; _unauthorized = false; _renewal = null; });
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
      setState(() { _loading = false; _unauthorized = true; });
    } catch (_) {
      if (!mounted || token != _generation) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  String _o2(String es, String ca) =>
      Localizations.localeOf(context).languageCode == 'ca' ? ca : es;

  Future<void> _loadManualFollowUp(int token) async {
    if (!mounted) return;
    setState(() { _followUpLoading = true; _followUpError = false;
                  _manualFollowUp = null; });
    try {
      final value = await widget.api.fetchManualFollowUp(
        widget.workspace.id, widget.renewalId);
      if (!mounted || token != _generation) return;
      setState(() { _manualFollowUp = value; _followUpLoading = false; });
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
          ListTile(title: Text(_o2('¿Cuándo quieres recordarlo?',
              'Quan ho vols recordar?')),
            subtitle: Text(_o2(
              'Se mostrará en la agenda, sin enviar notificaciones.',
              'Apareixerà a l’agenda, sense enviar notificacions.'))),
          ListTile(leading: const Icon(Icons.wb_twilight_outlined),
            title: Text(_o2('Mañana', 'Demà')),
            onTap: () => Navigator.of(sheet).pop(1)),
          ListTile(leading: const Icon(Icons.event_outlined),
            title: Text(_o2('En 3 días', 'D’aquí a 3 dies')),
            onTap: () => Navigator.of(sheet).pop(3)),
          ListTile(leading: const Icon(Icons.calendar_month_outlined),
            title: Text(_o2('En 7 días', 'D’aquí a 7 dies')),
            onTap: () => Navigator.of(sheet).pop(7)),
          ListTile(leading: const Icon(Icons.date_range_outlined),
            title: Text(_o2('Elegir otra fecha', 'Triar una altra data')),
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
        _o2('Seguimiento programado en agenda',
            'Seguiment programat a l’agenda'))));
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
            ? _o2('Marcar seguimiento atendido', 'Marcar seguiment atès')
            : _o2('Cancelar seguimiento', 'Cancel·lar seguiment')),
        content: Text(_o2(
          'Se guardará la acción en el historial. No se enviará ningún aviso.',
          'Es guardarà l’acció a l’historial. No s’enviarà cap avís.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false),
            child: Text(_t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true),
            child: Text(_o2('Confirmar', 'Confirmar'))),
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
          ? _o2('Seguimiento atendido', 'Seguiment atès')
          : _o2('Seguimiento cancelado', 'Seguiment cancel·lat'))));
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
          Expanded(child: Text(_o2('Recuérdamelo', 'Recorda-m’ho'),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        if (_followUpLoading)
          const LinearProgressIndicator()
        else if (_followUpError)
          OutlinedButton(onPressed: () => _loadManualFollowUp(_generation),
            child: Text(_t.retry))
        else ...[
          Text(_manualFollowUp == null
            ? _o2('Sin seguimiento manual programado.',
                'Sense seguiment manual programat.')
            : _o2('Próximo seguimiento: ', 'Pròxim seguiment: ') +
              DateFormat.yMd(locale).format(_manualFollowUp!.scheduledFor),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            key: const ValueKey('schedule-follow-up'),
            onPressed: _saving ? null : _chooseManualDate,
            icon: const Icon(Icons.event_available_outlined),
            label: Text(_manualFollowUp == null
              ? _o2('Elegir fecha', 'Triar data')
              : _o2('Reprogramar', 'Reprogramar')),
          ),
          if (_manualFollowUp != null) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton.icon(
                key: const ValueKey('complete-follow-up'),
                onPressed: _saving ? null : () => _resolveManual('complete'),
                icon: const Icon(Icons.check_rounded),
                label: Text(_o2('Atendido', 'Atès')),
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
          Text(_o2('Fecha visible en la agenda; no es una notificación enviada.',
              'Data visible a l’agenda; no és una notificació enviada.'),
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ]),
    ));
  }

  Future<void> _loadHistory(int page) async {
    if (!_historyAvailable) return;
    setState(() { _page = page; _history = null; _historyLoading = true; _historyError = false; });
    try {
      final value = await widget.api.fetchRenewalHistory(
          widget.workspace.id, widget.renewalId, page: page);
      if (!mounted) return;
      setState(() { _history = value; _historyLoading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _history = null; _historyLoading = false; _historyError = true; });
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
            ? _designLabel('Registrar contacto', 'Registrar contacte')
            : _designLabel('Volver a pendiente', 'Tornar a pendent')),
        content: Text(isContact
            ? _designLabel(
                'Confirma que el contacto ya se ha realizado fuera de VENCIRA. '
                'Solo se actualizará el estado; no se enviará ningún mensaje.',
                'Confirma que el contacte ja s’ha fet fora de VENCIRA. '
                'Només s’actualitzarà l’estat; no s’enviarà cap missatge.')
            : _designLabel(
                'La anotación volverá a pendiente. No se borrarán sus notas '
                'ni el historial de cambios.',
                'L’anotació tornarà a pendent. No s’esborraran les notes '
                'ni l’historial de canvis.')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(_t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(_designLabel('Confirmar', 'Confirmar')),
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
            ? _designLabel('Contacto registrado', 'Contacte registrat')
            : _designLabel('Estado pendiente restaurado',
                'Estat pendent restaurat')),
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
    'manual_follow_up' => _o2('Seguimiento manual', 'Seguiment manual'),
    _ => _t.detailOtherChange,
  };

  Widget _historySection(String locale) {
    if (_historyLoading) return const Center(child: CircularProgressIndicator());
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
      ...result.events.map((event) => ListTile(
        leading: const Icon(Icons.history),
        title: Text(event.action == 'created' ?
          _t.detailHistoryCreated : _t.detailHistoryUpdated),
        subtitle: Text(
          DateFormat.yMd(locale).add_Hm().format(event.timestamp.toLocal()) +
          ' · ' + (event.actor ?? _t.detailActorUnavailable) +
          (event.fields.isEmpty ? '' : '\n' + event.fields.map(_field).join(', ')),
        ),
      )),
      Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        OutlinedButton(onPressed: _page > 1 ? () => _loadHistory(_page - 1) : null,
            child: Text(_t.previous)),
        Text(_t.page + ' ' + _page.toString()),
        OutlinedButton(onPressed: result.hasNext ? () => _loadHistory(_page + 1) : null,
            child: Text(_t.next)),
      ]),
    ]);
  }

  String _designLabel(String es, String ca) =>
      Localizations.localeOf(context).languageCode == 'ca' ? ca : es;

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
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_unauthorized)
            Text(_t.loginRequired)
          else if (_error)
            Column(children: [
              Text(_t.detailLoadError),
              TextButton(onPressed: _refresh, child: Text(_t.retry)),
            ])
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
                _designLabel('Contacto', 'Contacte'), [
                  if (renewal.fullName.isNotEmpty)
                    _info('Nombre o razón social', renewal.fullName),
                  if (renewal.nickname.isNotEmpty)
                    _info('Apodo', renewal.nickname),
                  if (renewal.phone.isNotEmpty)
                    _info('Teléfono', renewal.phone),
                  if (renewal.email.isNotEmpty)
                    _info('Correo electrónico', renewal.email),
              ]),
            _sectionCard(Icons.description_outlined,
              _designLabel('Póliza', 'Pòlissa'), [
                if (renewal.policyNumber.isNotEmpty)
                  _info('Número de póliza', renewal.policyNumber),
                _info(_t.entryLabel, _entryLabel(renewal.entry)),
                _info(_t.modalityLabel, _modalityLabel(renewal.modality)),
                _info(_t.insurerLabel, renewal.insurerId == null
                  ? _t.notDefined : _insurers
                      .where((item) => item.id == renewal.insurerId)
                      .map((item) => item.name)
                      .firstOrNull ?? _t.insurerLegacy),
            ]),
            _sectionCard(Icons.event_note_outlined,
              _designLabel('Fechas', 'Dates'), [
                _info(_t.expiryDate,
                  DateFormat.yMd(locale).format(renewal.expiresOn)),
                if (renewal.noticeDeadlineOn != null)
                  _info(_t.noticeDate,
                    DateFormat.yMd(locale).format(renewal.noticeDeadlineOn!)),
            ]),
            if (renewal.notes.isNotEmpty)
              _sectionCard(Icons.notes_outlined,
                _designLabel('Notas', 'Notes'), [
                  _info(_designLabel('Observaciones', 'Observacions'),
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
                          _designLabel('Seguimiento', 'Seguiment'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        )),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                        _designLabel(
                          'Registra un contacto realizado fuera de VENCIRA. '
                          'Esta acción no envía mensajes ni programa avisos.',
                          'Registra un contacte fet fora de VENCIRA. '
                          'Aquesta acció no envia missatges ni programa avisos.',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (renewal.status == 'pending')
                        FilledButton.tonalIcon(
                          key: const ValueKey('mark-contacted'),
                          onPressed: _saving ? null : _changeContactStatus,
                          icon: const Icon(Icons.forum_outlined),
                          label: Text(_designLabel(
                              'Marcar como contactado', 'Marcar com a contactat')),
                        )
                      else
                        OutlinedButton.icon(
                          key: const ValueKey('restore-pending'),
                          onPressed: _saving ? null : _changeContactStatus,
                          icon: const Icon(Icons.undo_rounded),
                          label: Text(_designLabel(
                              'Volver a pendiente', 'Tornar a pendent')),
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
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: _saving ? null : _edit,
              icon: const Icon(Icons.edit_outlined),
              label: Text(_t.editRenewal)),
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
