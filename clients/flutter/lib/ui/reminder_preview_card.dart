import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

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

  AppLocalizations get _strings => AppLocalizations.of(context)!;

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
      _result = null; // No conservar simulaciones de otra anotación.
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
      // Conservar la simulación visible durante el recálculo.
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
              _strings.previewText01,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            )),
          ]),
          const SizedBox(height: 8),
          Text(_strings.previewText02, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('reminder-preview-days'),
            controller: _days,
            enabled: !_loading,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: _strings.previewText03,
              hintText: '60,45,35',
              helperText: _strings.previewText04,
              errorText: _badInput ? _strings.previewText05 : null,
            ),
            onSubmitted: (_) => _calculate(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const ValueKey('reminder-preview-calculate'),
            onPressed: _loading ? null : _calculate,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(_strings.previewText06),
          ),
          SizedBox(height: 3, child: _loading && result != null
            ? const LinearProgressIndicator() : null),
          if (_loading && result == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error) ...[
            const SizedBox(height: 10),
            Text(_strings.previewText07),
            TextButton(
              onPressed: _loading ? null : _calculate,
              child: Text(_strings.previewText08),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 14),
            Text(_strings.previewText09 + _date(result.cutoffOn),
              style: Theme.of(context).textTheme.bodyMedium),
            if (result.lifeRuleRequiresReview)
              _warning(_strings.previewText10),
            if (result.noPreCutoffNotice)
              _warning(_strings.previewText11),
            if (result.lateControlNeedsDecision)
              _warning(_strings.previewText12),
            if (result.cutoffAlreadyElapsed)
              _warning(_strings.previewText13),
            const SizedBox(height: 8),
            for (final notice in result.reminders)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  notice.alreadyElapsed ? Icons.history : Icons.event_outlined),
                title: Text('${notice.daysBefore} ' +
                    _strings.previewText14 +
                    _date(notice.scheduledFor)),
                subtitle: notice.controlQuestion
                    ? Text(_strings.previewText15)
                    : notice.alreadyElapsed
                        ? Text(_strings.previewText16)
                        : null,
              ),
            Text(_strings.previewText17,
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
