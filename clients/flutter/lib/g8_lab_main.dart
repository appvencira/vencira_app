// G8-PHONE dedicated offline, DEBUG-ONLY Android APK entry point.
// Build solely with scripts/g8_phone_apk_build.sh (separate .g8lab app ID).
// NOT imported by main.dart; no backend, no login, no tokens from users.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'g8_lab/physical_store_checks.dart';

const bool _g8Enabled = bool.fromEnvironment('VENCIRA_G8_LAB_BUILD');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_g8Enabled || kReleaseMode || !Platform.isAndroid) {
    throw StateError('G8_DEBUG_ANDROID_LAB_ONLY');
  }
  runApp(const _G8LabApp());
}

class _G8LabApp extends StatelessWidget {
  const _G8LabApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'VENCIRA G8 Pruebas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF236E87),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F7F9),
        ),
        home: const _G8LabHome(),
      );
}

class _G8LabHome extends StatefulWidget {
  const _G8LabHome();

  @override
  State<_G8LabHome> createState() => _G8LabHomeState();
}

class _G8LabHomeState extends State<_G8LabHome> {
  bool _busy = false;
  bool _prepared = false;
  bool _resultOk = false;
  String? _failure;
  List<String> _markers = const [];

  @override
  void initState() {
    super.initState();
    _loadPhase();
  }

  Future<void> _loadPhase() async {
    try {
      final pending = await G8PhoneStorageCheck.hasPendingRestart();
      if (!mounted) return;
      setState(() => _prepared = pending);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failure = 'No se pudo leer el estado de prueba');
    }
  }

  Future<void> _run(Future<List<String>> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
      _resultOk = false;
      _markers = const [];
    });
    try {
      final result = await action();
      final pending = await G8PhoneStorageCheck.hasPendingRestart();
      if (!mounted) return;
      setState(() {
        _markers = result;
        _prepared = pending;
        _resultOk = result.contains('G8_PHONE_PHYSICAL_STORAGE_RESULT=0');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        // Deliberately never display exception.toString(), token data,
        // storage entries or Android platform exception messages.
        _failure = error is StateError
            ? error.message.toString()
            : 'G8_PHONE_ERROR_${error.runtimeType}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<List<String>> _clear() async {
    await G8PhoneStorageCheck.cleanup();
    return const ['G8_PHONE_MANUAL_LAB_CLEANUP=OK'];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('VENCIRA · G8 LAB'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              elevation: 0,
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Almacenamiento cifrado Android',
                        style: TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w700,
                        )),
                    SizedBox(height: 8),
                    Text('APK independiente de pruebas. Sin inicio de sesión, '
                        'sin conexión con el servidor y sin contraseñas reales. '
                        'Solo utiliza claves sintéticas.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Paso 1 · Preparar', style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                    )),
                    const SizedBox(height: 7),
                    const Text('Guarda un dato sintético cifrado y activa '
                        'el marcador de recuperación.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || _prepared
                          ? null
                          : () => _run(G8PhoneStorageCheck.prepare),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Preparar prueba'),
                    ),
                    const SizedBox(height: 14),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('Paso 2 · Cerrar y abrir', style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700,
                    )),
                    const SizedBox(height: 7),
                    const Text('Después del paso 1, ve a Ajustes del móvil '
                        '> Aplicaciones > VENCIRA G8 Pruebas > Forzar detención. '
                        'Abre esta APK de nuevo y pulsa Verificar.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _busy || !_prepared
                          ? null
                          : () => _run(
                              G8PhoneStorageCheck.verifyAfterRestart,
                            ),
                      icon: const Icon(Icons.verified_user_outlined),
                      label: const Text('Verificar tras reinicio'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_busy) const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            ),
            if (_resultOk)
              Card(
                color: const Color(0xFFE0F2EB),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline,
                        color: Color(0xFF177249)),
                    const SizedBox(width: 9),
                    Expanded(child: Text('Prueba completada: almacenamiento '
                        'y limpieza confirmados',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ))),
                  ]),
                ),
              if (_failure != null)
              Card(
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText('ERROR: ${_failure!}'),
                ),
              ),
            if (_markers.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: SelectableText(_markers.join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace', fontSize: 12.5,
                      )),
                ),
              ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _run(_clear),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Borrar datos de laboratorio'),
            ),
            const SizedBox(height: 12),
            Text('Esta prueba no verifica el uso de hardware seguro ni '
                'autoriza el despliegue. El proceso debe reiniciarse '
                'realmente; volver de una pantalla a otra no es suficiente.',
                style: TextStyle(color: scheme.onSurfaceVariant,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
