import 'package:flutter/material.dart';

import '../api/vencira_api.dart';

/// Editor local: devuelve una solicitud validada, sin credenciales ni red.
class VenciraRenewalEditor extends StatefulWidget {
  const VenciraRenewalEditor({super.key, this.existing});

  final VenciraRenewal? existing;

  @override
  State<VenciraRenewalEditor> createState() => _VenciraRenewalEditorState();
}

class _VenciraRenewalEditorState extends State<VenciraRenewalEditor> {
  final _formKey = GlobalKey<FormState>();
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
    if (day == null) return 'No definida';
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
      helpText: notice ? 'Límite de preaviso contractual' : 'Fecha de vencimiento',
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
        const SnackBar(content: Text('Indica una fecha de vencimiento.')),
      );
      return;
    }
    if (_notice != null && _notice!.isAfter(_expiration!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'El límite de preaviso no puede ser posterior al vencimiento.',
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
      title: Text(widget.existing == null ? 'Nuevo vencimiento' : 'Editar vencimiento'),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Solo referencias ficticias durante la fase de pruebas.'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reference,
                  maxLength: 160,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Referencia',
                    helperText: 'No introduzcas nombres reales de clientes',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'La referencia es obligatoria' : null,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: false),
                  icon: const Icon(Icons.event),
                  label: Text('Vencimiento: ${_displayDate(_expiration)}'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _chooseDate(notice: true),
                  icon: const Icon(Icons.event_note),
                  label: Text('Límite de preaviso: ${_displayDate(_notice)}'),
                ),
                if (_notice != null)
                  TextButton.icon(
                    onPressed: () => setState(() => _notice = null),
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar preaviso'),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _status,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Pendiente')),
                    DropdownMenuItem(value: 'contacted', child: Text('Contactado')),
                    DropdownMenuItem(value: 'closed', child: Text('Cerrado')),
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
          child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
