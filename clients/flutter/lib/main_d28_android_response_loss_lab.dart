// D28: two-stage physical Android lab: lost oc1 response, restart, or1 recovery.
// No production main.dart integration. No real users/passwords or TOTP secrets.
// Connects only to 127.0.0.1:18743 over an authenticated SSH tunnel;
// TLS verifies dev.vencira.es against a one-run embedded PUBLIC lab CA.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;

import 'api/native_api_endpoint.dart';
import 'api/native_http_auth_port.dart';
import 'api/native_mobile_recovery_entry.dart';
import 'api/native_first_issuance_entry.dart';
import 'api/native_mobile_entry_router.dart';
import 'api/native_session_coordinator.dart';
import 'api/native_mobile_startup_gate.dart';
import 'api/native_recovery_login_gateway.dart';
import 'api/native_refresh_credential_vault.dart';
import 'api/native_refresh_recovery_journal.dart';
import 'api/native_session_fence.dart';
import 'ui/native_login_screen.dart';

const _authorized = bool.fromEnvironment('VENCIRA_D28_ANDROID_LAB');
const _caB64 = String.fromEnvironment('VENCIRA_D28_PUBLIC_CA_B64');
const _syntheticPassword = 'synthetic-d28-password';
const _labHost = 'dev.vencira.es';
const _labPort = 18743;

class _Lab {
  _Lab() {
    store = FlutterNativeSecretStore(
      storage: const FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'vencira_d28_mobile_tls_lab_v1',
          resetOnError: false,
          migrateOnAlgorithmChange: false,
        ),
      ),
    );
    fence = NativeSessionFence();
    endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
  }

  late final FlutterNativeSecretStore store;
  late final NativeSessionFence fence;
  late final NativeApiEndpoint endpoint;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
}

SecurityContext _labTrust() {
  if (!_authorized || _caB64.isEmpty) {
    throw StateError('D28 explicit lab and public CA required');
  }
  final ca = base64Decode(_caB64);
  final text = utf8.decode(ca);
  if (!text.startsWith('-----BEGIN CERTIFICATE-----') ||
      !text.contains('-----END CERTIFICATE-----')) {
    throw StateError('Invalid lab CA');
  }
  final trust = SecurityContext(withTrustedRoots: false);
  trust.setTrustedCertificatesBytes(ca);
  return trust;
}

HttpClient _http(SecurityContext trust) {
  final c = HttpClient(context: trust);
  c.findProxy = (_) => 'DIRECT';
  c.connectionTimeout = const Duration(seconds: 8);
  c.connectionFactory = (uri, proxyHost, proxyPort) {
    if (proxyHost != null || proxyPort != null ||
        uri.scheme != 'https' || uri.host != _labHost || uri.port != 443) {
      throw StateError('D28 non-lab route denied');
    }
    return Socket.startConnect(InternetAddress.loopbackIPv4, _labPort)
        .then((task) {
      Socket? opened;
      final socket = task.socket.then((raw) async {
        opened = raw;
        try {
          final secure = await SecureSocket.secure(
              raw, host: _labHost, context: trust);
          opened = secure;
          return secure;
        } catch (_) {
          raw.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket<Socket>(socket, () {
        task.cancel();
        opened?.destroy();
      });
    });
  };
  return c;
}

String _totp() {
  // Public RFC 6238 fixture, never user-provided key material.
  const seed = '12345678901234567890';
  final counter = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
  final msg = ByteData(8)..setUint64(0, counter, Endian.big);
  final digest = Hmac(sha1, utf8.encode(seed))
      .convert(msg.buffer.asUint8List()).bytes;
  final o = digest.last & 15;
  final value = ((digest[o] & 0x7f) << 24) |
      (digest[o + 1] << 16) |
      (digest[o + 2] << 8) |
      digest[o + 3];
  return (value % 1000000).toString().padLeft(6, '0');
}

/// Deliberately lose ONLY the MFA response after the D27 server has issued.
class _LoseMfaResponse implements NativeAuthPort {
  _LoseMfaResponse(this.real);
  final NativeHttpAuthPort real;
  bool committedResponseDropped = false;

  @override
  Future<NativePasswordResponse> password({
    required String username, required String password,
  }) => real.password(username: username, password: password);

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge, required String code,
  }) async {
    // Real HTTPS request completes and returns authentic credentials.
    await real.mfa(challenge: challenge, code: code);
    committedResponseDropped = true;
    // The simulated lost response MUST never reach the coordinator.
    throw StateError('D28 synthetic response loss after server issuance');
  }

  @override
  Future<void> revoke({required String refresh}) =>
      real.revoke(refresh: refresh);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_authorized || kReleaseMode || !Platform.isAndroid) {
    throw StateError('D28 is available only in explicit Android debug lab');
  }
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _Screen()));
}

class _Screen extends StatefulWidget {
  const _Screen();
  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  bool _busy = false;
  String _status = 'SIN EJECUTAR';

  void _emit(String value) {
    if (mounted) setState(() => _status = value);
  }

  Future<void> _run() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Comprobando HTTPS y marcador seguro...';
    });
    IOClient? client;
    final lab = _Lab();
    try {
      final trust = _labTrust();
      final wrong = await Socket.connect(InternetAddress.loopbackIPv4, _labPort,
          timeout: const Duration(seconds: 8));
      try {
        try {
          final accepted = await SecureSocket.secure(wrong,
              host: 'wrong-d28.invalid', context: trust);
          accepted.destroy();
          throw StateError('Wrong hostname accepted');
        } on HandshakeException {
          // Correct rejection.
        }
      } finally {
        wrong.destroy();
      }
      final socket = await Socket.connect(InternetAddress.loopbackIPv4,
          _labPort, timeout: const Duration(seconds: 8));
      final verified = await SecureSocket.secure(socket,
          host: _labHost, context: trust);
      verified.destroy();
      _emit('D28_ANDROID_TLS_HOSTNAME=PASS');

      final raw = _http(trust);
      client = IOClient(raw);
      final real = NativeHttpAuthPort(endpoint: lab.endpoint, client: client);
      final drop = _LoseMfaResponse(real);
      final startup = NativeMobileStartupGate(
          fence: lab.fence, vault: lab.vault, journal: lab.journal);
      final first = NativeFirstIssuanceEntry(
          startup: startup,
          coordinator: NativeSessionCoordinator(
              port: drop, vault: lab.vault, fence: lab.fence,
              firstIssuanceJournal: lab.journal),
          journal: lab.journal);
      final recover = NativeMobileRecoveryEntry(
          startup: startup,
          recovery: NativeRecoveryLoginGateway(
              port: real, journal: lab.journal, vault: lab.vault,
              fence: lab.fence));
      final router = NativeMobileEntryRouter(
          startup: startup, firstIssuance: first, recovery: recover);
      final disposition = await router.inspect();
      if (disposition == NativeStartupDisposition.cleanLogin) {
        if (!identical(router.gateway, first)) {
          throw StateError('D28 unexpected issuance route');
        }
        final decision = await first.verifyPassword(
            username: 'd28-android', password: _syntheticPassword);
        if (decision != NativePasswordDecision.mfaRequired) {
          throw StateError('D28 MFA challenge missing');
        }
        try {
          await first.verifyTotp(_totp());
          throw StateError('D28 injected loss did not occur');
        } catch (_) {
          if (!drop.committedResponseDropped) rethrow;
        }
        if (!await lab.journal.requiresReauthentication() ||
            await lab.vault.read() != null ||
            lab.fence.ticket != null ||
            await first.accessToken() != null) {
          throw StateError('D28 uncertain first issuance not fenced');
        }
        _emit('D28_ANDROID_TLS_HOSTNAME=PASS\\n'
            'D28_ANDROID_OC1_ISSUED_RESPONSE_LOST=PASS\\n'
            'D28_ANDROID_DURABLE_MARKER=PASS\\n'
            'FASE 1 LISTA. Cierra completamente la aplicación, '
            'reinicia Android y vuelve a abrirla. Pulsa otra vez el botón.');
      } else if (disposition == NativeStartupDisposition.fullReauthentication) {
        if (!identical(router.gateway, recover) ||
            lab.fence.ticket != null ||
            !await lab.journal.requiresReauthentication()) {
          throw StateError('D28 restart recovery route rejected');
        }
        final result = await router.gateway.verifyPassword(
            username: 'd28-android', password: _syntheticPassword);
        if (result != NativePasswordDecision.mfaRequired ||
            await recover.accessToken() != null) {
          throw StateError('D28 password alone authorized access');
        }
        await router.gateway.verifyTotp(_totp());
        final access = await recover.accessToken();
        final refresh = await lab.vault.read();
        if (access == null || refresh == null ||
            lab.fence.ticket == null ||
            await lab.journal.requiresReauthentication()) {
          throw StateError('D28 recovery commit not verified');
        }
        _emit('D28_ANDROID_RECOVERY_AFTER_RESTART=PASS\\n'
            'D28_ANDROID_KEYSTORE_RECOVERY=PASS\\n'
            'Comprobando revocación...');
        lab.fence.revoke();
        await real.revoke(refresh: refresh);
        final request = http.Request(
            'GET', lab.endpoint.resolveApiPath('/api/v1/mobile/me/'))
          ..followRedirects = false
          ..headers['Authorization'] = 'Bearer $access';
        final response = await client.send(request);
        await response.stream.drain<void>();
        if (response.statusCode != 401 ||
            response.headers.containsKey('set-cookie')) {
          throw StateError('D28 revoked access still works');
        }
        await lab.vault.clear();
        if (await lab.vault.read() != null || lab.fence.ticket != null) {
          throw StateError('D28 local cleanup not verified');
        }
        _emit('D28_ANDROID_TLS_HOSTNAME=PASS\\n'
            'D28_ANDROID_RECOVERY_AFTER_RESTART=PASS\\n'
            'D28_ANDROID_KEYSTORE_RECOVERY=PASS\\n'
            'D28_ANDROID_REVOKE_401=PASS\\n'
            'D28_ANDROID_LAB_CLEANUP=PASS');
      } else {
        throw StateError('D28 startup locked');
      }
    } catch (_) {
      lab.fence.revoke();
      // No tokens or exception details in UI.
      _emit('D28_ANDROID_GATE=FAIL\\n'
          'Laboratorio bloqueado. No reintentar emisión ni refresh. '
          'Comprobar túnel, certificado y marcador seguro.');
    } finally {
      client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · Android D28')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.verified_user_outlined, size: 52),
              const SizedBox(height: 20),
              const Text('D28 · primer acceso y recuperación',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Laboratorio sintético en dos fases con reinicio. '
                  'Conecta primero el túnel SSH a 127.0.0.1:18743. '
                  'No utiliza cuentas ni credenciales reales.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _busy ? null : _run,
                  child: const Text('Ejecutar ensayo completo')),
              const SizedBox(height: 24),
              SelectableText(_status, textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
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
