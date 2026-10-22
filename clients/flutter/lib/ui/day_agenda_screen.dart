import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'month_agenda_screen.dart';
import 'renewal_detail_screen.dart';
import 'modality_labels.dart';

/// Primera vista de la agenda tipo papel. Sólo presenta eventos previstos.
/// «Recuérdamelo», cierres y notificaciones entregadas aún no están modelados.
class VenciraDayAgendaScreen extends StatefulWidget {
  const VenciraDayAgendaScreen({
    super.key,
    required this.api,
    required this.workspace,
    this.initialDay,
    this.initialEntry = '',
    this.initialModality = '',
    this.initialInsurer = '',
  });

  final VenciraApi api;
  final VenciraWorkspace workspace;
  final DateTime? initialDay;
  final String initialEntry;
  final String initialModality;
  final String initialInsurer;

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
  late String _entryFilter;
  late String _modalityFilter;
  late String _insurerFilter;
  List<VenciraInsurer> _insurers = [];
  List<VenciraModalityOption> _modalities = VenciraModalityOption.defaults;

  // Solo contadores agregados y autorizados de la semana visible.
  DateTime? _weekMonday;
  Map<String, VenciraMonthDay>? _weekActivity;
  int _weekGeneration = 0;
  bool _weekError = false;

  AppLocalizations get _t => AppLocalizations.of(context)!;

  static DateTime _civilDate(DateTime day) =>
      DateTime(day.year, day.month, day.day);

  @override
  void initState() {
    super.initState();
    _selectedDay = _civilDate(widget.initialDay ?? DateTime.now());
    _entryFilter = widget.initialEntry;
    _modalityFilter = widget.initialModality;
    _insurerFilter = widget.initialInsurer;
    _loadInsurers();
    _loadModalities();
    _loadDay(1);
    _loadWeek();
  }

  @override
  void dispose() {
    _generation++;
    _weekGeneration++;
    super.dispose();
  }

  Future<void> _loadModalities() async {
    try {
      final options = await widget.api.fetchModalities(widget.workspace.id);
      if (mounted) setState(() => _modalities = options);
    } catch (_) {
      // Los 12 códigos por defecto siguen disponibles.
    }
  }

  Future<void> _loadInsurers() async {
    try {
      final companies = await widget.api.fetchInsurers(widget.workspace.id);
      if (mounted) setState(() => _insurers = companies);
    } catch (_) {
      if (mounted) setState(() => _insurers = []);
    }
  }

  void _setInsurer(String? value) {
    if (value == null || value == _insurerFilter) return;
    setState(() => _insurerFilter = value);
    _loadDay(1);
    _loadWeek(force: true);
  }

  void _setEntry(String? value) {
    if (value == null || value == _entryFilter) return;
    setState(() => _entryFilter = value);
    _loadDay(1);
    _loadWeek(force: true);
  }

  void _setModality(String? value) {
    if (value == null || value == _modalityFilter) return;
    setState(() => _modalityFilter = value);
    _loadDay(1);
    _loadWeek(force: true);
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
      final result = await widget.api.fetchFilteredAgendaDay(
        widget.workspace.id, requestedDay, page: page,
        entry: _entryFilter, modality: _modalityFilter,
        insurer: _insurerFilter,
      );
      if (!mounted || sequence != _generation) return;
      setState(() {
        _agenda = result;
        _loading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || sequence != _generation) return;
      _weekGeneration++;
      setState(() {
        _agenda = null;
        _weekActivity = null;
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

  static DateTime _weekBeginning(DateTime day) => DateTime(
    day.year, day.month, day.day - (day.weekday - DateTime.monday),
  );

  static String _dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  /// La semana puede abarcar dos meses: una o dos consultas agregadas,
  /// nunca siete listados de pólizas ni datos ajenos a la sesión.
  Future<void> _loadWeek({bool force = false}) async {
    final monday = _weekBeginning(_selectedDay);
    if (!force && _weekMonday == monday) return;
    final requestId = ++_weekGeneration;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    setState(() {
      _weekMonday = monday;
      _weekActivity = null; // No mostrar marcadores obsoletos.
      _weekError = false;
    });
    final monthStarts = <DateTime>[
      DateTime(monday.year, monday.month, 1),
      if (monday.year != sunday.year || monday.month != sunday.month)
        DateTime(sunday.year, sunday.month, 1),
    ];
    try {
      final summaries = await Future.wait([
        for (final month in monthStarts)
          if (month.year >= 2000 && month.year <= 2100)
            widget.api.fetchFilteredAgendaMonth(
              widget.workspace.id, month,
              entry: _entryFilter, modality: _modalityFilter,
              insurer: _insurerFilter,
            ),
      ]);
      if (!mounted || requestId != _weekGeneration) return;
      final allowedDays = {
        for (var i = 0; i < 7; i++)
          _dayKey(DateTime(monday.year, monday.month, monday.day + i)),
      };
      setState(() {
        _weekActivity = {
          for (final summary in summaries)
            for (final day in summary.days)
              if (allowedDays.contains(_dayKey(day.day))) _dayKey(day.day): day,
        };
      });
    } catch (_) {
      if (!mounted || requestId != _weekGeneration) return;
      setState(() {
        _weekActivity = null;
        _weekError = true; // No representar un error como semana vacía.
      });
    }
  }

  void _refreshAll() {
    _loadDay(_page);
    _loadWeek(force: true);
  }

  void _chooseDay(DateTime day) {
    final civil = _civilDate(day);
    if (civil == _selectedDay) {
      if (_page != 1) _loadDay(1);
      return;
    }
    setState(() => _selectedDay = civil);
    _loadDay(1);
    _loadWeek();
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
          entry: _entryFilter, modality: _modalityFilter,
          insurer: _insurerFilter,
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
    if (mounted) {
      _loadDay(1);
      _loadWeek(force: true);
    }
  }

  Widget _weekDot(Color color, {required bool filled, required String markerKey}) {
    return Container(
      key: ValueKey(markerKey),
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? color : Colors.transparent,
        border: Border.all(color: color, width: 1.5),
      ),
    );
  }

  Widget _weekMarks(String dateKey, VenciraMonthDay info, ColorScheme colors) {
    Widget pair(String kind, VenciraMonthCounts count, Color color) {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        if (count.pending > 0)
          _weekDot(color, filled: true,
              markerKey: 'week-mark-' + dateKey + '-' + kind + '-pending'),
        if (count.pending > 0 && count.contacted > 0)
          const SizedBox(width: 2),
        if (count.contacted > 0)
          _weekDot(color, filled: false,
              markerKey: 'week-mark-' + dateKey + '-' + kind + '-contacted'),
      ]);
    }

    return Wrap(
      spacing: 3,
      runSpacing: 3,
      alignment: WrapAlignment.center,
      children: [
        if (info.expiry.total > 0) pair('expiry', info.expiry, colors.error),
        if (info.notice.total > 0) pair('notice', info.notice, colors.tertiary),
        if (info.reminder.total > 0) pair('reminder', info.reminder, colors.primary),
      ],
    );
  }

  String _weekDayDescription(DateTime day, String locale, VenciraMonthDay? info) {
    final label = StringBuffer(DateFormat('EEEE d MMMM yyyy', locale).format(day));
    if (info != null) {
      for (final group in [
        (_t.agendaExpiryEvent, info.expiry),
        (_t.noticeLabel, info.notice),
        (_t.agendaMonthReminder, info.reminder),
      ]) {
        if (group.$2.total > 0) {
          label.write(' · ' + group.$1 + ': ' +
              group.$2.pending.toString() + ' ' + _t.pending +
              ', ' + group.$2.contacted.toString() + ' ' + _t.contacted);
        }
      }
    }
    return label.toString();
  }

  Widget _weekStrip(String locale, ColorScheme colors) {
    final monday = _weekBeginning(_selectedDay);
    final activity = _weekMonday == monday ? _weekActivity : null;
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth / 7).clamp(46.0, 88.0).toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(7, (index) {
            final day = DateTime(monday.year, monday.month, monday.day + index);
            final selected = day == _selectedDay;
            final dateKey = _dayKey(day);
            final info = activity?[dateKey];
            return SizedBox(
              width: itemWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: _weekDayDescription(day, locale, info),
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
                          // Reservar la misma zona para TODOS los días:
                          // los que tienen marcas no deben aumentar de alto.
                          const SizedBox(height: 5),
                          SizedBox(
                            key: ValueKey('agenda-week-slot-$index'),
                            height: 32,
                            child: info == null
                                ? const SizedBox.shrink()
                                : Center(child: _weekMarks(dateKey, info, colors)),
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
                  if (renewal.entry != null) ...[
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, size: 10,
                        color: renewal.entry == 'clients'
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.tertiary),
                      const SizedBox(width: 6),
                      Text(renewal.entry == 'clients'
                          ? _t.entryClients : _t.entryProspects,
                        style: Theme.of(context).textTheme.labelMedium),
                    ]),
                    const SizedBox(height: 6),
                  ],
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
            onPressed: _loading ? null : _refreshAll,
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
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        SizedBox(width: 170, child: DropdownButtonFormField<String>(
                          key: ValueKey('agenda-entry-' + _entryFilter),
                          initialValue: _entryFilter, isExpanded: true,
                          decoration: InputDecoration(labelText: _t.entryLabel,
                            border: const OutlineInputBorder()),
                          items: [
                            DropdownMenuItem(value:'', child: Text(_t.all)),
                            DropdownMenuItem(value:'clients', child: Text(_t.entryClients)),
                            DropdownMenuItem(value:'prospects', child: Text(_t.entryProspects)),
                          ],
                          onChanged: _setEntry,
                        )),
                        SizedBox(width: 180, child: DropdownButtonFormField<String>(
                          key: ValueKey('agenda-modality-' + _modalityFilter),
                          initialValue: _modalityFilter, isExpanded: true,
                          decoration: InputDecoration(labelText: _t.modalityLabel,
                            border: const OutlineInputBorder()),
                          items: [
                            DropdownMenuItem(value:'', child: Text(_t.all)),
                            for (final option in _modalities)
                              if (option.active || option.code == _modalityFilter)
                                DropdownMenuItem(value: option.code,
                                  child: Text(modalityCaption(context, option),
                                    overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: _setModality,
                        )),
                        SizedBox(width: 200,
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('agenda-insurer-' + _insurerFilter),
                            initialValue: _insurerFilter, isExpanded: true,
                            decoration: InputDecoration(
                              labelText: _t.insurerLabel,
                              border: const OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(value:'', child: Text(_t.all)),
                              for (final company in _insurers)
                                if (company.active || company.id == _insurerFilter)
                                  DropdownMenuItem(value:company.id,
                                    child: Text(company.name,
                                      overflow: TextOverflow.ellipsis)),
                              if (_insurerFilter.isNotEmpty &&
                                  !_insurers.any((company) =>
                                    company.id == _insurerFilter))
                                DropdownMenuItem(value: _insurerFilter,
                                  child: Text(_t.insurerLegacy)),
                            ],
                            onChanged: _setInsurer,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      _weekStrip(locale, colors),
                      if (_weekError) ...[
                        const SizedBox(height: 6),
                        Text(_t.agendaWeekUnavailable,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
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
