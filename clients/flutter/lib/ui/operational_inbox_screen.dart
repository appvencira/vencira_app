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

  /// Igual que Preferencias: fila táctil, sin flechas ni botones repetidos.
  Widget _sheetRow(BuildContext sheetContext, String label,
      IconData icon, VoidCallback onTap) {
    final colors = Theme.of(sheetContext).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(children: [
              Icon(icon, size: 20, color: colors.onSurfaceVariant),
              const SizedBox(width: 13),
              Expanded(child: Text(label,
                style: Theme.of(sheetContext).textTheme.bodyLarge)),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _showActions(VenciraInboxItem item) async {
    if (_acting || _loading) return;
    final colors = Theme.of(context).colorScheme;
    final chosen = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: colors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.opActions,
                  style: Theme.of(sheetContext).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _sheetRow(sheetContext, t.inboxOpenDetail,
                  Icons.open_in_new, () => Navigator.pop(sheetContext, 'detail')),
                _sheetRow(sheetContext, t.opDone,
                  Icons.check_circle_outline,
                  () => Navigator.pop(sheetContext, 'complete')),
                _sheetRow(sheetContext, t.opTomorrow,
                  Icons.wb_twilight_outlined,
                  () => Navigator.pop(sheetContext, 'tomorrow')),
                _sheetRow(sheetContext, t.opChoose,
                  Icons.event_outlined,
                  () => Navigator.pop(sheetContext, 'another_day')),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || chosen == null) return;
    switch (chosen) {
      case 'detail':
        await _openDetail(item);
        return;
      case 'complete':
        await _action(item, 'complete');
        return;
      case 'tomorrow':
        await _action(item, 'tomorrow');
        return;
      case 'another_day':
        await _otherDay(item);
        return;
    }
  }

  Widget _summaryValue(String label, int count, {Color? color}) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 3),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(count.toString(), style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700, color: color ?? colors.onSurface)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant)),
      ]),
    ));
  }

  Widget _summary(VenciraOperationalInbox inbox) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20)),
      child: Row(children: [
        _summaryValue(t.inboxOverdue, inbox.overdue,
          color: inbox.overdue > 0 ? colors.error : null),
        Container(height: 38, width: 1, color: colors.outlineVariant),
        _summaryValue(t.inboxToday, inbox.today),
        Container(height: 38, width: 1, color: colors.outlineVariant),
        _summaryValue(t.inboxUpcoming, inbox.upcoming),
      ]),
    );
  }

  Widget _scopeTile({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final selected = _scope == value;
    final foreground = selected
        ? colors.onPrimaryContainer : colors.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: selected
            ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('inbox-scope-$value'),
          onTap: _loading || _acting ? null : () => _selectScope(value),
          borderRadius: BorderRadius.circular(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 77),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 13, vertical: 11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(icon, size: 19, color: foreground),
                    const Spacer(),
                    if (selected) Icon(Icons.check_circle_rounded,
                      size: 19, color: colors.primary),
                  ]),
                  const SizedBox(height: 6),
                  Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected
                          ? FontWeight.w700 : FontWeight.w500,
                      color: foreground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _item(VenciraInboxItem item) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final today = _inbox?.day;
    final isToday = today != null &&
      item.reminder.day.year == today.year &&
      item.reminder.day.month == today.month &&
      item.reminder.day.day == today.day;
    final label = item.overdue ? t.inboxOverdue :
      (isToday ? t.inboxToday : t.inboxUpcoming);
    final tint = item.overdue ? colors.error :
      (isToday ? colors.primary : colors.tertiary);
    return Card.outlined(
      key: ValueKey('inbox-item-' + item.reminder.id),
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant)),
      child: InkWell(
        onTap: _acting ? null : () => _openDetail(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 15, 8, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.reference,
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 7),
                  Text(item.reminder.reason,
                    style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Wrap(spacing: 10, runSpacing: 7,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_outlined, size: 16,
                          color: colors.onSurfaceVariant),
                        const SizedBox(width: 5),
                        Text(DateFormat('dd/MM/yyyy').format(item.reminder.day),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant)),
                      ]),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: Color.lerp(colors.surface, tint, 0.13),
                          borderRadius: BorderRadius.circular(9)),
                        child: Text(label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: tint, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ],
              )),
              IconButton(
                key: ValueKey('inbox-more-' + item.reminder.id),
                onPressed: _acting ? null : () => _showActions(item),
                tooltip: t.opActions,
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          ),
        ),
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
            _summary(inbox),
            const SizedBox(height: 18),
          ],
          LayoutBuilder(builder: (context, constraints) {
            const gap = 10.0;
            final width = (constraints.maxWidth - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [
              SizedBox(width: width, child: _scopeTile(
                value: 'due', label: t.inboxDue,
                icon: Icons.inbox_outlined)),
              SizedBox(width: width, child: _scopeTile(
                value: 'overdue', label: t.inboxOverdue,
                icon: Icons.schedule_outlined)),
              SizedBox(width: width, child: _scopeTile(
                value: 'today', label: t.inboxToday,
                icon: Icons.today_outlined)),
              SizedBox(width: width, child: _scopeTile(
                value: 'upcoming', label: t.inboxUpcoming,
                icon: Icons.upcoming)),
            ]);
          }),
          const SizedBox(height: 10),
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
