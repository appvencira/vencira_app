// Android-only I8-N manual Keystore laboratory. Never imported by main.dart.
// Build only debug with VENCIRA_I8N_LAB_BUILD=1 and the explicit lab target.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api/native_api_endpoint.dart';
import 'api/native_mobile_startup_gate.dart';
import 'api/native_refresh_credential_vault.dart';
import 'api/native_refresh_recovery_journal.dart';
import 'api/native_session_fence.dart';

const _labBuild = bool.fromEnvironment('VENCIRA_I8N_ANDROID_LAB');
const _markerKey = 'vencira.mobile.dev.uncertain.v1';
const _syntheticRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _Lab {
  _Lab() {
    store = FlutterNativeSecretStore(
      storage: const FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'vencira_i8n_restart_lab_v1',
          resetOnError: false,
          migrateOnAlgorithmChange: false,
        ),
      ),
    );
    fence = NativeSessionFence();
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
  }

  late final FlutterNativeSecretStore store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_labBuild || kReleaseMode || !Platform.isAndroid) {
    throw StateError('I8-N requires an isolated Android debug APK');
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VENCIRA I8-N Keystore',
    home: _LabScreen(),
  ));
}

class _LabScreen extends StatefulWidget {
  const _LabScreen();

  @override
  State<_LabScreen> createState() => _LabScreenState();
}

class _LabScreenState extends State<_LabScreen> {
  bool _busy = false;
  String _result = 'SIN EJECUTAR';

  Future<void> _execute(String phase) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _result = 'Ejecutando ' + phase + '...';
    });
    try {
      final lab = _Lab();
      if (phase == 'seed') {
        await lab.store.delete(_markerKey);
        await lab.vault.clear();
        await lab.vault.replace(_syntheticRefresh);
        await lab.journal.arm();
        if (await lab.vault.read() != _syntheticRefresh ||
            !await lab.journal.requiresReauthentication() ||
            lab.fence.ticket != null) {
          throw StateError('Seed read-back or fence verification failed');
        }
        _report('I8N_ANDROID_KEYSTORE_SEED=PASS\n'
            'Reinicia el móvil y vuelve a abrir esta APK. '
            'Después pulsa Verificar.');
      } else if (phase == 'verify') {
        // Requires a separate process after a genuine phone reboot.
        if (await lab.vault.read() != _syntheticRefresh ||
            !await lab.journal.requiresReauthentication()) {
          throw StateError('No durable recovery credentials found');
        }
        final startup = NativeMobileStartupGate(
          fence: lab.fence, vault: lab.vault, journal: lab.journal,
        );
        if (await startup.inspect() !=
                NativeStartupDisposition.fullReauthentication ||
            lab.fence.ticket != null) {
          throw StateError('Cold-start recovery fence not closed');
        }
        _report('I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS\n'
            'El estado protegido persiste y la sesión sigue bloqueada. '
            'Pulsa Limpiar.');
      } else if (phase == 'cleanup') {
        await lab.vault.clear();
        await lab.store.delete(_markerKey);
        if (await lab.vault.read() != null ||
            await lab.journal.requiresReauthentication()) {
          throw StateError('Lab cleanup verification failed');
        }
        final startup = NativeMobileStartupGate(
          fence: lab.fence, vault: lab.vault, journal: lab.journal,
        );
        if (await startup.inspect() != NativeStartupDisposition.cleanLogin ||
            lab.fence.ticket != null) {
          throw StateError('Clean state was authenticated unexpectedly');
        }
        _report('I8N_ANDROID_KEYSTORE_CLEANUP=PASS\n'
            'Eliminados solo los datos sintéticos del laboratorio.');
      } else {
        throw StateError('Invalid lab phase');
      }
    } catch (_) {
      // Do not log exceptions, platform secrets or credential values.
      _report('I8N_ANDROID_' + phase.toUpperCase() + '=FAIL\n'
          'Comprobación fallida. No se ha activado ninguna sesión.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _report(String message) {
    if (mounted) setState(() => _result = message);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · Keystore I8-N')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.security_outlined, size: 50),
              const SizedBox(height: 14),
              const Text('Laboratorio aislado de almacenamiento Android',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              const Text(
                'Sin conexiones de red ni credenciales reales. '
                'No desinstales ni borres los datos de esta APK '
                'entre Guardar y Verificar.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _busy ? null : () => _execute('seed'),
                child: const Text('1 · Guardar datos sintéticos'),
              ),
              const SizedBox(height: 12),
              const Text('Reinicia completamente el teléfono y vuelve '
                  'a abrir esta APK.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy ? null : () => _execute('verify'),
                child: const Text('2 · Verificar tras reinicio'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _busy ? null : () => _execute('cleanup'),
                child: const Text('3 · Limpiar laboratorio'),
              ),
              const SizedBox(height: 28),
              SelectableText(_result, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              const Text('MFA_RELEASE_AUTHORIZED=NO\n'
                  'NO_DEPLOY_NO_LIVE_MIGRATION=1',
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );
}
