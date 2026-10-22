import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// Vista mensual: los indicadores representan anotaciones, no envíos.
class VenciraMonthAgendaScreen extends StatefulWidget {
  const VenciraMonthAgendaScreen({
    super.key, required this.api, required this.workspace, required this.initialMonth,
  });

  final VenciraApi api;
  final VenciraWorkspace workspace;
  final DateTime initialMonth;

  @override
  State<VenciraMonthAgendaScreen> createState() => _VenciraMonthAgendaScreenState();
}

class _VenciraMonthAgendaScreenState extends State<VenciraMonthAgendaScreen> {
  late DateTime _month;
  VenciraAgendaMonth? _summary;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;
  bool _unauthorized = false;
  AppLocalizations get _t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialMonth.year, widget.initialMonth.month, 1);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final sequence = ++_generation;
    final requested = _month;
    setState(() {
      _summary = null;
      _loading = true;
      _failed = false;
      _unauthorized = false;
    });
    try {
      final result = await widget.api.fetchAgendaMonth(widget.workspace.id, requested);
      if (!mounted || sequence != _generation) return;
      setState(() {
        _summary = result;
        _loading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _generation) return;
      setState(() {
        _loading = false;
        _unauthorized = true;
      });
    } catch (_) {
      if (!mounted || sequence != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _changeMonth(int offset) {
    final target = DateTime(_month.year, _month.month + offset, 1);
    if (target.year < 2000 || target.year > 2100) return;
    setState(() => _month = target);
    _load();
  }

  void _goToday() {
    final now = DateTime.now();
    setState(() => _month = DateTime(now.year, now.month, 1));
    _load();
  }

  Widget _dot(Color color, {bool filled = true, Key? key}) => Container(
    key: key,
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: filled ? color : Colors.transparent,
      border: Border.all(color: color, width: 1.5),
    ),
  );

  Widget _legend(String text, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _dot(color),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.labelSmall),
    ],
  );

  Widget _marks(String day, String kind, VenciraMonthCounts count, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (count.pending > 0)
        _dot(color, key: ValueKey('month-mark-' + day + '-' + kind + '-pending')),
      if (count.pending > 0 && count.contacted > 0)
        const SizedBox(width: 2),
      if (count.contacted > 0)
        _dot(color, filled: false,
            key: ValueKey('month-mark-' + day + '-' + kind + '-contacted')),
    ]);
  }

  String _iso(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  Widget _calendar(String locale, ColorScheme colors) {
    final first = DateTime(_month.year, _month.month, 1);
    final count = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = first.weekday - DateTime.monday;
    final activity = {for (final day in _summary!.days) _iso(day.day): day};
    final now = DateTime.now();

    return Column(children: [
      Row(children: List.generate(7, (i) {
        return Expanded(child: Center(child: Text(
          DateFormat.E(locale).format(DateTime(2024, 1, i + 1)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        )));
      })),
      const SizedBox(height: 7),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: offset + count,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7, crossAxisSpacing: 3, mainAxisSpacing: 3,
          childAspectRatio: 0.83,
        ),
        itemBuilder: (context, i) {
          if (i < offset) return const SizedBox.shrink();
          final date = DateTime(_month.year, _month.month, i - offset + 1);
          final key = _iso(date);
          final info = activity[key];
          final today = now.year == date.year && now.month == date.month &&
              now.day == date.day;
          final description = StringBuffer(
            DateFormat('EEEE d MMMM yyyy', locale).format(date),
          );
          if (info != null) {
            for (final group in [
              (_t.agendaExpiryEvent, info.expiry),
              (_t.noticeLabel, info.notice),
              (_t.agendaMonthReminder, info.reminder),
            ]) {
              if (group.$2.total > 0) {
                description.write(' · ' + group.$1 + ': ' +
                    group.$2.pending.toString() + ' ' + _t.pending + ', ' +
                    group.$2.contacted.toString() + ' ' + _t.contacted);
              }
            }
          }
          return Semantics(
            button: true,
            label: description.toString(),
            child: Material(
              color: today ? colors.primaryContainer : colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                key: ValueKey('month-day-' + key),
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(context, date),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Column(
                    children: [
                      Text(date.day.toString(),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: today ? FontWeight.bold : FontWeight.normal,
                          color: today ? colors.onPrimaryContainer : colors.onSurface,
                        ),
                      ),
                      if (info != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 3,
                          runSpacing: 3,
                          children: [
                            _marks(key, 'expiry', info.expiry, colors.error),
                            _marks(key, 'notice', info.notice, colors.tertiary),
                            _marks(key, 'reminder', info.reminder, colors.primary),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(_t.agendaMonthTitle),
        actions: [
          IconButton(tooltip: _t.refresh, onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Row(children: [
            IconButton(
              key: const ValueKey('month-previous'),
              tooltip: _t.agendaPreviousMonth,
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(child: Text(DateFormat.yMMMM(locale).format(_month),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
              key: const ValueKey('month-next'),
              tooltip: _t.agendaNextMonth,
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          Center(child: TextButton.icon(onPressed: _goToday,
            icon: const Icon(Icons.today), label: Text(_t.agendaToday))),
          Wrap(
            spacing: 13, runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legend(_t.agendaExpiryEvent, colors.error),
              _legend(_t.noticeLabel, colors.tertiary),
              _legend(_t.agendaMonthReminder, colors.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(_t.agendaMonthStatusLegend, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_unauthorized)
            Text(_t.loginRequired)
          else if (_failed)
            Column(children: [
              Text(_t.agendaMonthLoadError),
              TextButton(onPressed: _load, child: Text(_t.retry)),
            ])
          else if (_summary != null) ...[
            _calendar(locale, colors),
            const SizedBox(height: 12),
            if (_summary!.days.isEmpty)
              Text(_t.agendaMonthEmpty, textAlign: TextAlign.center),
            Text(_t.agendaMonthHelp, textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          ],
        ]),
      ))),
    );
  }
}
