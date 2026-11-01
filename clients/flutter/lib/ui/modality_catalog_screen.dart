import 'package:flutter/material.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'modality_labels.dart';

/// Modificación reservada al propietario del workspace (API lo verifica).
class VenciraModalityCatalogScreen extends StatefulWidget {
  const VenciraModalityCatalogScreen({
    super.key, required this.api, required this.workspace,
    this.onSessionExpired,
  });
  final VenciraApi api;
  final VenciraWorkspace workspace;
  final Future<void> Function()? onSessionExpired;
  @override
  State<VenciraModalityCatalogScreen> createState() => _CatalogState();
}

class _CatalogState extends State<VenciraModalityCatalogScreen> {
  List<VenciraModalityOption>? _items;
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;
  bool _unauthorized = false;
  int _seq = 0;
  AppLocalizations get _t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _seq++;
    super.dispose();
  }

  Future<void> _revoke() async {
    if (!mounted || _unauthorized) return;
    setState(() { _seq++; _unauthorized = true; _items = null; _loading = false; _failed = true; });
    try {
      await widget.onSessionExpired?.call();
    } catch (_) {
      // Preserve the revoked, data-free route while native cleanup is unacknowledged.
      return;
    }
    if (mounted && widget.onSessionExpired != null) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _load() async {
    if (_unauthorized) return;
    final token = ++_seq;
    setState(() { _loading = true; _failed = false; });
    try {
      final options = await widget.api.fetchModalities(widget.workspace.id);
      if (!mounted || token != _seq) return;
      setState(() { _items = options; _loading = false; });
    } on VenciraUnauthorized {
      if (!mounted || token != _seq) return;
      await _revoke();
    } catch (_) {
      if (!mounted || token != _seq) return;
      setState(() { _loading = false; _failed = true; });
    }
  }

  Future<String?> _askLabel({String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(initial == null ? _t.modalityAdd : _t.modalityRename),
          content: TextField(
            key: const ValueKey('modality-name'),
            controller: controller,
            maxLength: 80,
            autofocus: true,
            decoration: InputDecoration(
              labelText: _t.modalityLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
                child: Text(_t.cancel)),
            FilledButton(onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            }, child: Text(_t.save)),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<bool> _confirmDeactivate(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_t.modalityDeactivate),
        content: Text(_t.modalityDeactivateHelp + '\n' + name),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_t.modalityDeactivate)),
        ],
      ),
    ) ?? false;
  }

  Future<void> _act(Future<void> Function() callback) async {
    if (_saving || _unauthorized) return;
    setState(() => _saving = true);
    try {
      await callback();
      if (mounted) await _load();
    } on VenciraUnauthorized {
      await _revoke();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.modalityChangeFailed)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _add() async {
    final label = await _askLabel();
    if (label == null || !mounted) return;
    await _act(() async {
      await widget.api.addModality(widget.workspace.id, label);
    });
  }

  Future<void> _rename(VenciraModalityOption option) async {
    final label = await _askLabel(initial: option.label);
    if (label == null || !mounted || label == option.label) return;
    await _act(() async {
      await widget.api.editModality(widget.workspace.id, option.code, label);
    });
  }

  Future<void> _toggle(VenciraModalityOption option) async {
    if (option.active &&
        !await _confirmDeactivate(modalityCaption(context, option))) return;
    if (!mounted) return;
    await _act(() async {
      if (option.active) {
        await widget.api.removeModality(widget.workspace.id, option.code);
      } else {
        await widget.api.enableModality(widget.workspace.id, option.code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_t.modalityManage), actions: [
        IconButton(tooltip: _t.refresh, onPressed: _saving ? null : _load,
          icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: widget.workspace.role == 'owner' ? FloatingActionButton.extended(
        onPressed: _saving ? null : _add,
        icon: const Icon(Icons.add), label: Text(_t.modalityAdd),
      ) : null,
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 750),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Text(_t.modalityCatalogHint),
          const SizedBox(height: 12),
          SizedBox(height: 3, child: _loading && _items != null
            ? const LinearProgressIndicator() : null),
          if (_loading && _items == null)
            const Center(child: CircularProgressIndicator()),
          if (_failed) Column(children: [
            Text(_t.modalityChangeFailed),
            TextButton(onPressed: _load, child: Text(_t.retry)),
          ]),
          if (_items != null)
            for (final option in _items!)

            Card(child: ListTile(
              key: ValueKey('catalog-' + option.code),
              title: Text(modalityCaption(context, option)),
              subtitle: Text(option.active ?
                _t.modalityActive : _t.modalityInactive),
              trailing: widget.workspace.role != 'owner' ? null : Wrap(
                alignment: WrapAlignment.end,
                spacing: 2,
                children: [
                  IconButton(
                    tooltip: _t.modalityRename,
                    onPressed: _saving ? null : () => _rename(option),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: option.active ?
                        _t.modalityDeactivate : _t.modalityEnable,
                    onPressed: _saving ? null : () => _toggle(option),
                    icon: Icon(option.active ?
                      Icons.visibility_off_outlined : Icons.visibility_outlined),
                  ),
                ],
              ),
            )),
          const SizedBox(height: 75),
        ]),
      ))),
    );
  }
}
