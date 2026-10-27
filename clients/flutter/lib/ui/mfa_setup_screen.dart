import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../api/vencira_api.dart';

/// D1.5n: flujo MFA por pasos; deshabilitado en Ajustes salvo build opt-in.
/// Los secretos permanecen solamente en memoria de este widget.
class MfaSetupScreen extends StatefulWidget {
  const MfaSetupScreen({super.key, required this.api, required this.catalan});
  final VenciraApi api;
  final bool catalan;
  @override
  State<MfaSetupScreen> createState() => _MfaSetupScreenState();
}

class _MfaSetupScreenState extends State<MfaSetupScreen> {
  final _password = TextEditingController();
  final _totp = TextEditingController();
  final _proof = TextEditingController();
  String? _secret;
  String? _provisioningUri;
  List<String> _codes = [];
  bool _saved = false;
  bool _busy = false;
  bool _complete = false;
  String? _error;

  String tr(String es, String ca) => widget.catalan ? ca : es;

  @override
  void dispose() {
    _password.dispose();
    _totp.dispose();
    _proof.dispose();
    _codes.clear();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try { await action(); }
    catch (_) {
      if (mounted) setState(() => _error = tr(
        'No se ha podido completar el paso. Comprueba los datos o reinicia el alta.',
        'No s’ha pogut completar el pas. Comprova les dades o reinicia l’alta.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Verificación en dos pasos', 'Verificació en dos passos'))),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Icon(_complete ? Icons.verified_user_outlined : Icons.shield_outlined,
            size: 42, color: scheme.primary),
          const SizedBox(height: 12),
          Text(_complete ? tr('Protección activada', 'Protecció activada')
             : tr('Protege tu cuenta', 'Protegix el teu compte'),
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 12),
          ],
          if (_complete)
            Text(tr('Guarda tus códigos en un lugar seguro fuera de VENCIRA.',
                    'Guarda els codis en un lloc segur fora de VENCIRA.'))
          else if (_secret == null && _codes.isEmpty) ...[
            Text(tr('Confirma tu contraseña para configurar el autenticador.',
                    'Confirma la contrasenya per a configurar l’autenticador.')),
            const SizedBox(height: 16),
            TextField(controller: _password, obscureText: true,
              enableSuggestions: false, autocorrect: false,
              decoration: InputDecoration(labelText: tr('Contraseña actual', 'Contrasenya actual'))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : () => _run(() async {
              final data = await widget.api.startMfaSetup(_password.text);
              final secret = data['secret'];
              final uri = data['provisioning_uri'];
              if (secret is! String || uri is! String || !uri.startsWith('otpauth://')) {
                throw const VenciraApiException();
              }
              if (!mounted) return;
              _password.clear();
              setState(() { _secret = secret; _provisioningUri = uri; });
            }), child: Text(tr('Continuar', 'Continuar'))),
          ] else if (_codes.isEmpty) ...[
            Text(tr('Introduce esta clave en tu aplicación autenticadora. No la compartas.',
                    'Introduïx esta clau en l’aplicació autenticadora. No la compartisques.')),
            const SizedBox(height: 12),
            if (_provisioningUri != null) ...[
              Center(child: Semantics(
                label: tr('QR para añadir VENCIRA al autenticador',
                          'QR per afegir VENCIRA a l’autenticador'),
                child: QrImageView(
                  data: _provisioningUri!, version: QrVersions.auto,
                  size: 210, backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              )),
              const SizedBox(height: 14),
            ],
            SelectableText(_secret!, style: const TextStyle(fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text(tr('La aplicación permite añadir la cuenta manualmente.',
                    'L’aplicació permet afegir el compte manualment.')),
            const SizedBox(height: 16),
            TextField(controller: _totp, keyboardType: TextInputType.number,
              maxLength: 6, decoration: InputDecoration(
                labelText: tr('Código de seis dígitos', 'Codi de sis dígits'))),
            FilledButton(onPressed: _busy ? null : () => _run(() async {
              final codes = await widget.api.confirmMfaSetup(_totp.text.trim());
              if (!mounted) return;
              _totp.clear();
              setState(() { _codes = codes; _secret = null; _provisioningUri = null; });
            }), child: Text(tr('Verificar código', 'Verificar codi'))),
          ] else ...[
            Text(tr('Guarda estos diez códigos. Solo se muestran una vez. No hagas capturas en un dispositivo compartido.',
                    'Guarda estos deu codis. Només es mostren una vegada. No faces captures en un dispositiu compartit.')),
            const SizedBox(height: 12),
            for (final code in _codes)
              Padding(padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(code, style: const TextStyle(fontFamily: 'monospace'))),
            const SizedBox(height: 12),
            CheckboxListTile(value: _saved,
              title: Text(tr('He guardado los códigos en un lugar seguro',
                             'He guardat els codis en un lloc segur')),
              onChanged: _busy ? null : (v) => setState(() => _saved = v ?? false)),
            TextField(controller: _proof, autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(labelText: tr(
                'Introduce uno de los códigos guardados',
                'Introduïx un dels codis guardats'))),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy || !_saved ? null : () => _run(() async {
              await widget.api.acknowledgeMfaRecovery(_proof.text.trim().toUpperCase());
              if (!mounted) return;
              _proof.clear();
              setState(() { _codes.clear(); _complete = true; });
            }), child: Text(tr('Activar protección', 'Activar protecció'))),
          ],
        ]),
      ))),
    );
  }
}
