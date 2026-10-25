import 'package:flutter/material.dart';
import '../api/vencira_api.dart';

/// O8c: ajustes por anotación, exclusivamente en estado borrador.
/// No crea tareas, envíos, recordatorios entregados ni políticas globales.
class VenciraReminderDraftCard extends StatefulWidget {
  const VenciraReminderDraftCard({
    super.key, required this.api, required this.workspaceId,
    required this.renewalId,
  });
  final VenciraApi api;
  final String workspaceId;
  final String renewalId;

  @override
  State<VenciraReminderDraftCard> createState() =>
      _ReminderDraftCardState();
}

class _ReminderDraftCardState extends State<VenciraReminderDraftCard> {
  final TextEditingController _days = TextEditingController();
  VenciraReminderDraft? _draft;
  int _sequence = 0;
  bool _loading = true;
  bool _saving = false;
  bool _error = false;
  bool _badInput = false;
  bool _conflict = false;

  String _tr(String es, String ca) =>
      Localizations.localeOf(context).languageCode == 'ca' ? ca : es;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant VenciraReminderDraftCard previous) {
    super.didUpdateWidget(previous);
    if (previous.workspaceId != widget.workspaceId ||
        previous.renewalId != widget.renewalId ||
        previous.api != widget.api) {
      _load();
    }
  }

  @override
  void dispose() {
    _sequence++;
    _days.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final version = ++_sequence;
    setState(() {
      _loading = true;
      _saving = false;
      _conflict = false;
      _error = false;
      _badInput = false;
      _draft = null;
    });
    try {
      final result = await widget.api.fetchReminderDraft(
          widget.workspaceId, widget.renewalId);
      if (!mounted || _sequence != version) return;
      setState(() {
        _draft = result;
        _days.text = result.daysBefore.join(',');
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _sequence != version) return;
      setState(() { _error = true; _loading = false; });
    }
  }

  List<int>? _parseDays() {
    final input = _days.text.trim();
    if (!RegExp(r'^(0|[1-9][0-9]{0,2})(,(0|[1-9][0-9]{0,2})){0,11}$')
        .hasMatch(input)) return null;
    final values = input.split(',').map(int.parse).toList();
    if (values.any((n) => n > 365) ||
        values.toSet().length != values.length) return null;
    return values;
  }

  Future<void> _save() async {
    if (_loading || _saving || _draft == null || _conflict) return;
    final values = _parseDays();
    if (values == null) {
      setState(() => _badInput = true);
      return;
    }
    setState(() { _saving = true; _error = false; _badInput = false; });
    final version = ++_sequence;
    try {
      final result = await widget.api.saveReminderDraft(
        widget.workspaceId, widget.renewalId,
        revision: _draft!.revision, daysBefore: values,
      );
      if (!mounted || version != _sequence) return;
      setState(() {
        _draft = result;
        _days.text = result.daysBefore.join(',');
        _saving = false;
      });
    } on VenciraConflictException {
      if (!mounted || version != _sequence) return;
      setState(() { _saving = false; _conflict = true; });
    } catch (_) {
      if (!mounted || version != _sequence) return;
      setState(() { _saving = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
          Row(children: [
            const Icon(Icons.edit_calendar_outlined),
            const SizedBox(width: 10),
            Expanded(child: Text(
              _tr('Guardar borrador de avisos',
                  'Desar esborrany d’avisos'),
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            )),
          ]),
          const SizedBox(height: 8),
          Text(_tr(
            'Guarda los días solo para esta anotación. No activa '
            'avisos ni envía notificaciones.',
            'Desa els dies només per a aquesta anotació. No activa '
            'avisos ni envia notificacions.',
          ), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && draft != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _tr(
                  draft.isPersisted
                      ? 'Borrador guardado'
                      : 'Valores sugeridos, aún no guardados',
                  draft.isPersisted
                      ? 'Esborrany desat'
                      : 'Valors suggerits, encara no desats',
                ),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextField(
              key: const ValueKey('draft-days'),
              controller: _days,
              enabled: !_saving && !_conflict,
              decoration: InputDecoration(
                labelText: _tr('Días antes', 'Dies abans'),
                hintText: '60,45,35',
                helperText: _tr(
                  '1 a 12 valores únicos, entre 0 y 365.',
                  'D’1 a 12 valors únics, entre 0 i 365.'),
                errorText: _badInput ? _tr(
                  'Introduce días válidos separados por comas.',
                  'Introdueix dies vàlids separats per comes.') : null,
              ),
            ),
            const SizedBox(height: 16),
            if (draft.noPreCutoffNotice)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_tr(
                  'Sin aviso anterior al límite informativo.',
                  'Sense avís anterior al límit informatiu.',
                )),
              ),
            if (draft.lifeRuleRequiresReview)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_tr(
                  'Vida: pendiente de revisión del régimen específico.',
                  'Vida: pendent de revisió del règim específic.',
                )),
              ),
            FilledButton.icon(
              key: const ValueKey('save-draft'),
              onPressed: _saving || _conflict ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_tr('Guardar solo borrador', 'Desar només esborrany')),
            ),
          ],
          if (_conflict) ...[
            Text(_tr(
              'Otra sesión ha modificado la configuración. Recarga '
              'antes de guardar; no se ha sobrescrito nada.',
              'Una altra sessió ha modificat la configuració. Recarrega '
              'abans de desar; no s’ha sobreescrit res.')),
            TextButton(
              key: const ValueKey('draft-reload'),
              onPressed: _load,
              child: Text(_tr('Recargar borrador', 'Recarregar esborrany')),
            ),
          ],
          if (_error) ...[
            Text(_tr(
              'No se ha podido consultar o guardar el borrador.',
              'No s’ha pogut consultar o desar l’esborrany.')),
            TextButton(
              key: const ValueKey('draft-retry'),
              onPressed: _load,
              child: Text(_tr('Reintentar', 'Torna-ho a provar')),
            ),
          ],
          if (_saving) const LinearProgressIndicator(),
        ]),
      ),
    );
  }
}
