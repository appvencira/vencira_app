import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'month_agenda_screen.dart';
import 'renewal_detail_screen.dart';

/// Primera vista de la agenda tipo papel. Sólo presenta eventos previstos.
/// «Recuérdamelo», cierres y notificaciones entregadas aún no están modelados.
class VenciraDayAgendaScreen extends StatefulWidget {
  const VenciraDayAgendaScreen({
    super.key,
    required this.api,
    required this.workspace,
    this.initialDay,
  });

  final VenciraApi api;
  final VenciraWorkspace workspace;
  final DateTime? initialDay;

  @override
  State<VenciraDayAgendaScreen> createState() => _VenciraDayAgendaScreenState();
}

class _VenciraDayAgendaScreenState extends State<VenciraDayAgendaScreen> {
  late DateTime _selectedDay;
  VenciraAgendaDayPage? _agenda;
  int _page = 1;
  int _generation = 0;
  bool _loading = false;
  bool _failed = false;
  bool _unauthorized = false;

  AppLocalizations get _t => AppLocalizations.of(context)!;

  static DateTime _civilDate(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  void initState() {
    super.initState();
    _selectedDay = _civilDate(widget.initialDay ?? DateTime.now());
    _loadDay(1);
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _loadDay(int page) async {
    final sequence = ++_generation;
    final requestedDay = _selectedDay;
    setState(() {
      _agenda = null; // No revelar anotaciones del día anterior al navegar.
      _page = page;
      _loading = true;
      _failed = false;
      _unauthorized = false;
    });
    try {
      final result = await widget.api.fetchAgendaDay(
        widget.workspace.id, requestedDay, page: page,
      );
      if (!mounted || sequence != _generation) return;
      setState(() {
        _agenda = result;
        _loading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _generation) return;
      setState(() {
        _agenda = null;
        _loading = false;
        _unauthorized = true;
      });
    } catch (_) {
      if (!mounted || sequence != _generation) return;
      setState(() {
        _agenda = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _chooseDay(DateTime day) {
    final civil = _civilDate(day);
    if (civil == _selectedDay) {
      if (_page != 1) _loadDay(1);
      return;
    }
    setState(() => _selectedDay = civil);
    _loadDay(1);
  }

  void _stepDay(int offset) {
    _chooseDay(DateTime(
      _selectedDay.year, _selectedDay.month, _selectedDay.day + offset,
    ));
  }

  Future<void> _openDatePicker() async {
    final chosen = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: _selectedDay,
      helpText: _t.agendaChooseDay,
    );
    if (mounted && chosen != null) _chooseDay(chosen);
  }

  Future<void> _openMonth() async {
    final chosen = await Navigator.of(context).push<DateTime>(
      MaterialPageRoute(
        builder: (_) => VenciraMonthAgendaScreen(
          api: widget.api,
          workspace: widget.workspace,
          initialMonth: _selectedDay,
        ),
      ),
    );
    if (mounted && chosen != null) _chooseDay(chosen);
  }

  Future<void> _openDetail(String renewalId) async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraRenewalDetailScreen(
        api: widget.api, workspace: widget.workspace, renewalId: renewalId,
      ),
    ));
    if (mounted) _loadDay(1);
  }

  Widget _weekStrip(String locale, ColorScheme colors) {
    final monday = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day - (_selectedDay.weekday - DateTime.monday),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth / 7).clamp(46.0, 88.0).toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final day = DateTime(monday.year, monday.month, monday.day + index);
            final selected = day == _selectedDay;
            return SizedBox(
              width: itemWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: DateFormat('EEEE d MMMM yyyy', locale).format(day),
                  child: InkWell(
                    key: ValueKey('agenda-weekday-$index'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _chooseDay(day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? colors.primaryContainer
                            : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? colors.primary : colors.outlineVariant,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat.E(locale).format(day),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${day.day}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _eventCard(VenciraAgendaEntry entry, String locale) {
    final renewal = entry.renewal;
    return Card(
      child: InkWell(
        key: ValueKey('agenda-annotation-' + renewal.id),
        onTap: () => _openDetail(renewal.id),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.event_note_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(renewal.reference,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    '${_t.expiresOn} ${DateFormat('dd/MM/yyyy', locale).format(renewal.expiresOn)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (renewal.noticeDeadlineOn != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${_t.noticeLabel}: ${DateFormat('dd/MM/yyyy', locale).format(renewal.noticeDeadlineOn!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.events.map((event) {
                      if (event.kind == 'expiry') {
                        return Chip(
                          avatar: const Icon(Icons.event_available_outlined, size: 18),
                          label: Text(_t.agendaExpiryEvent),
                        );
                      }
                      if (event.kind == 'notice_deadline') {
                        return Chip(
                          avatar: const Icon(Icons.event_busy_outlined, size: 18),
                          label: Text(_t.agendaContractualNotice),
                        );
                      }
                      return Chip(
                        avatar: const Icon(Icons.notifications_none, size: 18),
                        label: Text(event.basis == 'notice_deadline'
                            ? _t.agendaPlannedNotice
                            : _t.agendaPlannedReminder),
                      );
                    }).toList(growable: false),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _dayContents(String locale) {
    if (_loading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: CircularProgressIndicator(),
      ));
    }
    if (_unauthorized) return Text(_t.loginRequired);
    if (_failed) {
      return Column(
        children: [
          Text(_t.agendaLoadError),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => _loadDay(_page),
            child: Text(_t.retry),
          ),
        ],
      );
    }
    final agenda = _agenda;
    if (agenda == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_t.agendaDayEntries}: ${agenda.total}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (agenda.entries.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(_t.agendaEmptyDay),
            ),
          )
        else
          ...agenda.entries.map((entry) => _eventCard(entry, locale)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _page > 1 ? () => _loadDay(_page - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(_t.previous),
            ),
            Text('${_t.page} $_page'),
            OutlinedButton.icon(
              onPressed: agenda.hasNext ? () => _loadDay(_page + 1) : null,
              icon: const Icon(Icons.chevron_right),
              label: Text(_t.next),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final colors = Theme.of(context).colorScheme;
    final dateText = DateFormat('EEEE d MMMM yyyy', locale).format(_selectedDay);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t.agendaTitle),
        actions: [
          IconButton(
            tooltip: _t.refresh,
            onPressed: _loading ? null : () => _loadDay(_page),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft):
                () => _stepDay(-1),
            const SingleActivator(LogicalKeyboardKey.arrowRight):
                () => _stepDay(1),
          },
          child: Focus(
            autofocus: true,
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity > 250) _stepDay(-1);
                if (velocity < -250) _stepDay(1);
              },
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(dateText,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          IconButton.outlined(
                            tooltip: _t.agendaPreviousDay,
                            onPressed: () => _stepDay(-1),
                            icon: const Icon(Icons.chevron_left),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: () => _chooseDay(DateTime.now()),
                            icon: const Icon(Icons.today),
                            label: Text(_t.agendaToday),
                          ),
                          IconButton.outlined(
                            tooltip: _t.agendaNextDay,
                            onPressed: () => _stepDay(1),
                            icon: const Icon(Icons.chevron_right),
                          ),
                          OutlinedButton.icon(
                            onPressed: _openDatePicker,
                            icon: const Icon(Icons.calendar_month),
                            label: Text(_t.agendaChooseDay),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('agenda-open-month'),
                            onPressed: _openMonth,
                            icon: const Icon(Icons.calendar_view_month),
                            label: Text(_t.agendaMonthOpen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _weekStrip(locale, colors),
                      const SizedBox(height: 22),
                      _dayContents(locale),
                      const SizedBox(height: 12),
                      Text(_t.agendaForecastDisclaimer,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
