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
