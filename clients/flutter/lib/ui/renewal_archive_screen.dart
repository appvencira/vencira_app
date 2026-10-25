import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'renewal_detail_screen.dart';

/// Archivo de una sola organización, servido por la API autorizada.
/// Incluye registros O3 archivados y los cierres legacy (sin inferir desenlace).
/// Solo utiliza el endpoint existente status=closed; no ejecuta borrados.
class VenciraArchiveScreen extends StatefulWidget {
  const VenciraArchiveScreen({
    super.key, required this.api, required this.workspace,
  });

  final VenciraApi api;
  final VenciraWorkspace workspace;

  @override
  State<VenciraArchiveScreen> createState() => _ArchiveState();
}

class _ArchiveState extends State<VenciraArchiveScreen> {
  VenciraRenewalPage? _archive;
  bool _loading = true;
  bool _unauthorized = false;
  bool _error = false;
  int _page = 1;
  int _request = 0;

  AppLocalizations get _t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  @override
  void dispose() {
    _request++;
    super.dispose();
  }

  Future<void> _load(int page) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      // Mantener el archivo visible durante actualización de la misma cuenta.
      _error = false;
      _unauthorized = false;
    });
    try {
      final result = await widget.api.fetchFilteredRenewals(
        widget.workspace.id, page: page, status: 'closed',
      );
      if (!mounted || request != _request) return;
      setState(() {
        _page = page;
        _archive = result;
        _loading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _unauthorized = true;
        _archive = null;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _open(VenciraRenewal renewal) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraRenewalDetailScreen(
        api: widget.api,
        workspace: widget.workspace,
        renewalId: renewal.id,
      ),
    ));
    if (mounted) await _load(_page);
  }

  String _outcome(VenciraRenewal value) => switch (value.archiveOutcome) {
    'won' => _t.archiveWon,
    'discarded' => _t.archiveDiscarded,
    _ => _t.archiveLegacy,
  };

  Widget _row(VenciraRenewal value) {
    final date = DateFormat('dd/MM/yyyy').format(value.expiresOn);
    return Card(
      child: ListTile(
        key: ValueKey('archive-item-${value.id}'),
        isThreeLine: true,
        title: Text(value.reference, maxLines: 1,
          overflow: TextOverflow.ellipsis),
        subtitle: Text('${_outcome(value)}\n${_t.expiryDate}: $date'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _open(value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t.archiveTitle),
        actions: [
          IconButton(
            tooltip: _t.refresh,
            onPressed: _loading ? null : () => _load(_page),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.workspace.name,
                  style: Theme.of(context).textTheme.titleSmall,
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 9),
                Text(_t.archiveDescription,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                SizedBox(height: 3, child: _loading && _archive != null
                    ? const LinearProgressIndicator() : null),
                if (_loading && _archive == null)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  )),
                if (_unauthorized)
                  Text(_t.loginRequired),
                if (_error)
                  Column(children: [
                    Text(_t.loadError),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => _load(_page),
                      child: Text(_t.retry),
                    ),
                  ]),
                if (_archive != null && !_unauthorized) ...[
                  if (_archive!.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(_t.archiveEmpty),
                    ),
                  for (final value in _archive!.items)
                    _row(value),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _page > 1 ? () => _load(_page - 1) : null,
                        icon: const Icon(Icons.chevron_left),
                        label: Text(_t.previous),
                      ),
                      Text('${_t.page} $_page'),
                      OutlinedButton.icon(
                        onPressed: _archive!.hasNext
                            ? () => _load(_page + 1) : null,
                        icon: const Icon(Icons.chevron_right),
                        label: Text(_t.next),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
