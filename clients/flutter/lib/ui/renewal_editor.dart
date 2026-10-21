import 'package:flutter/material.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';

/// Editor local: devuelve una solicitud validada, sin credenciales ni red.
class VenciraRenewalEditor extends StatefulWidget {
  const VenciraRenewalEditor({super.key, this.existing});

  final VenciraRenewal? existing;

  @override
  State<VenciraRenewalEditor> createState() => _VenciraRenewalEditorState();
}

class _VenciraRenewalEditorState extends State<VenciraRenewalEditor> {
  final _formKey = GlobalKey<FormState>();
  AppLocalizations get _t => AppLocalizations.of(context)!;
  late final TextEditingController _reference;
  DateTime? _expiration;
  DateTime? _notice;
  late String _status;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.existing?.reference ?? '');
    _expiration = widget.existing?.expiresOn;
    _notice = widget.existing?.noticeDeadlineOn;
    _status = widget.existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _reference.dispose();
    super.dispose();
  }

  String _displayDate(DateTime? day) {
    if (day == null) return _t.notDefined;
    final d = day.day.toString().padLeft(2, '0');
    final m = day.month.toString().padLeft(2, '0');
    return '$d/$m/${day.year}';
  }

  Future<void> _chooseDate({required bool notice}) async {
    final initial = notice
        ? (_notice ?? _expiration ?? DateTime.now())
        : (_expiration ?? DateTime.now());
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: initial,
      helpText: notice ? _t.noticeDate : _t.expiryDate,
    );
    if (!mounted || date == null) return;
    setState(() {
      if (notice) {
        _notice = date;
      } else {
        _expiration = date;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_expiration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.missingExpiry)),
      );
      return;
    }
    if (_notice != null && _notice!.isAfter(_expiration!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          _t.invalidNotice,
        )),
      );
      return;
    }
    Navigator.of(context).pop(VenciraRenewalInput(
      reference: _reference.text.trim(),
      expiresOn: _expiration!,
      noticeDeadlineOn: _notice,
      status: _status,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? _t.newRenewal : _t.editRenewal),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t.demoOnly),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reference,
                  maxLength: 160,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _t.reference,
                    helperText: _t.referenceHelper,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? _t.referenceRequired : null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: false),
                  icon: const Icon(Icons.event),
                  label: Text('${_t.expiryLabel}: ${_displayDate(_expiration)}'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: true),
                  icon: const Icon(Icons.event_note),
                  label: Text('${_t.noticeLabel}: ${_displayDate(_notice)}'),
                ),
                if (_notice != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(Icons.clear),
                    label: Text(_t.removeNotice),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: _t.status,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: 'pending', child: Text(_t.pending)),
                    DropdownMenuItem(value: 'contacted', child: Text(_t.contacted)),
                    DropdownMenuItem(value: 'closed', child: Text(_t.closed)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _status = v);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(),
          child: Text(_t.cancel)),
        FilledButton(onPressed: _submit, child: const Text(_t.save)),
      ],
    );
  }
}
