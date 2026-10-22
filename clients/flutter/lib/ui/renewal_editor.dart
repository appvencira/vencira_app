import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'modality_labels.dart';

/// Editor local: devuelve una solicitud validada, sin credenciales ni red.
class VenciraRenewalEditor extends StatefulWidget {
  const VenciraRenewalEditor({super.key, this.existing, this.modalities, this.insurers});

  final VenciraRenewal? existing;
  final List<VenciraModalityOption>? modalities;
  final List<VenciraInsurer>? insurers;

  @override
  State<VenciraRenewalEditor> createState() => _VenciraRenewalEditorState();
}

class _VenciraRenewalEditorState extends State<VenciraRenewalEditor> {
  final _formKey = GlobalKey<FormState>();
  AppLocalizations get _t => AppLocalizations.of(context)!;
  late final TextEditingController _reference;
  late final TextEditingController _fullName;
  late final TextEditingController _nickname;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _policyNumber;
  String? _entry;
  String _modality = '';
  String? _insurerId;
  DateTime? _expiration;
  DateTime? _notice;
  late String _status;

  @override
  void initState() {
    super.initState();
    _reference = TextEditingController(text: widget.existing?.reference ?? '');
    _fullName = TextEditingController(text: widget.existing?.fullName ?? '');
    _nickname = TextEditingController(text: widget.existing?.nickname ?? '');
    _phone = TextEditingController(text: widget.existing?.phone ?? '');
    _email = TextEditingController(text: widget.existing?.email ?? '');
    _policyNumber = TextEditingController(text: widget.existing?.policyNumber ?? '');
    _entry = widget.existing?.entry;
    _modality = widget.existing?.modality ?? '';
    _insurerId = widget.existing?.insurerId;
    _expiration = widget.existing?.expiresOn;
    _notice = widget.existing?.noticeDeadlineOn;
    _status = widget.existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _reference.dispose();
    _fullName.dispose();
    _nickname.dispose();
    _phone.dispose();
    _email.dispose();
    _policyNumber.dispose();
    super.dispose();
  }

  String _displayDate(DateTime? day) {
    if (day == null) return _t.notDefined;
    return DateFormat(
      'dd/MM/yyyy',
      Localizations.localeOf(context).languageCode,
    ).format(day);
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
        SnackBar(content: Text(
          _t.invalidNotice,
        )),
      );
      return;
    }
    if (widget.existing == null && _entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t.entryRequired)),
      );
      return;
    }
    Navigator.of(context).pop(VenciraRenewalInput(
      reference: _reference.text.trim(),
      fullName: _fullName.text.trim(),
      nickname: _nickname.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      policyNumber: _policyNumber.text.trim(),
      entry: _entry,
      modality: _modality,
      insurerId: _insurerId,
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
                TextFormField(
                  key: const ValueKey('full-name'),
                  controller: _fullName,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Nombre y apellidos o razón social', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('nickname'),
                  controller: _nickname,
                  maxLength: 80,
                  decoration: const InputDecoration(labelText: 'Apodo o nick', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('phone'),
                  controller: _phone,
                  maxLength: 32,
                  decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('email'),
                  controller: _email,
                  maxLength: 254,
                  decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('policy-number'),
                  controller: _policyNumber,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Número de póliza', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  key: const ValueKey('renewal-entry'),
                  initialValue: _entry,
                  decoration: InputDecoration(
                    labelText: _t.entryLabel,
                    border: const OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(value: 'clients', child: Text(_t.entryClients)),
                    DropdownMenuItem(value: 'prospects', child: Text(_t.entryProspects)),
                  ],
                  onChanged: (value) => setState(() => _entry = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('renewal-modality'),
                  initialValue: _modality,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: _t.modalityLabel,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    DropdownMenuItem(value: '', child: Text(_t.notDefined)),
                    for (final option in widget.modalities ??
                        VenciraModalityOption.defaults)
                      if (option.active || option.code == _modality)
                        DropdownMenuItem(
                          value: option.code,
                          child: Text(
                            modalityCaption(context, option) +
                              (option.active ? '' : ' · ' + _t.modalityInactive),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    if (_modality.isNotEmpty &&
                        !(widget.modalities ??
                          VenciraModalityOption.defaults)
                            .any((option) => option.code == _modality))
                      DropdownMenuItem(value: _modality,
                        child: Text(_modality, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (value) => setState(() {
                    if (value != null) _modality = value;
                  }),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, limits) {
                  final choices = widget.insurers ?? const <VenciraInsurer>[];
                  final existing = choices.any((s) => s.id == _insurerId);
                  return DropdownMenu<String>(
                    key: const ValueKey('renewal-insurer'),
                    width: limits.maxWidth,
                    enableFilter: true,
                    requestFocusOnTap: true,
                    label: Text(_t.insurerLabel),
                    initialSelection: _insurerId ?? '',
                    dropdownMenuEntries: [
                      DropdownMenuEntry(value: '', label: _t.notDefined),
                      for (final row in choices)
                        if (row.active || row.id == _insurerId)
                          DropdownMenuEntry(
                            value: row.id,
                            label: row.name +
                              (row.active ? '' : ' · ' + _t.modalityInactive),
                          ),
                      if (_insurerId != null && !existing)
                        DropdownMenuEntry(
                          value: _insurerId!,
                          label: _t.insurerLegacy,
                        ),
                    ],
                    onSelected: (value) => setState(
                      () => _insurerId = value == '' ? null : value,
                    ),
                  );
                }),
                const SizedBox(height: 12),
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
                  decoration: InputDecoration(
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
        FilledButton(onPressed: _submit, child: Text(_t.save)),
      ],
    );
  }
}
