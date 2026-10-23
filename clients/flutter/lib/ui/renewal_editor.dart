import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/vencira_api.dart';
import '../l10n/app_localizations.dart';
import 'modality_labels.dart';
import 'vencira_select.dart';

/// Editor local: devuelve una solicitud validada, sin credenciales ni red.
class VenciraRenewalEditor extends StatefulWidget {
  const VenciraRenewalEditor({super.key, this.existing, this.modalities, this.insurers, this.api, this.workspaceId});

  final VenciraRenewal? existing;
  final VenciraApi? api;
  final String? workspaceId;
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
  late final TextEditingController _notes;
  String? _entry;
  bool _suggesting = false;
  List<VenciraPersonSuggestion> _suggestions = [];
  int _suggestionGeneration = 0;
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
    _notes = TextEditingController(text: widget.existing?.notes ?? '');
    _entry = widget.existing?.entry;
    _modality = widget.existing?.modality ?? '';
    _insurerId = widget.existing?.insurerId;
    _expiration = widget.existing?.expiresOn;
    _notice = widget.existing?.noticeDeadlineOn;
    _status = widget.existing?.status ?? 'pending';
  }

  @override
  void dispose() {
    _suggestionGeneration++;
    _reference.dispose();
    _fullName.dispose();
    _nickname.dispose();
    _phone.dispose();
    _email.dispose();
    _policyNumber.dispose();
    _notes.dispose();
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

  Future<void> _lookupPerson() async {
    final api = widget.api;
    final workspace = widget.workspaceId;
    final name = _fullName.text.trim();
    final phone = _phone.text.trim();
    final by = name.length >= 3 ? 'name' : 'phone';
    final query = by == 'name' ? name : phone;
    if (api == null || workspace == null || query.length < 3) return;
    final generation = ++_suggestionGeneration;
    setState(() { _suggesting = true; _suggestions = []; });
    try {
      final results = await api.suggestPeople(
        workspace, query, by: by, excludeId: widget.existing?.id);
      if (!mounted || generation != _suggestionGeneration) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (!mounted || generation != _suggestionGeneration) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudieron consultar las sugerencias.')));
    } finally {
      if (mounted && generation == _suggestionGeneration) {
        setState(() => _suggesting = false);
      }
    }
  }

  void _copySuggestion(VenciraPersonSuggestion item) {
    setState(() {
      _fullName.text = item.fullName;
      _nickname.text = item.nickname;
      _phone.text = item.phone;
      _email.text = item.email;
      _suggestions = [];
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existing == null && _fullName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre o razón social es obligatorio.')),
      );
      return;
    }
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
      notes: _notes.text.trim(),
      entry: _entry,
      modality: _modality,
      insurerId: _insurerId,
      expiresOn: _expiration!,
      noticeDeadlineOn: _notice,
      status: _status,
    ));
  }

  String _designLabel(String es, String ca) =>
      Localizations.localeOf(context).languageCode == 'ca' ? ca : es;

  Widget _formSection(IconData icon, String title) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 9),
        Expanded(child: Text(title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 40, vertical: compact ? 14 : 28),
      title: Text(widget.existing == null ? _t.newRenewal : _t.editRenewal),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
      content: SizedBox(
        width: compact ? MediaQuery.sizeOf(context).width - 64 : 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_t.demoOnly,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
                _formSection(Icons.badge_outlined,
                  _designLabel('Identificación', 'Identificació')),
                TextFormField(
                  controller: _reference,
                  maxLength: 160,
                  autofocus: !compact,
                  decoration: InputDecoration(
                    labelText: _t.reference,
                    helperText: _t.referenceHelper,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? _t.referenceRequired : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('full-name'),
                  controller: _fullName,
                  textCapitalization: TextCapitalization.words,
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
                  keyboardType: TextInputType.phone,
                  maxLength: 32,
                  decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
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
                _formSection(Icons.policy_outlined,
                  _designLabel('Póliza y clasificación',
                    'Pòlissa i classificació')),
                if (widget.api != null && widget.workspaceId != null) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('lookup-person'),
                    onPressed: _suggesting ? null : _lookupPerson,
                    icon: const Icon(Icons.person_search),
                    label: const Text('Buscar datos en otras anotaciones'),
                  ),
                  if (_suggesting) const LinearProgressIndicator(),
                  for (final candidate in _suggestions)
                    ListTile(
                      title: Text(candidate.fullName),
                      subtitle: Text(candidate.nickname.isEmpty
                          ? 'Copiar datos de contacto'
                          : candidate.nickname),
                      trailing: const Icon(Icons.content_copy),
                      onTap: () => _copySuggestion(candidate),
                    ),
                  const SizedBox(height: 10),
                ],
                VenciraSelect<String>(
                  key: const ValueKey('renewal-entry'),
                  label: _t.entryLabel,
                  value: _entry ?? '',
                  prefixIcon: Icons.people_outline,
                  options: [
                    VenciraOption(value: '', label: _t.notDefined),
                    VenciraOption(value: 'clients', label: _t.entryClients),
                    VenciraOption(value: 'prospects', label: _t.entryProspects),
                  ],
                  onChanged: (value) => setState(
                    () => _entry = value.isEmpty ? null : value),
                ),
                const SizedBox(height: 12),
                VenciraSelect<String>(
                  key: const ValueKey('renewal-modality'),
                  label: _t.modalityLabel,
                  value: _modality,
                  prefixIcon: Icons.category_outlined,
                  options: [
                    VenciraOption(value: '', label: _t.notDefined),
                    for (final option in widget.modalities ??
                        VenciraModalityOption.defaults)
                      if (option.active || option.code == _modality)
                        VenciraOption(value: option.code,
                          label: modalityCaption(context, option) +
                              (option.active ? ''
                                  : ' · ${_t.modalityInactive}')),
                    if (_modality.isNotEmpty &&
                        !(widget.modalities ?? VenciraModalityOption.defaults)
                            .any((option) => option.code == _modality))
                      VenciraOption(value: _modality, label: _modality),
                  ],
                  onChanged: (value) => setState(() => _modality = value),
                ),
                const SizedBox(height: 12),
                VenciraSelect<String>(
                  key: const ValueKey('renewal-insurer'),
                  label: _t.insurerLabel,
                  value: _insurerId ?? '',
                  prefixIcon: Icons.apartment_outlined,
                  options: [
                    VenciraOption(value: '', label: _t.notDefined),
                    for (final insurer in widget.insurers ?? <VenciraInsurer>[])
                      if (insurer.active || insurer.id == _insurerId)
                        VenciraOption(value: insurer.id,
                          label: insurer.name +
                            (insurer.active ? ''
                                : ' · ${_t.modalityInactive}')),
                    if (_insurerId != null &&
                        !(widget.insurers ?? <VenciraInsurer>[])
                            .any((insurer) => insurer.id == _insurerId))
                      VenciraOption(value: _insurerId!, label: _t.insurerLegacy),
                  ],
                  onChanged: (value) => setState(
                    () => _insurerId = value.isEmpty ? null : value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('renewal-notes'),
                  controller: _notes,
                  maxLength: 4000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notas',
                    border: OutlineInputBorder(),
                  ),
                ),
                _formSection(Icons.event_outlined,
                  _designLabel('Fechas y seguimiento',
                    'Dates i seguiment')),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: false),
                  icon: const Icon(Icons.event),
                  label: Text('${_t.expiryLabel}: ${_displayDate(_expiration)}'),
                )),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: true),
                  icon: const Icon(Icons.event_note),
                  label: Text('${_t.noticeLabel}: ${_displayDate(_notice)}'),
                )),
                if (_notice != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(Icons.clear),
                    label: Text(_t.removeNotice),
                  ),
                const SizedBox(height: 12),
                VenciraSelect<String>(
                  key: const ValueKey('renewal-status'),
                  label: _t.status, value: _status,
                  prefixIcon: Icons.flag_outlined,
                  options: [
                    VenciraOption(value: 'pending',
                      label: _t.pending, icon: Icons.schedule),
                    VenciraOption(value: 'contacted',
                      label: _t.contacted, icon: Icons.forum_outlined),
                    // Sólo legados ya cerrados: nuevos cierres se realizan
                    // mediante Desenlace, nunca cambiando el estado.
                    if (widget.existing?.status == 'closed')
                      VenciraOption(value: 'closed',
                        label: _t.closed,
                        icon: Icons.check_circle_outline),
                  ],
                  onChanged: (value) => setState(() => _status = value),
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
