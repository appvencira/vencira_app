/// I8-G physical Android, two-stage, debug-only secure-storage lab.
/// No backend, passwords, personal data, or production credential namespace.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/native_api_endpoint.dart';
import 'api/native_refresh_credential_vault.dart';

const _enabled = bool.fromEnvironment('VENCIRA_I8G_DEVICE_TEST');
const _first = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _second = 'v1.r.fedcba9876543210fedcba9876543210.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(
    storageNamespace: 'vencira_i8g_device_disposable_v1',
    resetOnError: false,
    migrateOnAlgorithmChange: false,
  ),
);
const _markerKey = 'i8g.disposable.force_stop_marker.v1';

NativeRefreshCredentialVault _vault() => NativeRefreshCredentialVault(
  endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
  store: FlutterNativeSecretStore(storage: _storage),
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_enabled || kReleaseMode || kIsWeb || !Platform.isAndroid) {
    throw StateError('NATIVE_I8G_ANDROID_DEBUG_ONLY');
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: I8gLabHome(),
  ));
}

class I8gLabHome extends StatefulWidget {
  const I8gLabHome({super.key});

  @override
  State<I8gLabHome> createState() => _I8gLabHomeState();
}

class _I8gLabHomeState extends State<I8gLabHome> {
  bool _busy = false;
  bool _pending = false;
  String _result = 'NATIVE_I8G_ANDROID_NOT_STARTED';

  @override
  void initState() {
    super.initState();
    _discover();
  }

  Future<void> _discover() async {
    try {
      final marker = await _storage.read(key: _markerKey);
      if (!mounted) return;
      setState(() => _pending = marker != null);
    } catch (_) {
      if (mounted) setState(() => _result = 'NATIVE_I8G_ANDROID_STORAGE_READ_FAILED');
    }
  }

  Future<void> _execute(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final value = await action();
      if (mounted) setState(() => _result = value);
    } catch (_) {
      if (mounted) {
        setState(() => _result = 'NATIVE_I8G_ANDROID_PHASE_FAILED');
      }
    } finally {
      await _discover();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _prepare() async {
    if (await _storage.read(key: _markerKey) != null) {
      throw StateError('PREVIOUS_PHASE_INCOMPLETE');
    }
    final vault = _vault();
    await vault.clear();
    if (await vault.read() != null) throw StateError('NOT_EMPTY');
    await vault.replace(_first);
    if (await _vault().read() != _first) throw StateError('READBACK_FAILED');
    await vault.replace(_second);
    if (await _vault().read() != _second) throw StateError('ROTATION_FAILED');
    await _storage.write(key: _markerKey, value: 'pending-i8g-v1');
    if (await _storage.read(key: _markerKey) != 'pending-i8g-v1') {
      throw StateError('MARKER_NOT_DURABLE');
    }
    return 'NATIVE_I8G_ANDROID_PHASE1=PASS';
  }

  Future<String> _verify() async {
    final marker = await _storage.read(key: _markerKey);
    if (marker != 'pending-i8g-v1' || await _vault().read() != _second) {
      throw StateError('PERSISTENCE_FAILED');
    }
    await _vault().clear();
    if (await _vault().read() != null) throw StateError('DELETE_FAILED');
    await _storage.delete(key: _markerKey);
    if (await _storage.read(key: _markerKey) != null) {
      throw StateError('MARKER_DELETE_FAILED');
    }
    return 'NATIVE_I8G_ANDROID_PHASE2_PERSISTENCE=PASS';
  }

  Future<String> _clean() async {
    await _vault().clear();
    await _storage.delete(key: _markerKey);
    if (await _vault().read() != null ||
        await _storage.read(key: _markerKey) != null) {
      throw StateError('CLEAN_FAILED');
    }
    return 'NATIVE_I8G_ANDROID_LAB_CLEAN=PASS';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · I8-G Android')),
    body: SafeArea(child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Almacenamiento seguro Android',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        const Text('APK DEBUG aislada. Sin acceso al servidor. Solo credenciales '
          'sintéticas en un espacio exclusivo de laboratorio.'),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy || _pending ? null : () => _execute(_prepare),
          child: const Text('1. Guardar y rotar credencial sintética'),
        ),
        const SizedBox(height: 8),
        const Text('Después de la fase 1, fuerza la detención de esta aplicación '
          'desde Ajustes de Android y vuelve a abrirla. No borres los datos.'),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _busy || !_pending ? null : () => _execute(_verify),
          child: const Text('2. Verificar persistencia y borrar'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => _execute(_clean),
          child: const Text('Borrar datos sintéticos de I8-G'),
        ),
        const SizedBox(height: 16),
        SelectableText(_result, style: const TextStyle(fontFamily: 'monospace')),
        const SizedBox(height: 12),
        const Text('No prueba atestación de hardware, identidad de usuario ni '
          'autenticación operativa. No autoriza publicación.'),
      ],
    )),
  );
}
