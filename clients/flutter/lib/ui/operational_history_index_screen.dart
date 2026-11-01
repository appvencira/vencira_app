import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'operational_history_screen.dart';

/// Entrada visible desde cualquier ficha, incluidas las cerradas.
/// Se consultan los avisos guardados de esa anotación sin mutaciones.
class VenciraOperationalHistoryIndexScreen extends StatefulWidget {
  const VenciraOperationalHistoryIndexScreen({
    super.key,
    required this.api,
    required this.workspaceId,
    required this.renewalId,
    this.onSessionExpired,
  });

  final VenciraApi api;
  final String workspaceId, renewalId;
  final Future<void> Function()? onSessionExpired;

  @override
  State<VenciraOperationalHistoryIndexScreen> createState() =>
      _OperationalHistoryIndexState();
}

class _OperationalHistoryIndexState
    extends State<VenciraOperationalHistoryIndexScreen> {
  List<VenciraOperationalReminder>? _rows;
  bool _loading = false;
  bool _failed = false;
  bool _unauthorized = false;
  int _generation = 0;

  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _expire() async {
    if (!mounted || _unauthorized) return;
    setState(() {
      _generation++;
      _rows = null;
      _loading = false;
      _unauthorized = true;
    });
    await widget.onSessionExpired?.call();
    if (mounted && widget.onSessionExpired != null) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() { _loading = true; _failed = false; });
    try {
      final rows = await widget.api.fetchOperationalReminders(
        widget.workspaceId, widget.renewalId);
      if (!mounted || _generation != generation) return;
      setState(() {
        _rows = rows;
        _loading = false;
        _unauthorized = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || _generation != generation) return;
      await _expire();
    } catch (_) {
      if (!mounted || _generation != generation) return;
      setState(() { _failed = true; _loading = false; });
    }
  }

  String _state(String state) => switch (state) {
    'planned' => t.opStatePlanned,
    'pending' => t.opStatePending,
    'snoozed' => t.opStateSnoozed,
    'completed' => t.opStateCompleted,
    'cancelled' => t.opStateCancelled,
    _ => t.opStateUnknown,
  };

  void _open(VenciraOperationalReminder reminder) {
    Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraOperationalHistoryScreen(
        api: widget.api,
        workspaceId: widget.workspaceId,
        renewalId: widget.renewalId,
        reminderId: reminder.id,
        reason: reminder.reason,
        onSessionExpired: _expire),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.inboxHistoryIndexTitle),
        actions: [
          IconButton(
            tooltip: t.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.inboxHistoryIndexDescription,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 14),
            SizedBox(height: 3, child: _loading && _rows != null
                ? const LinearProgressIndicator() : null),
            if (_loading && _rows == null)
              const Padding(padding: EdgeInsets.all(28),
                child: Center(child: CircularProgressIndicator())),
            if (_unauthorized) Text(t.loginRequired),
            if (_failed) Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.inboxHistoryError),
                TextButton(onPressed: _load, child: Text(t.retry)),
              ],
            ),
            if (!_loading && !_failed && !_unauthorized &&
                (_rows?.isEmpty ?? false))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 22),
                child: Text(t.inboxHistoryIndexEmpty)),
            if (!_unauthorized)
              for (final reminder in _rows ?? <VenciraOperationalReminder>[])
                Card.outlined(
                  margin: const EdgeInsets.only(bottom: 9),
                  child: ListTile(
                    key: ValueKey('history-reminder-' + reminder.id),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 9),
                    title: Text(reminder.reason,
                      maxLines: 3, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${DateFormat('dd/MM/yyyy').format(reminder.day)} · '
                      '${_state(reminder.state)}'),
                    trailing: const Icon(Icons.history_outlined),
                    onTap: () => _open(reminder),
                  ),
                ),
          ],
        ),
      ))),
    );
  }
}
