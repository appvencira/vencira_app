import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// O9b-3: manual declaration only; never asserts insurer has been notified.
class VenciraControlResponseCard extends StatefulWidget {
  const VenciraControlResponseCard({super.key, required this.api,
      required this.workspaceId, required this.renewalId});
  final VenciraApi api;
  final String workspaceId;
  final String renewalId;

  @override
  State<VenciraControlResponseCard> createState() => _ControlResponseCardState();
}

class _ControlResponseCardState extends State<VenciraControlResponseCard> {
  List<VenciraControlResponse>? _history;
  String? _answer;
  String? _option;
  final TextEditingController _daysController = TextEditingController(text: '1');

  @override
  void dispose() { _daysController.dispose(); super.dispose(); }
  bool _busy = false;
  bool _error = false;
  bool _conflict = false;
  AppLocalizations get t => AppLocalizations.of(context)!;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (_busy) return;
    setState(() { _busy = true; _error = false; _conflict = false; });
    try {
      final rows = await widget.api.fetchControlResponses(
          widget.workspaceId, widget.renewalId);
      if (mounted) setState(() => _history = rows);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _uuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0,8)}-${hex.substring(8,12)}-'
        '${hex.substring(12,16)}-${hex.substring(16,20)}-'
        '${hex.substring(20)}';
  }

  String _optionLabel(String? option) => switch (option) {
    'notified_by_client' => t.controlResponseClient,
    'insurer_not_renewing' => t.controlResponseInsurer,
    'notified_by_mediator' => t.controlResponseMediator,
    _ => '',
  };

  Future<void> _save() async {
    final answer = _answer;
    if (_busy || _history == null || answer == null ||
        (answer == 'yes' && _option == null)) return;
    final days = answer == 'no' ? int.tryParse(_daysController.text) : null;
    if (answer == 'no' && (days == null || days < 1)) {
      setState(() => _error = true);
      return;
    }
    setState(() { _busy = true; _error = false; _conflict = false; });
    try {
      final revision = _history!.isEmpty ? 0 : _history!.first.revision;
      await widget.api.saveControlResponse(widget.workspaceId, widget.renewalId,
        revision: revision, idempotencyKey: _uuid(), answer: answer,
        yesOption: answer == 'yes' ? _option : null,
        daysLater: answer == 'no' ? days : null);
      final rows = await widget.api.fetchControlResponses(
          widget.workspaceId, widget.renewalId);
      if (!mounted) return;
      setState(() { _history = rows; _answer = null; _option = null; });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.controlResponseSaved)));
    } on VenciraConflictException {
      if (mounted) setState(() => _conflict = true);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    return Card(child: Padding(padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.controlResponseTitle,
          style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(t.controlResponseManualWarning,
          style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_error) ...[
          Text(t.controlResponseError),
          TextButton(onPressed: _busy ? null : _load, child: Text(t.retry)),
        ],
        if (_conflict) ...[
          Text(t.controlResponseConflict),
          TextButton(onPressed: _busy ? null : _load, child: Text(t.refresh)),
        ],
        if (_history != null) ...[
          Text(t.controlResponseQuestion),
          RadioGroup<String>(
            groupValue: _answer,
            onChanged: _busy ? null : (value) =>
              setState(() { _answer = value; _option = null; }),
            child: Column(children: [
              RadioListTile<String>(
                title: Text(t.controlResponseYes), value: 'yes',
              ),
              RadioListTile<String>(
                title: Text(t.controlResponseNo), value: 'no',
              ),
            ]),
          ),
          if (_answer == 'yes') DropdownButtonFormField<String>(
            initialValue: _option, isExpanded: true,
            decoration: InputDecoration(labelText: t.controlResponseYesChoice),
            items: const [
              'notified_by_client', 'insurer_not_renewing',
              'notified_by_mediator',
            ].map((value) => DropdownMenuItem(
              value: value, child: Text(_optionLabel(value)))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _option = v),
          ),
          if (_answer == 'no') ...[
            const SizedBox(height: 10),
            Text(t.controlResponseDays),
            TextField(
              key: const ValueKey('control-repeat-days'),
              controller: _daysController,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: t.controlResponseDays),
            ),
            Text(t.controlResponseDaysHint,
              style: Theme.of(context).textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('save-control-response'),
            onPressed: _busy || _answer == null ||
                (_answer == 'yes' && _option == null) ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(t.controlResponseSave),
          ),
          const Divider(height: 28),
          Text(t.controlResponseHistory,
            style: Theme.of(context).textTheme.titleSmall),
          if (_history!.isEmpty) Text(t.controlResponseEmpty),
          for (final row in _history!) ListTile(
            dense: true,
            leading: const Icon(Icons.history),
            title: Text(row.answer == 'yes'
                ? '${t.controlResponseYes} · ${_optionLabel(row.yesOption)}'
                : t.controlResponseNo),
            subtitle: Text(
              DateFormat.yMd(locale).add_Hm().format(row.answeredAt.toLocal()) +
              (row.repeatOn == null ? '' :
                  ' · ${t.controlResponseRepeatOn} ' +
                  DateFormat.yMd(locale).format(row.repeatOn!))),
          ),
        ],
      ]),
    ));
  }
}
