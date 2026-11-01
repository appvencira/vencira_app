import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// Historial factual de acciones internas. No son entregas de avisos externos.
class VenciraOperationalHistoryScreen extends StatefulWidget {
  const VenciraOperationalHistoryScreen({
    super.key,
    required this.api,
    required this.workspaceId,
    required this.renewalId,
    required this.reminderId,
    required this.reason,
    this.onSessionExpired,
  });

  final VenciraApi api;
  final String workspaceId, renewalId, reminderId, reason;
  final Future<void> Function()? onSessionExpired;

  @override
  State<VenciraOperationalHistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends State<VenciraOperationalHistoryScreen> {
  final List<VenciraOperationalEvent> _events = [];
  bool _loading = false;
  bool _failed = false;
  bool _unauthorized = false;
  bool _hasNext = false;
  int _nextPage = 1;
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
      _unauthorized = true;
      _events.clear();
      _loading = false;
    });
    try {
      await widget.onSessionExpired?.call();
    } catch (_) {
      // The parent cleanup barrier failed. Keep the revoked route data-free
      // and do not navigate past an unacknowledged native cancellation.
      return;
    }
    if (mounted && widget.onSessionExpired != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _load({bool reload = false}) async {
    if (_loading) return;
    final request = ++_generation;
    final page = reload ? 1 : _nextPage;
    setState(() { _loading = true; _failed = false; });
    try {
      final result = await widget.api.fetchOperationalHistory(
        widget.workspaceId, widget.renewalId, widget.reminderId, page: page);
      if (!mounted || request != _generation) return;
      setState(() {
        if (page == 1) _events.clear();
        _events.addAll(result.items);
        _hasNext = result.hasNext;
        _nextPage = page + 1;
        _loading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || request != _generation) return;
      await _expire();
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() { _loading = false; _failed = true; });
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

  String _action(String action) => switch (action) {
    'planned' => t.inboxHistoryPlanned,
    'cancelled' => t.inboxHistoryCancelled,
    'complete' => t.inboxHistoryCompleted,
    'tomorrow' => t.inboxHistoryTomorrow,
    'another_day' => t.inboxHistoryAnotherDay,
    _ => t.opStateUnknown,
  };

  IconData _icon(String action) => switch (action) {
    'planned' => Icons.event_available_outlined,
    'complete' => Icons.check_circle_outline,
    'cancelled' => Icons.event_busy_outlined,
    'tomorrow' => Icons.update_outlined,
    'another_day' => Icons.event_repeat_outlined,
    _ => Icons.history,
  };

  Widget _event(VenciraOperationalEvent event) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final timestamp = DateFormat('dd/MM/yyyy · HH:mm')
        .format(event.occurredAt.toLocal());
    final scheduled = DateFormat('dd/MM/yyyy').format(event.scheduledFor);
    return Card.outlined(
      key: ValueKey('history-event-${event.id}'),
      margin: const EdgeInsets.only(bottom: 9),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              color: colors.primaryContainer),
            child: Icon(_icon(event.action), size: 19,
              color: colors.onPrimaryContainer)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_action(event.action),
                style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(timestamp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (event.previousState.isNotEmpty)
                Text('${_state(event.previousState)} → ${_state(event.nextState)}',
                  style: theme.textTheme.bodyMedium),
              Text('${t.inboxHistoryScheduled}: $scheduled',
                style: theme.textTheme.bodyMedium),
              const SizedBox(height: 3),
              Text('${t.inboxHistoryActor}: ${event.actor ?? t.inboxHistoryUnknownActor}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant)),
            ],
          )),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(t.inboxHistoryTitle),
        actions: [
          IconButton(
            tooltip: t.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : () => _load(reload: true)),
        ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.reason, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(t.inboxDescription, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            SizedBox(height: 3, child: _loading && _events.isNotEmpty
              ? const LinearProgressIndicator() : null),
            if (_loading && _events.isEmpty)
              const Padding(padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator())),
            if (_unauthorized) Text(t.loginRequired),
            if (_failed) Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.inboxHistoryError),
                TextButton(onPressed: () => _load(reload: _events.isEmpty),
                  child: Text(t.retry)),
              ]),
            if (!_loading && !_failed && !_unauthorized && _events.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(t.inboxHistoryEmpty)),
            if (!_unauthorized)
              for (final event in _events) _event(event),
            if (_hasNext && !_loading && !_unauthorized)
              Center(child: TextButton.icon(
                key: const ValueKey('history-more'),
                onPressed: _load,
                icon: const Icon(Icons.expand_more),
                label: Text(t.inboxHistoryMore))),
          ],
        ),
      ))),
    );
  }
}
