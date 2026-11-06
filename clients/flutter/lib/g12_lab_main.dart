// G12 phone-only offline DEBUG lab. Independent APK and Android key namespace.
// No login form, network client, real tokens, user or production integration.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'g12_lab/physical_auth_checks.dart';

const _g12Enabled = bool.fromEnvironment('VENCIRA_G12_LAB_BUILD');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_g12Enabled || kReleaseMode || !Platform.isAndroid) {
    throw StateError('G12_DEBUG_ANDROID_LAB_ONLY');
  }
  runApp(const _G12LabApp());
}

class _G12LabApp extends StatelessWidget {
  const _G12LabApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VENCIRA G12 Pruebas',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF176B81),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
    ),
    home: const _G12Home(),
  );
}

class _G12Home extends StatefulWidget {
  const _G12Home();

  @override
  State<_G12Home> createState() => _G12HomeState();
}

class _G12HomeState extends State<_G12Home> {
  bool _busy = false;
  bool _pending = false;
  bool _passed = false;
  String? _error;
  List<String> _markers = const [];

  @override
  void initState() {
    super.initState();
    _refreshPhase();
  }

  Future<void> _refreshPhase() async {
    try {
      final next = await G12PhoneAuthCheck.hasPendingRestart();
      if (!mounted) return;
      setState(() => _pending = next);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'G12_STORAGE_PHASE_READ_FAILED');
    }
  }

  Future<void> _perform(Future<List<String>> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _passed = false;
      _error = null;
      _markers = const [];
    });
    try {
      final result = await action();
      final next = await G12PhoneAuthCheck.hasPendingRestart();
      if (!mounted) return;
      setState(() {
        _markers = result;
        _pending = next;
        _passed = result.contains('G12_ANDROID_PHYSICAL_AUTH_RESULT=0');
      });
    } catch (error) {
      if (!mounted) return;
      // Only explicitly prefixed synthetic lab error codes may be displayed.
      // Never expose platform exception messages or protected store contents.
      final message = error is StateError ? error.message : null;
      setState(() {
        _error = message is String && message.startsWith('G12_')
            ? message
            : 'G12_LAB_STEP_FAILED';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>> _reset() async {
    await G12PhoneAuthCheck.cleanup();
    return const ['G12_ANDROID_MANUAL_LAB_CLEANUP=OK'];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('VENCIRA · G12 LAB')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              color: colors.primaryContainer,
              elevation: 0,
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Autenticación nativa · Android',
                        style: TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('APK de pruebas independiente, SIN servidor. '
                        'Contraseña, TOTP, tokens y revocación son valores '
                        'sintéticos fijos. El almacenamiento cifrado utiliza '
                        'el plugin real de Android.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('1 · Preparar escenario',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Ejecuta primera emisión, MFA, cierre normal, '
                        'revocación fallida y emisión incierta. Se guarda '
                        'un marcador cifrado para el segundo arranque.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || _pending
                          ? null
                          : () => _perform(G12PhoneAuthCheck.prepare),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Preparar prueba G12'),
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
                    const Text('2 · Reiniciar el proceso',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Desde Ajustes > Aplicaciones > '
                        'VENCIRA G12 Pruebas, pulsa Forzar detención. '
                        'Abre de nuevo esta APK y verifica la recuperación. '
                        'Cambiar de pantalla no es suficiente.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || !_pending
                          ? null
                          : () => _perform(
                                G12PhoneAuthCheck.verifyAfterRestart,
                              ),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Verificar tras reinicio'),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_passed)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(15),
                  child: Row(children: [
                    Icon(Icons.verified_outlined,
                        color: Color(0xFF127145)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text('G12 completado en Android físico.'),
                    ),
                  ]),
                ),
              ),
            if (_error != null)
              Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText('ERROR: ${_error!}'),
                ),
              ),
            if (_markers.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(
                    _markers.join('\n'),
                    style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12.5),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _perform(_reset),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Limpiar datos G12'),
            ),
            const SizedBox(height: 12),
            Text('Una prueba superada NO autoriza producción ni demuestra '
                'conexión real a Django. Se usa un único teléfono y no se '
                'verifica TEE/StrongBox.',
                style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
