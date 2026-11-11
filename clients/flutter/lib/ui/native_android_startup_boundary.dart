import 'package:flutter/material.dart';

import '../api/native_api_endpoint.dart';
import '../api/native_mobile_startup_gate.dart';
import '../api/native_refresh_credential_vault.dart';
import '../api/native_refresh_recovery_journal.dart';
import '../api/native_session_fence.dart';
import 'android_web_access_screen.dart';

/// Read-only native startup classification for the REAL Android entrypoint.
/// Does not issue credentials, contact an auth endpoint or enable login.
/// A prior/uncertain refresh stays fenced until the account-wide recovery
/// protocol is actually available and independently authorized.
class NativeAndroidStartupBoundary extends StatefulWidget {
  const NativeAndroidStartupBoundary({super.key, this.inspect});

  /// Test seam; production always inspects the protected platform storage.
  final Future<NativeStartupDisposition> Function()? inspect;

  @override
  State<NativeAndroidStartupBoundary> createState() =>
      _NativeAndroidStartupBoundaryState();
}

class _NativeAndroidStartupBoundaryState
    extends State<NativeAndroidStartupBoundary> {
  NativeStartupDisposition? _disposition;
  bool _storageFailure = false;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<NativeStartupDisposition> _platformInspect() {
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    final store = FlutterNativeSecretStore();
    final fence = NativeSessionFence();
    final vault = NativeRefreshCredentialVault(
      endpoint: endpoint, store: store,
    );
    final journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    return NativeMobileStartupGate(
      fence: fence, vault: vault, journal: journal,
    ).inspect();
  }

  Future<void> _inspect() async {
    try {
      final result = await (widget.inspect ?? _platformInspect)();
      if (!mounted) return;
      setState(() => _disposition = result);
    } catch (_) {
      if (!mounted) return;
      setState(() => _storageFailure = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_storageFailure && _disposition == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('native-startup-checking'),
          ),
        ),
      );
    }
    if (_storageFailure ||
        _disposition == NativeStartupDisposition.locked) {
      return const AndroidWebAccessScreen(
        statusMessage: 'El almacenamiento seguro de Android no se ha '
            'podido verificar. El acceso nativo permanece bloqueado.',
      );
    }
    if (_disposition ==
        NativeStartupDisposition.fullReauthentication) {
      return const AndroidWebAccessScreen(
        statusMessage: 'Existe una sesión nativa anterior o pendiente de '
            'recuperación. No se reutilizarán sus credenciales. '
            'La recuperación nativa aún no está disponible.',
      );
    }
    // Clean login state does not grant authorization or permit any requests.
    // The existing browser handoff remains the only supported UI.
    return const AndroidWebAccessScreen();
  }
}
