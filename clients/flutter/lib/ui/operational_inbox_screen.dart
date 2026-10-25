import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'renewal_detail_screen.dart';

/// B: bandeja de ocurrencias persistidas, nunca notificaciones entregadas.
class VenciraOperationalInboxScreen extends StatefulWidget {
  const VenciraOperationalInboxScreen({
    super.key, required this.api, required this.workspace,
  });
  final VenciraApi api;
  final VenciraWorkspace workspace;

  @override
  State<VenciraOperationalInboxScreen> createState() => _InboxState();
}

class _InboxState extends State<VenciraOperationalInboxScreen> {
  VenciraOperationalInbox? _inbox;
  String _scope = 'due';
  bool _loading = false;
  bool _failed = false;
  bool _unauthorized = false;
  bool _acting = false;
  int _page = 1;
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

  Future<void> _load({int page = 1}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true; _failed = false; _unauthorized = false;
      _inbox = null; _page = page;
    });
    try {
      final now = DateTime.now();
      final civil = DateTime(now.year, now.month, now.day);
      final data = await widget.api.fetchOperationalInbox(
        widget.workspace.id, civil, scope: _scope, page: page,
      );
      if (!mounted || generation != _generation) return;
      setState(() { _inbox = data; _loading = false; });
    } on VenciraUnauthorized {
      if (mounted && generation == _generation) setState(() {
        _unauthorized = true; _loading = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) setState(() {
        _failed = true; _loading = false;
      });
    }
  }

  void _selectScope(String value) {
    if (_loading || _acting || value == _scope) return;
    setState(() => _scope = value);
    _load();
  }

  String _retryKey() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final raw = bytes.map((b) => b.toRadixString(16).padLeft(2,'0')).join();
    return '${raw.substring(0,8)}-${raw.substring(8,12)}-${raw.substring(12,16)}-${raw.substring(16,20)}-${raw.substring(20)}';
  }

  Future<void> _action(VenciraInboxItem item, String action,
      {int? daysLater}) async {
    if (_acting || _loading) return;
    setState(() => _acting = true);
    try {
      await widget.api.updateOperationalReminder(widget.workspace.id,
        item.renewalId, item.reminder, action, _retryKey(),
        daysLater: daysLater);
      if (mounted) await _load(page: _page);
    } on VenciraConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.opConflict)));
        await _load(page: _page);
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.opActionError)));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _otherDay(VenciraInboxItem item) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: today.add(const Duration(days: 7)),
      firstDate: today.add(const Duration(days: 2)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (!mounted || selected == null) return;
    final offset = DateTime.utc(selected.year, selected.month, selected.day)
      .difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    await _action(item, 'another_day', daysLater: offset);
  }

  Future<void> _openDetail(VenciraInboxItem item) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraRenewalDetailScreen(
        api: widget.api, workspace: widget.workspace,
        renewalId: item.renewalId),
    ));
    if (mounted) _load(page: _page);
  }

  Widget _item(VenciraInboxItem item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isOverdue = item.overdue;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(item.reference,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            if (isOverdue) Chip(
              label: Text(t.inboxOverdue),
              visualDensity: VisualDensity.compact,
              backgroundColor: colors.errorContainer,
              labelStyle: TextStyle(color: colors.onErrorContainer)),
          ]),
          const SizedBox(height: 6),
          Text(item.reminder.reason, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 5),
          Text(DateFormat('dd/MM/yyyy').format(item.reminder.day),
            style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            OutlinedButton.icon(
              onPressed: _acting ? null : () => _openDetail(item),
              icon: const Icon(Icons.open_in_new, size: 17),
              label: Text(t.inboxOpenDetail)),
            OutlinedButton.icon(
              onPressed: _acting ? null : () => _action(item, 'complete'),
              icon: const Icon(Icons.check_circle_outline, size: 17),
              label: Text(t.opDone)),
            OutlinedButton.icon(
              onPressed: _acting ? null : () => _action(item, 'tomorrow'),
              icon: const Icon(Icons.wb_twilight_outlined, size: 17),
              label: Text(t.opTomorrow)),
            IconButton(
              onPressed: _acting ? null : () => _otherDay(item),
              tooltip: t.opChoose,
              icon: const Icon(Icons.event_outlined)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inbox = _inbox;
    return Scaffold(
      appBar: AppBar(title: Text(t.inboxTitle), actions: [
        IconButton(onPressed: _loading ? null : () => _load(page: _page),
          tooltip: t.refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Text(t.inboxDescription, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (inbox != null) ...[
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(label: Text('${t.inboxOverdue}: ${inbox.overdue}')),
              Chip(label: Text('${t.inboxToday}: ${inbox.today}')),
              Chip(label: Text('${t.inboxUpcoming}: ${inbox.upcoming}')),
            ]),
            const SizedBox(height: 12),
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final pair in [
              ('due', t.inboxDue), ('overdue', t.inboxOverdue),
              ('today', t.inboxToday), ('upcoming', t.inboxUpcoming),
            ]) ChoiceChip(
              label: Text(pair.$2),
              selected: pair.$1 == _scope,
              onSelected: _loading || _acting ? null : (_) => _selectScope(pair.$1),
            ),
          ]),
          if (_loading) const Padding(
            padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_unauthorized) Text(t.loginRequired),
          if (_failed) TextButton.icon(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh), label: Text(t.retry)),
          if (inbox != null) ...[
            if (inbox.items.isEmpty) Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(t.inboxEmpty)),
            for (final item in inbox.items) _item(item),
            if (_page > 1 || inbox.hasNext) Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: _page > 1 && !_loading
                    ? () => _load(page: _page - 1) : null,
                  child: Text(t.previous)),
                Text('$_page'),
                TextButton(onPressed: inbox.hasNext && !_loading
                    ? () => _load(page: _page + 1) : null,
                  child: Text(t.next)),
              ]),
          ],
        ]),
      ))),
    );
  }
}
