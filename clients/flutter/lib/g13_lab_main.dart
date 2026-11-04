// G13 Android -> Termius SSH local-forward or ADB reverse -> private Django TLS lab.
// Strict DEBUG-only, ephemeral CA embedded at build time, synthetic credentials.
// Never imported by operational main.dart; cannot contact public DNS.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'g13_lab/physical_https_checks.dart';

const bool _enabled = bool.fromEnvironment('VENCIRA_G13_LAB_BUILD');
const String _ca = String.fromEnvironment('G13_LAB_PUBLIC_CA_BASE64');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_enabled || _ca.isEmpty || kReleaseMode || !Platform.isAndroid) {
    throw StateError('G13_DEBUG_ANDROID_TEMPORARY_CA_ONLY');
  }
  runApp(const _G13App());
}

class _G13App extends StatelessWidget {
  const _G13App();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VENCIRA G13 Pruebas TLS',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF186D81),
      ),
    ),
    home: const _Home(),
  );
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  bool _busy = false;
  bool _pending = false;
  bool _complete = false;
  String? _error;
  List<String> _output = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pending = await G13PhoneHttpsCheck.hasPendingRestart();
      if (mounted) setState(() => _pending = pending);
    } catch (_) {
      if (mounted) setState(() => _error = 'G13_PHASE_NOT_READABLE');
    }
  }

  Future<void> _run(Future<List<String>> Function() work) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _complete = false;
      _error = null;
      _output = const [];
    });
    try {
      final messages = await work();
      final pending = await G13PhoneHttpsCheck.hasPendingRestart();
      if (!mounted) return;
      setState(() {
        _output = messages;
        _pending = pending;
        _complete = messages.contains('G13_ANDROID_REAL_HTTPS_RESULT=0');
      });
    } catch (e) {
      if (!mounted) return;
      // Only explicit lab error codes are displayed. No URI, secrets, token,
      // plaintext, stack trace, or platform exception body is ever shown.
      final reason = e is StateError ? e.message : null;
      final category = e is SocketException
          ? 'G13_LOCAL_FORWARD_UNREACHABLE'
          : e is TlsException
              ? 'G13_TLS_CERTIFICATE_OR_HANDSHAKE_FAILED'
              : 'G13_LAB_ACTION_FAILED';
      setState(() {
        _error = reason is String && reason.startsWith('G13_')
            ? reason
            : category;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>> _reset() async {
    await G13PhoneHttpsCheck.cleanup();
    return const ['G13_LAB_MANUAL_RESET=OK'];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('VENCIRA · G13 TLS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              elevation: 0,
              color: colors.primaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Android físico + Django HTTPS temporal',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    SizedBox(height: 10),
                    Text('Conexión local mediante Termius SSH o ADB reverse. Servidor '
                        'Docker aislado en el PC. Certificado temporal '
                        'verificado. Solo cuentas y claves sintéticas '
                        'del laboratorio; sin tráfico a producción.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('1 · Emitir, validar HTTPS y preparar recuperación',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Prueba certificado TLS, rechazo de CA '
                        'desconocida, primera emisión, MFA, revocación '
                        'real en Django y una respuesta de emisión '
                        'perdida.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy || _pending ? null :
                          () => _run(G13PhoneHttpsCheck.prepare),
                      child: const Text('Iniciar G13: fase 1'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('2 · Forzar detención y reabrir',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    const Text('Mantén activo el túnel Termius/SSH (o USB) y la terminal '
                        'del laboratorio. En Ajustes > Aplicaciones > '
                        'VENCIRA G13 TLS > Forzar detención, luego '
                        'reabre esta APK y pulsa verificar.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _busy || !_pending ? null :
                          () => _run(G13PhoneHttpsCheck.verifyAfterRestart),
                      child: const Text('Verificar fase 2'),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_complete)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.verified, color: Color(0xFF08784B)),
                    SizedBox(width: 10),
                    Expanded(
                        child: Text('G13: secuencia HTTPS física completada')),
                  ]),
                ),
              ),
            if (_error != null)
              Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(_error!),
                ),
              ),
            if (_output.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    _output.join('\n'),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12.5),
                  ),
                ),
              ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: _busy ? null : () => _run(_reset),
              child: const Text('Limpiar claves de laboratorio G13'),
            ),
            const SizedBox(height: 14),
            Text(
              'No usar cuentas reales. No valida MFA productivo ni autoriza '
              'migraciones, despliegue o publicación de la API nativa.',
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
