import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';

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

  String _t(String es, String ca) =>
      Localizations.localeOf(context).languageCode == 'ca' ? ca : es;

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
      _value = null;
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

  String _date(DateTime day) =>
      DateFormat.yMd(Localizations.localeOf(context).languageCode).format(day);

  String _reason(String reason) {
    switch (reason) {
      case 'life_case_needs_review':
        return _t(
          'Vida: revisar el régimen aplicable antes de actuar.',
          'Vida: cal revisar el règim aplicable abans d’actuar.');
      case 'no_notice_before_cutoff':
        return _t(
          'No existe un aviso anterior a la fecha de referencia.',
          'No hi ha cap avís anterior a la data de referència.');
      case 'informational_cutoff_reached':
        return _t(
          'La fecha de referencia ya ha llegado o pasado.',
          'La data de referència ja ha arribat o ha passat.');
      case 'control_date_already_past_no_execution_evidence':
        return _t(
          'La fecha de control ha pasado; no hay evidencia de aviso enviado.',
          'La data de control ha passat; no hi ha evidència d’avís enviat.');
      default:
        return _t('Requiere revisión.', 'Cal revisar-ho.');
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
                _t('Pregunta de control: evaluación',
                    'Pregunta de control: avaluació'),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              )),
            ]),
            const SizedBox(height: 10),
            Text(_t(
              'Vista informativa. No pregunta, no registra respuestas '
              'ni envía notificaciones.',
              'Vista informativa. No fa preguntes, no registra respostes '
              'ni envia notificacions.',
            ), style: Theme.of(context).textTheme.bodySmall),
            if (_loading) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (!_loading && value != null) ...[
              const SizedBox(height: 14),
              Text(
                value.status == 'manual_review_required'
                  ? _t('Revisión manual pendiente', 'Revisió manual pendent')
                  : value.status == 'control_day_today_preview'
                    ? _t('Control previsto para hoy (no enviado)',
                         'Control previst per a hui (no enviat)')
                    : _t('Control futuro previsto (no programado)',
                         'Control futur previst (no programat)'),
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(_t('Referencia de un mes civil: ',
                      'Referència d’un mes civil: ') + _date(value.cutoffOn)),
              if (value.controlDay != null) ...[
                const SizedBox(height: 8),
                Text(_t('Control calculado: ', 'Control calculat: ') +
                     _date(value.controlDay!)),
              ],
              for (final reason in value.reasons) ...[
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.info_outline, size: 19),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_reason(reason))),
                ]),
              ],
              const SizedBox(height: 14),
              Text(_t(
                'Tras guardar otros días en el borrador, actualiza '
                'esta evaluación para recalcular.',
                'Després de desar altres dies en l’esborrany, '
                'actualitza aquesta avaluació per recalcular.',
              ), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (_error) ...[
              const SizedBox(height: 12),
              Text(_t('No se pudo consultar el control.',
                      'No s’ha pogut consultar el control.')),
            ],
            const SizedBox(height: 10),
            TextButton.icon(
              key: const ValueKey('control-assessment-refresh'),
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              label: Text(_t('Actualizar evaluación',
                             'Actualitzar avaluació')),
            ),
          ],
        ),
      ),
    );
  }
}
