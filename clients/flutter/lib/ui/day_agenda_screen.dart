import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'vencira_pagination_bar.dart';
import 'month_agenda_screen.dart';
import 'operational_inbox_screen.dart';
import 'renewal_detail_screen.dart';
import 'renewal_editor.dart';
import 'modality_labels.dart';
import 'vencira_select.dart';

/// Primera vista de la agenda tipo papel. Sólo presenta eventos previstos.
/// Seguimientos manuales y eventos previstos: no son notificaciones entregadas.
class VenciraDayAgendaScreen extends StatefulWidget {
  const VenciraDayAgendaScreen({
    super.key,
    required this.api,
    required this.workspace,
    this.initialDay,
    this.initialEntry = '',
    this.initialModality = '',
    this.initialInsurer = '',
    this.onSessionExpired,
  });

  final VenciraApi api;
  final VenciraWorkspace workspace;
  final DateTime? initialDay;
  final String initialEntry;
  final String initialModality;
  final String initialInsurer;
  final Future<void> Function()? onSessionExpired;

  @override
  State<VenciraDayAgendaScreen> createState() => _VenciraDayAgendaScreenState();
}

class _VenciraDayAgendaScreenState extends State<VenciraDayAgendaScreen> {
  late DateTime _selectedDay;
  VenciraAgendaDayPage? _agenda;
  VenciraOperationalInbox? _todayInbox;
  bool _todayInboxLoading = false;
  bool _todayInboxFailed = false;
  int _todayInboxGeneration = 0;
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

  Future<void> _expire() async {
    if (!mounted || _unauthorized) return;
    setState(() {
      _generation++;
      _todayInboxGeneration++;
      _weekGeneration++;
      _agenda = null;
      _todayInbox = null;
      _weekActivity = null;
      _unauthorized = true;
      _loading = false;
    });
    try {
      await widget.onSessionExpired?.call();
    } catch (_) {
      // Preserve the revoked, data-free route while native cleanup is unacknowledged.
      return;
    }
    if (mounted && widget.onSessionExpired != null) Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
    _loadTodayInbox();
  }

  @override
  void dispose() {
    _generation++;
    _weekGeneration++;
    _todayInboxGeneration++;
    super.dispose();
  }

  Future<void> _loadModalities() async {
    if (_unauthorized) return;
    try {
      final options = await widget.api.fetchModalities(widget.workspace.id);
      if (mounted) setState(() => _modalities = options);
    } catch (_) {
      // Los 12 códigos por defecto siguen disponibles.
    }
  }

  Future<void> _loadInsurers() async {
    if (_unauthorized) return;
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
    if (_unauthorized) return;
    final sequence = ++_generation;
    final requestedDay = _selectedDay;
    setState(() {
      // Solo descartar tarjetas si se ha cambiado realmente de día.
      // Refrescar/filtrar un mismo día no debe contraer la página.
      final shownDay = _agenda?.day;
      if (shownDay != null &&
          (shownDay.year != requestedDay.year ||
           shownDay.month != requestedDay.month ||
           shownDay.day != requestedDay.day)) {
        _agenda = null;
      }
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
      await _expire();
    } catch (_) {
      if (!mounted || sequence != _generation) return;
      setState(() {
        _agenda = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
  }

  Future<void> _loadTodayInbox() async {
    if (_unauthorized) return;
    final requestId = ++_todayInboxGeneration;
    if (!_isToday) {
      if (mounted) setState(() {
        _todayInbox = null;
        _todayInboxLoading = false;
        _todayInboxFailed = false;
      });
      return;
    }
    setState(() {
      _todayInboxLoading = true;
      _todayInboxFailed = false;
      // Never show a stale count while refreshing.
      _todayInbox = null;
    });
    try {
      final inbox = await widget.api.fetchOperationalInbox(
        widget.workspace.id, _selectedDay, scope: 'due',
      );
      if (!mounted || requestId != _todayInboxGeneration || !_isToday) return;
      setState(() {
        _todayInbox = inbox;
        _todayInboxLoading = false;
      });
    } on VenciraUnauthorized {
      if (!mounted || requestId != _todayInboxGeneration) return;
      await _expire();
    } catch (_) {
      if (!mounted || requestId != _todayInboxGeneration) return;
      setState(() {
        _todayInbox = null;
        _todayInboxLoading = false;
        _todayInboxFailed = true;
      });
    }
  }

  Future<void> _openTodayInbox() async {
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => VenciraOperationalInboxScreen(
        api: widget.api, workspace: widget.workspace,
        onSessionExpired: _expire),
    ));
    if (mounted) {
      _loadDay(_page);
      _loadTodayInbox();
    }
  }

  Widget _todayInboxShortcut() {
    if (!_isToday || _unauthorized) return const SizedBox.shrink();
    final count = _todayInbox == null
        ? null : _todayInbox!.today + _todayInbox!.overdue;
    return Card.outlined(
      key: const ValueKey('agenda-today-inbox-shortcut'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          const Icon(Icons.notifications_active_outlined),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_t.agendaInternalInbox,
                style: Theme.of(context).textTheme.titleSmall),
              Text(_todayInboxFailed
                  ? _t.agendaInternalInboxUnavailable
                  : _t.agendaInternalInboxDescription,
                style: Theme.of(context).textTheme.bodySmall),
            ],
          )),
          if (_todayInboxLoading)
            const SizedBox(width: 22, height: 22,
              child: CircularProgressIndicator(strokeWidth: 2))
          else if (count != null) ...[
            Text('$count', key: const ValueKey('agenda-due-count'),
              style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
          ],
          IconButton(
            key: const ValueKey('agenda-inbox-open'),
            tooltip: _todayInboxFailed ? _t.retry : _t.inboxShortcut,
            onPressed: _todayInboxLoading ? null :
                _todayInboxFailed ? _loadTodayInbox : _openTodayInbox,
            icon: Icon(_todayInboxFailed ? Icons.refresh :
                Icons.arrow_forward_ios_rounded, size: 18),
          ),
        ]),
      ),
    );
  }

  static DateTime _weekBeginning(DateTime day) => DateTime(
    day.year, day.month, day.day - (day.weekday - DateTime.monday),
  );

  static String _dayKey(DateTime day) => DateFormat('yyyy-MM-dd').format(day);

  /// La semana puede abarcar dos meses: una o dos consultas agregadas,
  /// nunca siete listados de pólizas ni datos ajenos a la sesión.
  Future<void> _loadWeek({bool force = false}) async {
    if (_unauthorized) return;
    final monday = _weekBeginning(_selectedDay);
    if (!force && _weekMonday == monday) return;
    final requestId = ++_weekGeneration;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    setState(() {
      // Descartar solo al navegar a otra semana.
      if (_weekMonday != monday) _weekActivity = null;
      _weekMonday = monday;
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
    _loadTodayInbox();
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
    _loadTodayInbox();
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
        onSessionExpired: _expire,
      ),
    ));
    if (mounted) {
      _loadDay(1);
      _loadWeek(force: true);
    }
  }

  /// Editar sin navegar a la ficha: Cancelar y Guardar regresan a Agenda.
  Future<void> _editAgendaRenewal(String renewalId) async {
    try {
      final detail = await widget.api.fetchRenewalDetail(
        widget.workspace.id, renewalId,
      );
      if (detail.archiveOutcome.isNotEmpty) return;
      final modalities = await widget.api.fetchModalities(widget.workspace.id);
      final insurers = await widget.api.fetchInsurers(widget.workspace.id);
      if (!mounted) return;
      final input = await showDialog<VenciraRenewalInput>(
        context: context,
        builder: (_) => VenciraRenewalEditor(
          existing: detail,
          modalities: modalities,
          insurers: insurers,
          api: widget.api,
          workspaceId: widget.workspace.id,
        ),
      );
      if (!mounted || input == null) return;
      await widget.api.updateRenewal(widget.workspace.id, renewalId, input);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saved)),
      );
      _refreshAll();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.saveError)),
      );
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
        if (info.followUp.total > 0)
          pair('follow_up', info.followUp, const Color(0xFF956DC0)),
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
        (_t.manualFollowUpShort, info.followUp),
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

  /// Tira de fechas compacta: círculos, no columnas rectangulares.
  /// Las marcas mantienen significado (tipo de evento + estado) y claves
  /// accesibles para las pruebas actuales.
  Widget _weekStrip(String locale, ColorScheme colors) {
    final monday = _weekBeginning(_selectedDay);
    final activity = _weekMonday == monday ? _weekActivity : null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth / 7).clamp(46.0, 88.0).toDouble();
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: List.generate(7, (index) {
          final day = DateTime(monday.year, monday.month, monday.day + index);
          final selected = day == _selectedDay;
          final dateKey = _dayKey(day);
          final info = activity?[dateKey];
          Color? eventColor;
          if (info != null) {
            if (info.expiry.total > 0) {
              eventColor = colors.error;
            } else if (info.notice.total > 0) {
              eventColor = colors.tertiary;
            } else if (info.reminder.total > 0) {
              eventColor = colors.primary;
            }
          }
          final background = selected
              ? colors.primary
              : eventColor == null
                  ? Colors.transparent
                  : Color.lerp(colors.surface, eventColor,
                      dark ? 0.32 : 0.18)!;
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
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _chooseDay(day),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(DateFormat.E(locale).format(day),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant)),
                        const SizedBox(height: 7),
                        Container(
                          width: 42, height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: background,
                            border: selected ? null : Border.all(
                              color: eventColor == null
                                  ? colors.outlineVariant
                                  : Colors.transparent,
                            ),
                          ),
                          child: Text('${day.day}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? colors.onPrimary : colors.onSurface,
                            )),
                        ),
                        const SizedBox(height: 7),
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
        })),
      );
    });
  }

  Widget _activityChip(String label, IconData icon, Color tint) {
    final colors = Theme.of(context).colorScheme;
    return Chip(
      side: BorderSide.none,
      backgroundColor: Color.lerp(colors.surface, tint, 0.17),
      avatar: Icon(icon, color: tint, size: 17),
      label: Text(label, style: Theme.of(context).textTheme.labelSmall
          ?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w600)),
    );
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
                  VenciraStatusBadge(
                    status: renewal.status,
                    label: switch (renewal.status) {
                      'pending' => _t.pending,
                      'contacted' => _t.contacted,
                      'closed' => _t.closed,
                      _ => _t.unknown,
                    },
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: entry.events.map((event) {
                      if (event.kind == 'expiry') {
                        return _activityChip(_t.agendaExpiryEvent,
                          Icons.event_available_outlined,
                          Theme.of(context).colorScheme.error);
                      }
                      if (event.kind == 'notice_deadline') {
                        return _activityChip(_t.agendaContractualNotice,
                          Icons.event_busy_outlined,
                          Theme.of(context).colorScheme.tertiary);
                      }
                      if (event.kind == 'follow_up') {
                        return _activityChip(
                          _t.manualFollowUpShort,
                          Icons.bookmark_added_outlined,
                          const Color(0xFF956DC0),
                        );
                      }
                      if (event.kind == 'operational_reminder') {
                        return _activityChip(
                          '${_t.agendaInternalReminder}: ${event.operationalReason}',
                          Icons.notifications_active_outlined,
                          Theme.of(context).colorScheme.primary,
                        );
                      }
                      return _activityChip(
                        event.basis == 'notice_deadline'
                            ? _t.agendaPlannedNotice
                            : _t.agendaPlannedReminder,
                        Icons.notifications_none,
                        Theme.of(context).colorScheme.primary,
                      );
                    }).toList(growable: false),
                  ),
                ],
              ),
            ),
            if (renewal.archiveOutcome.isEmpty)
              IconButton(
                key: ValueKey('agenda-edit-' + renewal.id),
                tooltip: _t.editRenewal,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editAgendaRenewal(renewal.id),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _dayContents(String locale) {
    if (_loading && _agenda == null) {
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
        SizedBox(height: 3, child: _loading
          ? const LinearProgressIndicator() : null),
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
        VenciraPaginationBar(
          pageLabel: '${_t.page} $_page',
          previousLabel: _t.previous,
          nextLabel: _t.next,
          onPrevious: _page > 1 && !_loading
              ? () => _loadDay(_page - 1) : null,
          onNext: agenda.hasNext && !_loading
              ? () => _loadDay(_page + 1) : null,
        ),
      ],
    );
  }

  Widget _agendaFilters() {
    return LayoutBuilder(builder: (context, constraints) {
      final fieldWidth = constraints.maxWidth < 620
          ? constraints.maxWidth : 220.0;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        SizedBox(width: fieldWidth, child: VenciraSelect<String>(
          key: ValueKey('agenda-entry-$_entryFilter'),
          label: _t.entryLabel, value: _entryFilter,
          prefixIcon: Icons.people_outline,
          options: [
            VenciraOption(value: '', label: _t.all),
            VenciraOption(value: 'clients', label: _t.entryClients),
            VenciraOption(value: 'prospects', label: _t.entryProspects),
          ],
          onChanged: _setEntry,
        )),
        SizedBox(width: fieldWidth, child: VenciraSelect<String>(
          key: ValueKey('agenda-modality-$_modalityFilter'),
          label: _t.modalityLabel, value: _modalityFilter,
          prefixIcon: Icons.category_outlined,
          options: [
            VenciraOption(value: '', label: _t.all),
            for (final option in _modalities)
              if (option.active || option.code == _modalityFilter)
                VenciraOption(value: option.code,
                  label: modalityCaption(context, option)),
          ],
          onChanged: _setModality,
        )),
        SizedBox(width: fieldWidth, child: VenciraSelect<String>(
          key: ValueKey('agenda-insurer-$_insurerFilter'),
          label: _t.insurerLabel, value: _insurerFilter,
          prefixIcon: Icons.apartment_outlined,
          options: [
            VenciraOption(value: '', label: _t.all),
            for (final company in _insurers)
              if (company.active || company.id == _insurerFilter)
                VenciraOption(value: company.id, label: company.name),
            if (_insurerFilter.isNotEmpty &&
                !_insurers.any((company) => company.id == _insurerFilter))
              VenciraOption(value: _insurerFilter,
                label: _t.insurerLegacy),
          ],
          onChanged: _setInsurer,
        )),
      ]);
    });
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
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          )),
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
                      if (MediaQuery.sizeOf(context).width < 600)
                        ExpansionTile(
                          key: const ValueKey('agenda-filters'),
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(Icons.tune_outlined),
                          title: Text(_t.agendaFiltersShort),
                          childrenPadding: const EdgeInsets.only(bottom: 12),
                          children: [_agendaFilters()],
                        )
                      else
                        _agendaFilters(),
                      const SizedBox(height: 16),
                      _weekStrip(locale, colors),
                      if (_weekError) ...[
                        const SizedBox(height: 6),
                        Text(_t.agendaWeekUnavailable,
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                      const SizedBox(height: 14),
                      _todayInboxShortcut(),
                      const SizedBox(height: 10),
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
