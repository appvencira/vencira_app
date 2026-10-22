import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'renewal_editor.dart';

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
    final input = await showDialog<VenciraRenewalInput>(context: context,
      builder: (_) => VenciraRenewalEditor(existing: current));
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

  Widget _info(String title, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.labelMedium),
      Text(value, style: Theme.of(context).textTheme.bodyLarge),
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
            Card(child: Padding(padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(renewal.reference, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                _info(_t.entryLabel, _entryLabel(renewal.entry)),
                _info(_t.modalityLabel, _modalityLabel(renewal.modality)),
                _info(_t.expiryDate, DateFormat.yMd(locale).format(renewal.expiresOn)),
                if (renewal.noticeDeadlineOn != null)
                  _info(_t.noticeDate, DateFormat.yMd(locale).format(renewal.noticeDeadlineOn!)),
                _info(_t.status, _status(renewal.status)),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _saving ? null : _edit,
                  icon: const Icon(Icons.edit_outlined), label: Text(_t.editRenewal)),
              ]),
            )),
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
