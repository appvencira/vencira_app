import 'package:flutter/material.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// Aseguradoras ficticias de la cuenta; no es aún el registro oficial DGSFP.
class VenciraInsurerCatalogScreen extends StatefulWidget {
  const VenciraInsurerCatalogScreen({
    super.key, required this.api, required this.workspace,
  });
  final VenciraApi api;
  final VenciraWorkspace workspace;

  @override
  State<VenciraInsurerCatalogScreen> createState() => _InsurersState();
}

class _InsurersState extends State<VenciraInsurerCatalogScreen> {
  final _search = TextEditingController();
  List<VenciraInsurer> _rows = [];
  bool _loading = true;
  bool _failed = false;
  bool _busy = false;
  int _generation = 0;
  AppLocalizations get _t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await widget.api.fetchInsurers(widget.workspace.id,
        search: _search.text.trim());
      if (!mounted || generation != _generation) return;
      setState(() { _rows = result; _loading = false; });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() { _loading = false; _failed = true; });
    }
  }

  Future<String?> _nameDialog({String? oldName}) async {
    // El TextFormField es propietario de su controlador: no lo destruimos
    // mientras el diálogo termina la animación de salida.
    var edited = oldName ?? '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(oldName == null ? _t.insurerAdd : _t.insurerRename),
        content: TextFormField(
          key: const ValueKey('insurer-name'),
          initialValue: edited,
          onChanged: (value) => edited = value,
          autofocus: true,
          maxLength: 140,
          decoration: InputDecoration(labelText: _t.insurerLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
            child: Text(_t.cancel)),
          FilledButton(onPressed: () {
            final value = edited.trim();
            if (value.length >= 2) Navigator.pop(dialogContext, value);
          }, child: Text(_t.save)),
        ],
      ),
    );
  }

  Future<void> _mutate(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await run();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.insurerSaveError)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final name = await _nameDialog();
    if (name == null || !mounted) return;
    await _mutate(() async {
      await widget.api.createInsurer(widget.workspace.id, name);
    });
  }

  Future<void> _rename(VenciraInsurer item) async {
    final name = await _nameDialog(oldName: item.name);
    if (name == null || !mounted || name == item.name) return;
    await _mutate(() async {
      await widget.api.renameInsurer(widget.workspace.id, item.id, name);
    });
  }

  Future<void> _toggle(VenciraInsurer item) async {
    if (item.active) {
      final accepted = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(
          title: Text(_t.insurerDeactivate),
          content: Text(_t.insurerDeactivateHelp),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text(_t.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true),
              child: Text(_t.insurerDeactivate)),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    await _mutate(() async {
      if (item.active) {
        await widget.api.deactivateInsurer(widget.workspace.id, item.id);
      } else {
        await widget.api.reactivateInsurer(widget.workspace.id, item.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.workspace.role == 'owner';
    return Scaffold(
      appBar: AppBar(
        title: Text(_t.insurerManage),
        actions: [
          IconButton(tooltip: _t.refresh, onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: !canEdit ? null : FloatingActionButton.extended(
        onPressed: _busy ? null : _add,
        icon: const Icon(Icons.add), label: Text(_t.insurerAdd),
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Text(_t.insurerCatalogScope,
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _search, maxLength: 80,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              labelText: _t.insurerSearch,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(tooltip: _t.refresh,
                onPressed: _load, icon: const Icon(Icons.search)),
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),
          SizedBox(height: 3, child: _loading && _rows.isNotEmpty
            ? const LinearProgressIndicator() : null),
          if (_loading && _rows.isEmpty)
            const Center(child: CircularProgressIndicator()),
          if (_failed) Column(children: [
            Text(_t.insurerLoadError),
            TextButton(onPressed: _load, child: Text(_t.retry)),
          ]),
          if (!_loading && !_failed && _rows.isEmpty)
            Text(_t.insurerEmpty),
          for (final item in _rows)
            Card(child: ListTile(
              key: ValueKey('insurer-' + item.id),
              title: Text(item.name),
              subtitle: Text(item.active ?
                _t.modalityActive : _t.modalityInactive),
              trailing: !canEdit ? null : Wrap(
                alignment: WrapAlignment.end,
                spacing: 0,
                children: [
                  IconButton(tooltip: _t.insurerRename,
                    onPressed: _busy ? null : () => _rename(item),
                    icon: const Icon(Icons.edit_outlined)),
                  IconButton(tooltip: item.active ?
                      _t.insurerDeactivate : _t.insurerReactivate,
                    onPressed: _busy ? null : () => _toggle(item),
                    icon: Icon(item.active ?
                      Icons.visibility_off_outlined : Icons.visibility_outlined)),
                ],
              ),
            )),
          const SizedBox(height: 85),
        ]),
      ))),
    );
  }
}
