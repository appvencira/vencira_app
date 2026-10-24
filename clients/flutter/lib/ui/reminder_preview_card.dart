import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';

/// Whitepaper §7–8: simulador de avisos por anotación. Solo lectura:
/// nunca agenda, envía ni da por respondido un aviso.
class VenciraReminderPreviewCard extends StatefulWidget {
  const VenciraReminderPreviewCard({
    super.key, required this.api, required this.workspaceId,
    required this.renewalId,
  });
  final VenciraApi api;
  final String workspaceId;
  final String renewalId;

  @override
  State<VenciraReminderPreviewCard> createState() =>
      _ReminderPreviewCardState();
}

class _ReminderPreviewCardState extends State<VenciraReminderPreviewCard> {
  final TextEditingController _days = TextEditingController(text: '60,45,35');
  VenciraReminderPreview? _result;
  int _version = 0;
  bool _loading = false;
  bool _error = false;
  bool _badInput = false;

  bool get _ca => Localizations.localeOf(context).languageCode == 'ca';
  String _language(String es, String ca) => _ca ? ca : es;

  @override
  void initState() {
    super.initState();
    _load(null);
  }

  @override
  void didUpdateWidget(covariant VenciraReminderPreviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspaceId != widget.workspaceId ||
        oldWidget.renewalId != widget.renewalId ||
        oldWidget.api != widget.api) {
      _days.text = '60,45,35';
      _load(null);
    }
  }

  @override
  void dispose() {
    _version++;
    _days.dispose();
    super.dispose();
  }

  List<int>? _parseDays() {
    final input = _days.text.trim();
    if (!RegExp(r'^(0|[1-9][0-9]{0,2})(,(0|[1-9][0-9]{0,2})){0,11}$')
        .hasMatch(input)) return null;
    final days = input.split(',').map(int.parse).toList();
    if (days.any((value) => value > 365) ||
        days.toSet().length != days.length) return null;
    return days;
  }

  Future<void> _calculate() async {
    if (_loading) return;
    final days = _parseDays();
    if (days == null) {
      setState(() => _badInput = true);
      return;
    }
    await _load(days);
  }

  Future<void> _load(List<int>? days) async {
    final request = ++_version;
    setState(() {
      _loading = true;
      _badInput = false;
      _error = false;
      _result = null;
    });
    try {
      final result = await widget.api.fetchReminderPreview(
        widget.workspaceId, widget.renewalId, daysBefore: days);
      if (!mounted || _version != request) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _version != request) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  String _date(DateTime day) =>
      DateFormat.yMd(Localizations.localeOf(context).languageCode).format(day);

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.notifications_active_outlined, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _language('Simulador de avisos', 'Simulador d’avisos'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            )),
          ]),
          const SizedBox(height: 8),
          Text(_language(
            'Prueba las anticipaciones en días naturales. Solo calcula fechas: '
            'no guarda configuraciones ni envía notificaciones.',
            'Prova les anticipacions en dies naturals. Només calcula dates: '
            'no desa configuracions ni envia notificacions.',
          ), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('reminder-preview-days'),
            controller: _days,
            enabled: !_loading,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: _language(
                'Días antes del vencimiento', 'Dies abans del venciment'),
              hintText: '60,45,35',
              helperText: _language(
                'De 1 a 12 avisos, entre 0 y 365 días; sin repetidos.',
                'D’1 a 12 avisos, entre 0 i 365 dies; sense repetits.'),
              errorText: _badInput ? _language(
                'Revisa los días: usa valores separados por comas.',
                'Revisa els dies: usa valors separats per comes.') : null,
            ),
            onSubmitted: (_) => _calculate(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('reminder-preview-calculate'),
            onPressed: _loading ? null : _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(_language('Calcular fechas', 'Calcular dates')),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error) ...[
            const SizedBox(height: 10),
            Text(_language(
              'No se ha podido consultar la vista previa.',
              'No s’ha pogut consultar la vista prèvia.')),
            TextButton(
              onPressed: _loading ? null : _calculate,
              child: Text(_language('Reintentar', 'Torna-ho a provar')),
            ),
          ],
          if (!_loading && result != null) ...[
            const SizedBox(height: 14),
            Text(_language(
              'Referencia de un mes civil: ',
              'Referència d’un mes civil: ') + _date(result.cutoffOn),
              style: Theme.of(context).textTheme.bodyMedium),
            if (result.lifeRuleRequiresReview)
              _warning(_language(
                'Póliza de Vida: revisa su régimen específico antes de actuar.',
                'Pòlissa de Vida: revisa el seu règim específic abans d’actuar.')),
            if (result.noPreCutoffNotice)
              _warning(_language(
                'No hay aviso anterior a la fecha de referencia. Se requiere decisión.',
                'No hi ha cap avís anterior a la data de referència. Cal decidir.')),
            if (result.lateControlNeedsDecision)
              _warning(_language(
                'La pregunta de control prevista ya habría pasado.',
                'La pregunta de control prevista ja hauria passat.')),
            if (result.cutoffAlreadyElapsed)
              _warning(_language(
                'La fecha de referencia ya ha llegado o pasado.',
                'La data de referència ja ha arribat o ha passat.')),
            const SizedBox(height: 8),
            for (final notice in result.reminders)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  notice.alreadyElapsed ? Icons.history : Icons.event_outlined),
                title: Text('${notice.daysBefore} ' +
                    _language('días antes · ', 'dies abans · ') +
                    _date(notice.scheduledFor)),
                subtitle: notice.controlQuestion
                    ? Text(_language(
                        'Pregunta de control prevista (no enviada)',
                        'Pregunta de control prevista (no enviada)'))
                    : notice.alreadyElapsed
                        ? Text(_language('Fecha pasada', 'Data passada'))
                        : null,
              ),
            Text(_language(
              'Simulación, no aviso enviado ni tarea guardada.',
              'Simulació, no avís enviat ni tasca desada.'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }

  Widget _warning(String message) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.info_outline, size: 19),
      const SizedBox(width: 8),
      Expanded(child: Text(message)),
    ]),
  );
}
