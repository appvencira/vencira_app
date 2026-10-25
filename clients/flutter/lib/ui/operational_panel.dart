import 'dart:math';
import 'package:flutter/material.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

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
  final Map<String, String> _lastActions = {};
  String _localizedState(String state, AppLocalizations t) => switch (state) {
    'planned' => t.opStatePlanned,
    'pending' => t.opStatePending,
    'snoozed' => t.opStateSnoozed,
    'completed' => t.opStateCompleted,
    'cancelled' => t.opStateCancelled,
    _ => t.opStateUnknown,
  };

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
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.opFetchError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _saveReasons() async {
    final draft = _draft;
    if (_busy || draft == null) return false;
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
      if (!mounted) return false;
      setState(() => _draft = result);
      return true;
    } on VenciraConflictException {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.opConflict);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.opSaveError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _activate() async {
    final draft = _draft;
    if (_busy || draft == null || !draft.isPersisted) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.activateOperationalReminders(
        widget.workspaceId, widget.renewalId, draft.revision);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.opActivateError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _load();
  }

  Future<void> _choosePreset(int day, String chosen) async {
    final controller = _controllers[day];
    if (controller == null || _busy) return;
    controller.text = chosen;
    // The previous version only changed the TextField; the draft and
    // existing planned occurrences kept their previous reasons.
    if (await _saveReasons() && mounted) {
      await _activate();
    }
  }

  Widget _sheetOption(BuildContext sheetContext, {
    required String title, required IconData icon, required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = Theme.of(sheetContext).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? colors.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(children: [
              Icon(icon, color: selected ? colors.onPrimaryContainer : colors.onSurface),
              const SizedBox(width: 18),
              Expanded(child: Text(title, style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                color: selected ? colors.onPrimaryContainer : colors.onSurface,
              ))),
              if (selected) Icon(Icons.check_circle,
                color: colors.onPrimaryContainer),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(VenciraOperationalReminder reminder) async {
    if (_busy) return;
    final t = AppLocalizations.of(context)!;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(t.opActions, textAlign: TextAlign.left,
              style: Theme.of(sheetContext).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            _sheetOption(sheetContext, title: t.opDone,
              icon: Icons.check_circle_outline,
              selected: _lastActions[reminder.id] == 'complete',
              onTap: () => Navigator.pop(sheetContext, 'complete')),
            _sheetOption(sheetContext, title: t.opTomorrow,
              icon: Icons.wb_twilight_outlined,
              selected: _lastActions[reminder.id] == 'tomorrow',
              onTap: () => Navigator.pop(sheetContext, 'tomorrow')),
            _sheetOption(sheetContext, title: t.opChoose,
              icon: Icons.event_outlined,
              selected: _lastActions[reminder.id] == 'another_day',
              onTap: () => Navigator.pop(sheetContext, 'another_day')),
          ],
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    if (chosen == 'another_day') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final selected = await showDatePicker(
        context: context,
        firstDate: today.add(const Duration(days: 2)),
        lastDate: today.add(const Duration(days: 365)),
        initialDate: today.add(const Duration(days: 7)),
      );
      if (selected == null || !mounted) return;
      final days = DateTime.utc(selected.year, selected.month, selected.day)
        .difference(DateTime.utc(today.year, today.month, today.day)).inDays;
      await _act(reminder, chosen, days: days);
    } else {
      await _act(reminder, chosen);
    }
  }

  Future<void> _act(VenciraOperationalReminder row, String action, {int? days}) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.api.updateOperationalReminder(widget.workspaceId,
        widget.renewalId, row, action, _key(), daysLater: days);
      if (mounted) setState(() => _lastActions[row.id] = action);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context)!.opActionError);
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
        Text(AppLocalizations.of(context)!.opTitle, style: Theme.of(context).textTheme.titleMedium),
        Text(AppLocalizations.of(context)!.opDescription),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!, style: TextStyle(
          color: Theme.of(context).colorScheme.error)),
        if (draft != null) ...[
          Text(AppLocalizations.of(context)!.opPresetHint),
          for (final day in draft.daysBefore) ...[
            const SizedBox(height: 18),
            Text('${AppLocalizations.of(context)!.opReason} · $day ${AppLocalizations.of(context)!.opBefore}',
              style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            TextField(
              controller: _controllers[day],
              maxLength: 160,
              maxLines: 1,
              onTap: () => _controllers[day]!.selection =
                  TextSelection(baseOffset: 0, extentOffset: _controllers[day]!.text.length),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.opCustomReason,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                suffixIcon: IconButton(
                  tooltip: AppLocalizations.of(context)!.opPresetChoose,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  onPressed: _busy ? null : () async {
                    final t = AppLocalizations.of(context)!;
                    final options = [
                      t.opPresetReview, t.opPresetContact, t.opPresetRenewal,
                      t.opPresetNonRenewal, t.opPresetDocuments,
                    ];
                    final chosen = await showModalBottomSheet<String>(
                      context: context,
                      useSafeArea: true,
                      showDragHandle: true,
                      isScrollControlled: true,
                      builder: (sheetContext) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(t.opPresetLabel,
                              textAlign: TextAlign.left,
                              style: Theme.of(sheetContext).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 18),
                            ...options.map((option) => _sheetOption(
                              sheetContext,
                              title: option,
                              icon: Icons.bookmark_outline,
                              selected: _controllers[day]?.text == option,
                              onTap: () => Navigator.pop(sheetContext, option),
                            )),
                          ],
                        ),
                      ),
                    );
                    if (chosen != null && mounted) {
                      await _choosePreset(day, chosen);
                    }
                  },
                ),
              ),
            ),
          ],
          TextButton(onPressed: _busy ? null : _saveReasons,
            child: Text(AppLocalizations.of(context)!.opSave)),
          FilledButton(onPressed: _busy || !draft.isPersisted ? null : _activate,
            child: Text(AppLocalizations.of(context)!.opActivate)),
        ],
        if (_rows == null) TextButton(onPressed: _busy ? null : _load,
          child: Text(AppLocalizations.of(context)!.opLoad)),
        for (final reminder in _rows ?? <VenciraOperationalReminder>[])
          Card(margin: const EdgeInsets.symmetric(vertical: 5), child: ListTile(
            title: Text(reminder.reason),
            subtitle: Text('${reminder.day.day}/${reminder.day.month}/${reminder.day.year} · ${_localizedState(reminder.state, AppLocalizations.of(context)!)}'),
            trailing: reminder.state == 'completed' || reminder.state == 'cancelled'
              ? null : IconButton(
                tooltip: AppLocalizations.of(context)!.opActions,
                icon: const Icon(Icons.more_vert),
                onPressed: _busy ? null : () => _showActions(reminder),
              ),
          )),
      ]),
    ));
  }
}
