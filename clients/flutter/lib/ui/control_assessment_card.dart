import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// O9a: lectura de la situación de control. No registra respuestas ni envíos.
class VenciraControlAssessmentCard extends StatefulWidget {
  const VenciraControlAssessmentCard({
    super.key,
    required this.api,
    required this.workspaceId,
    required this.renewalId,
  });
  final VenciraApi api;
  final String workspaceId;
  final String renewalId;

  @override
  State<VenciraControlAssessmentCard> createState() =>
      _ControlAssessmentCardState();
}

class _ControlAssessmentCardState extends State<VenciraControlAssessmentCard> {
  VenciraControlAssessment? _value;
  int _generation = 0;
  bool _loading = true;
  bool _error = false;
  bool _creating = false;
  bool _createError = false;
  bool _createConflict = false;

  AppLocalizations get _strings => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VenciraControlAssessmentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.renewalId != widget.renewalId ||
        oldWidget.workspaceId != widget.workspaceId) {
      _value = null; // Cambio de identidad: no mostrar control de otra ficha.
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final current = ++_generation;
    setState(() {
      _loading = true;
      _error = false;
      // La última evaluación sigue visible durante una recarga ordinaria.
    });
    try {
      final data = await widget.api.fetchControlAssessment(
        widget.workspaceId, widget.renewalId,
      );
      if (!mounted || current != _generation) return;
      setState(() { _value = data; _loading = false; });
    } catch (_) {
      if (!mounted || current != _generation) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-'
        '${hex.substring(12,16)}-${hex.substring(16,20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _createExplicitControl() async {
    final policy = _value?.c2Policy;
    if (_creating || policy?.offerExplicitControl != true ||
        policy?.latestExplicitControlDay == null) return;
    final last = policy!.latestExplicitControlDay!;
    final today = DateUtils.dateOnly(DateTime.now());
    if (last.isBefore(today)) return;
    final picked = await showDatePicker(
      context: context, initialDate: today,
      firstDate: today, lastDate: last,
    );
    if (!mounted || picked == null) return;
    final ca = Localizations.localeOf(context).languageCode == 'ca';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(ca ? 'Crear avís de control' : 'Crear aviso de control'),
        content: Text(ca
            ? 'Es crearà un avís intern per al dia ${_date(picked)}. '
              'No implica cap enviament ni notificació a l’asseguradora.'
            : 'Se creará un aviso interno para el día ${_date(picked)}. '
              'No implica envío ni notificación a la aseguradora.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(ca ? 'Cancel·lar' : 'Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(ca ? 'Confirmar' : 'Confirmar')),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final current = _generation;
    setState(() { _creating = true; _createError = false; _createConflict = false; });
    try {
      await widget.api.createExplicitControl(
        widget.workspaceId, widget.renewalId,
        day: picked, idempotencyKey: _uuid(),
      );
      if (!mounted || current != _generation) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
        ca ? 'Avís intern creat. No s’ha enviat cap notificació.'
           : 'Aviso interno creado. No se ha enviado ninguna notificación.',
      )));
      await _load();
    } on VenciraConflictException {
      if (mounted && current == _generation) setState(() => _createConflict = true);
    } catch (_) {
      if (mounted && current == _generation) setState(() => _createError = true);
    } finally {
      if (mounted && current == _generation) setState(() => _creating = false);
    }
  }

  String _date(DateTime day) =>
      DateFormat.yMd(Localizations.localeOf(context).languageCode).format(day);

  String _reason(String reason) {
    switch (reason) {
      case 'life_case_needs_review':
        return _strings.controlLifeReview;
      case 'no_notice_before_cutoff':
        return _strings.controlNoEligible;
      case 'informational_cutoff_reached':
        return _strings.controlCutoffPassed;
      case 'control_date_already_past_no_execution_evidence':
        return _strings.controlPastNotSent;
      default:
        return _strings.controlRequiresReview;
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = _value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.fact_check_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(
                _strings.controlTitle,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              )),
            ]),
            const SizedBox(height: 10),
            Text(_strings.controlReadOnlyInfo, style: Theme.of(context).textTheme.bodySmall),
            SizedBox(height: 3, child: _loading && value != null
              ? const LinearProgressIndicator() : null),
            if (_loading && value == null) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (value != null) ...[
              const SizedBox(height: 14),
              Text(
                value.status == 'manual_review_required'
                  ? _strings.controlManualPending
                  : value.status == 'control_day_today_preview'
                    ? _strings.controlTodayPreview
                    : _strings.controlFuturePreview,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (value.c2Policy?.manualReviewRequired == true) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.assignment_late_outlined,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        _strings.controlManualPending,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Vida requires policy-specific human review: the general
              // one-month cutoff cannot be presented as legally confirmed.
              if (!value.reasons.contains('life_case_needs_review'))
                Text(_strings.controlCutoffLabel + _date(value.cutoffOn)),
              if (value.controlDay != null) ...[
                const SizedBox(height: 8),
                Text(_strings.controlDayLabel +
                     _date(value.controlDay!)),
              ],
              for (final reason in value.reasons) ...[
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(
                    reason == 'no_notice_before_cutoff' ||
                            reason == 'informational_cutoff_reached' ||
                            reason == 'control_date_already_past_no_execution_evidence'
                        ? Icons.warning_amber_rounded : Icons.info_outline,
                    size: 19,
                    color: reason == 'life_case_needs_review'
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_reason(reason))),
                ]),
              ],
              if (value.c2Policy?.offerExplicitControl == true) ...[
                const SizedBox(height: 14),
                FilledButton.icon(
                  key: const ValueKey('explicit-control-create'),
                  onPressed: _loading || _creating ? null : _createExplicitControl,
                  icon: const Icon(Icons.add_alert_outlined),
                  label: Text(Localizations.localeOf(context).languageCode == 'ca'
                      ? 'Crear avís de control' : 'Crear aviso de control'),
                ),
                if (_creating) const LinearProgressIndicator(),
                if (_createError || _createConflict)
                  Text(_createConflict
                    ? _strings.controlLoadError : _strings.controlLoadError),
              ],
              const SizedBox(height: 14),
              Text(_strings.controlRefreshHelp, style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error) ...[
              const SizedBox(height: 12),
              Text(_strings.controlLoadError),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              key: const ValueKey('control-assessment-refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(_strings.controlRefresh),
            ),
          ],
        ),
      ),
    );
  }
}
