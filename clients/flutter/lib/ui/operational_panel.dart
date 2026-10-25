import 'dart:math';
import 'package:flutter/material.dart';
import '../api/vencira_api.dart';

/// Control de avisos internos. No representa una notificación enviada.
class VenciraOperationalPanel extends StatefulWidget {
  const VenciraOperationalPanel({super.key, required this.api,
    required this.workspaceId, required this.renewalId});
  final VenciraApi api;
  final String workspaceId, renewalId;

  @override
  State<VenciraOperationalPanel> createState() => _OperationalPanelState();
}

class _OperationalPanelState extends State<VenciraOperationalPanel> {
  List<VenciraOperationalReminder>? _rows;
  VenciraReminderDraft? _draft;
  bool _busy = false;
  String? _error;
  final Map<int, TextEditingController> _controllers = {};
  String _key() {
    final rand = Random.secure();
    final b = List<int>.generate(16, (_) => rand.nextInt(256));
    b[6] = (b[6] & 15) | 64; b[8] = (b[8] & 63) | 128;
    final h = b.map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0,8)}-${h.substring(8,12)}-${h.substring(12,16)}-${h.substring(16,20)}-${h.substring(20)}';
  }

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }
  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      final draft = await widget.api.fetchReminderDraft(widget.workspaceId, widget.renewalId);
      final rows = await widget.api.fetchOperationalReminders(widget.workspaceId, widget.renewalId);
      if (!mounted) return;
      for (final controller in _controllers.values) { controller.dispose(); }
      _controllers.clear();
      for (final d in draft.daysBefore) {
        _controllers[d] = TextEditingController(text: draft.reasonsByDay['$d'] ?? '');
      }
      setState(() { _draft = draft; _rows = rows; });
    } catch (_) {
      if (mounted) setState(() => _error = 'No se han podido consultar los avisos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveReasons() async {
    final draft = _draft;
    if (_busy || draft == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      final reasons = <String, String>{};
      for (final entry in _controllers.entries) {
        final value = entry.value.text.trim();
        if (value.length > 160) throw const FormatException('Motivo demasiado largo');
        if (value.isNotEmpty) reasons['${entry.key}'] = value;
      }
      final result = await widget.api.saveReminderDraft(
        widget.workspaceId, widget.renewalId,
        revision: draft.revision, daysBefore: draft.daysBefore,
        reasonsByDay: reasons);
      if (!mounted) return;
      setState(() => _draft = result);
    } on VenciraConflictException {
      if (mounted) setState(() => _error = 'Los datos han cambiado. Actualiza antes de guardar.');
    } catch (_) {
      if (mounted) setState(() => _error = 'No se han podido guardar los motivos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final draft = _draft;
    if (_busy || draft == null || !draft.isPersisted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.activateOperationalReminders(
        widget.workspaceId, widget.renewalId, draft.revision);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se han podido activar los avisos internos. Comprueba las fechas.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _act(VenciraOperationalReminder row, String action, {int? days}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.updateOperationalReminder(widget.workspaceId,
        widget.renewalId, row, action, _key(), daysLater: days);
    } catch (_) {
      if (mounted) setState(() => _error = 'No se ha podido actualizar. Revisa los datos.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child:
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Avisos internos', style: Theme.of(context).textTheme.titleMedium),
        const Text('Se guardan en la agenda. No se envían notificaciones todavía.'),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(
          color: Theme.of(context).colorScheme.error)),
        if (draft != null) ...[
          for (final day in draft.daysBefore)
            TextField(controller: _controllers[day], maxLength: 160,
              decoration: InputDecoration(labelText: 'Motivo · $day días antes')),
          TextButton(onPressed: _busy ? null : _saveReasons,
            child: const Text('Guardar motivos')),
          FilledButton(onPressed: _busy || !draft.isPersisted ? null : _activate,
            child: const Text('Programar avisos internos')),
        ],
        if (_rows == null) TextButton(onPressed: _busy ? null : _load,
          child: const Text('Cargar avisos')),
        for (final reminder in _rows ?? <VenciraOperationalReminder>[])
          ListTile(
            title: Text(reminder.reason),
            subtitle: Text('${reminder.day.day}/${reminder.day.month}/${reminder.day.year} · ${reminder.state}'),
            trailing: reminder.state == 'completed' || reminder.state == 'cancelled'
              ? null : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'another_day') {
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    showDatePicker(
                      context: context,
                      firstDate: today.add(const Duration(days: 2)),
                      lastDate: today.add(const Duration(days: 365)),
                      initialDate: today.add(const Duration(days: 7)),
                    ).then((selected) {
                      if (selected == null || !mounted) return;
                      final days = DateTime.utc(selected.year, selected.month, selected.day)
                        .difference(DateTime.utc(today.year, today.month, today.day)).inDays;
                      _act(reminder, value, days: days);
                    });
                  } else {
                    _act(reminder, value);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'complete', child: Text('Completada')),
                  PopupMenuItem(value: 'tomorrow', child: Text('Mañana')),
                  PopupMenuItem(value: 'another_day', child: Text('Elegir fecha')),
                ],
              ),
          ),
      ]),
    ));
  }
}
