import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// §11: pantalla exclusivamente web de escritorio. Los empleados sin
/// autorización explícita del §18 no disponen de acceso.
class VenciraResultsScreen extends StatefulWidget {
  const VenciraResultsScreen({super.key, required this.api, required this.workspace});
  final VenciraApi api;
  final VenciraWorkspace workspace;

  @override
  State<VenciraResultsScreen> createState() => _ResultsState();
}

class _ResultsState extends State<VenciraResultsScreen> {
  String _period = 'month';
  late int _year;
  late int _slot;
  int _sequence = 0;
  VenciraResultsSummary? _summary;
  bool _loading = true;
  bool _error = false;
  bool _unauthorized = false;

  AppLocalizations get _t => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _slot = now.month;
    _load();
  }

  @override
  void dispose() {
    _sequence++;
    super.dispose();
  }

  Future<void> _load() async {
    final sequence = ++_sequence;
    setState(() {
      _loading = true; _summary = null; _error = false; _unauthorized = false;
    });
    try {
      final result = await widget.api.fetchResults(
        widget.workspace.id, period: _period, year: _year,
        month: _period == 'month' ? _slot : null,
        quarter: _period == 'quarter' ? _slot : null,
      );
      if (!mounted || sequence != _sequence) return;
      setState(() { _summary = result; _loading = false; });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _sequence) return;
      setState(() { _loading = false; _unauthorized = true; });
    } catch (_) {
      if (!mounted || sequence != _sequence) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  void _setPeriod(String period) {
    if (_loading || period == _period ||
        !const ['month', 'quarter', 'year'].contains(period)) return;
    final now = DateTime.now();
    setState(() {
      _period = period;
      _year = now.year;
      _slot = period == 'month' ? now.month :
          period == 'quarter' ? (now.month - 1) ~/ 3 + 1 : 1;
    });
    _load();
  }

  void _shift(int step) {
    if (_loading) return;
    final limit = _period == 'month' ? 12 :
                  _period == 'quarter' ? 4 : 1;
    int target = _slot + step;
    int year = _year;
    if (target < 1) { year--; target = limit; }
    if (target > limit) { year++; target = 1; }
    if (year < 2000 || year > 2100) return;
    setState(() { _year = year; _slot = target; });
    _load();
  }

  String get _label {
    if (_period == 'year') return '$_year';
    if (_period == 'quarter') return '${_t.resultsQuarter} $_slot · $_year';
    final locale = Localizations.localeOf(context).languageCode;
    return DateFormat.yMMMM(locale).format(DateTime(_year, _slot));
  }

  Widget _metric(String label, int number, IconData icon) {
    final color = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color.primary),
          const SizedBox(height: 12),
          Text('$number',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    return Scaffold(
      appBar: AppBar(title: Text(_t.resultsTitle)),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text(widget.workspace.name,
            style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(_t.resultsDescription,
            style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final entry in [
              ('month', _t.resultsMonth),
              ('quarter', _t.resultsQuarter),
              ('year', _t.resultsYear),
            ])
              ChoiceChip(
                key: ValueKey('results-period-${entry.$1}'),
                selected: _period == entry.$1,
                label: Text(entry.$2),
                onSelected: _loading ? null : (_) => _setPeriod(entry.$1),
              ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            IconButton(
              key: const ValueKey('results-previous'),
              tooltip: _t.previous,
              onPressed: _loading || (_year == 2000 && _slot == 1)
                  ? null : () => _shift(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(child: Text(_label, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium)),
            IconButton(
              key: const ValueKey('results-next'),
              tooltip: _t.next,
              onPressed: _loading || (_year == 2100 &&
                  (_period == 'year' || _slot ==
                    (_period == 'month' ? 12 : 4)))
                  ? null : () => _shift(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          const SizedBox(height: 18),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            )),
          if (_unauthorized) Text(_t.loginRequired),
          if (_error) ...[
            Text(_t.loadError),
            TextButton(onPressed: _load, child: Text(_t.retry)),
          ],
          if (!_loading && summary != null)
            LayoutBuilder(builder: (context, dimensions) {
              final wide = dimensions.maxWidth >= 520;
              final width = wide ? (dimensions.maxWidth - 12) / 2
                                 : dimensions.maxWidth;
              return Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: width, child: _metric(
                    _t.resultsWon, summary.won, Icons.check_circle_outline)),
                SizedBox(width: width, child: _metric(
                    _t.resultsDeclined, summary.declined, Icons.event_repeat)),
                SizedBox(width: width, child: _metric(
                    _t.resultsDiscarded, summary.discarded, Icons.archive_outlined)),
                SizedBox(width: width, child: _metric(
                    _t.resultsPending, summary.pending, Icons.schedule_outlined)),
              ]);
            }),
        ]),
      ))),
    );
  }
}
