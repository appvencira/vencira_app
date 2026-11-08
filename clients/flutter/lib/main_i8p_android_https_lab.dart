// I8-P: independent Android debug lab for FULL native HTTPS recovery.
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
import 'api/native_mobile_startup_gate.dart';
import 'api/native_recovery_login_gateway.dart';
import 'api/native_refresh_credential_vault.dart';
import 'api/native_refresh_recovery_journal.dart';
import 'api/native_session_fence.dart';
import 'ui/native_login_screen.dart';

const _authorized = bool.fromEnvironment('VENCIRA_I8P_ANDROID_LAB');
const _caB64 = String.fromEnvironment('VENCIRA_I8P_PUBLIC_CA_B64');
const _old = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _syntheticPassword = 'synthetic-i8p-password';
const _labHost = 'dev.vencira.es';
const _labPort = 18743;

class _Lab {
  _Lab() {
    store = FlutterNativeSecretStore(
      storage: const FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'vencira_i8p_mobile_tls_lab_v1',
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
    throw StateError('I8-P explicit lab and public CA required');
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
      throw StateError('I8-P non-lab route denied');
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!_authorized || kReleaseMode || !Platform.isAndroid) {
    throw StateError('I8-P is available only in explicit Android debug lab');
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
      _status = 'Comprobando conexión TLS y recuperación...';
    });
    IOClient? client;
    final lab = _Lab();
    try {
      final trust = _labTrust();
      // Fail-closed on a wrong SNI/hostname before any HTTP credentials.
      final raw = await Socket.connect(InternetAddress.loopbackIPv4, _labPort,
          timeout: const Duration(seconds: 8));
      try {
        try {
          final unexpected = await SecureSocket.secure(raw,
              host: 'wrong-i8p.invalid', context: trust);
          unexpected.destroy();
          throw StateError('Wrong hostname accepted');
        } on HandshakeException {
          // Expected.
        }
      } finally {
        raw.destroy();
      }
      final validSocket = await Socket.connect(
          InternetAddress.loopbackIPv4, _labPort,
          timeout: const Duration(seconds: 8));
      final verified = await SecureSocket.secure(validSocket,
          host: _labHost, context: trust);
      verified.destroy();
      _emit('I8P_ANDROID_TLS_HOSTNAME=PASS\n'
          'Recuperando cuenta sintética...');

      // Starting with an orphan refresh requires durable full reauth.
      // Clear only the dedicated I8-P namespace, not operational storage.
      await lab.vault.clear();
      await lab.store.delete('vencira.mobile.dev.uncertain.v1');
      await lab.vault.replace(_old);
      final rawClient = _http(trust);
      client = IOClient(rawClient);
      final port = NativeHttpAuthPort(endpoint: lab.endpoint, client: client);
      final gateway = NativeRecoveryLoginGateway(
          port: port, journal: lab.journal, vault: lab.vault,
          fence: lab.fence);
      final entry = NativeMobileRecoveryEntry(
          startup: NativeMobileStartupGate(
              fence: lab.fence, vault: lab.vault, journal: lab.journal),
          recovery: gateway);
      if (await entry.inspect() !=
              NativeStartupDisposition.fullReauthentication ||
          lab.fence.ticket != null) {
        throw StateError('Startup incorrectly allowed a session');
      }
      final password = await entry.verifyPassword(
          username: 'i8p-recovery', password: _syntheticPassword);
      if (password != NativePasswordDecision.mfaRequired ||
          await entry.accessToken() != null) {
        throw StateError('Password alone activated a session');
      }
      await entry.verifyTotp(_totp());
      final access = await entry.accessToken();
      final newRefresh = await lab.vault.read();
      if (access == null || newRefresh == null || newRefresh == _old ||
          lab.fence.ticket == null ||
          await lab.journal.requiresReauthentication()) {
        throw StateError('Protected commit or MFA failed');
      }
      _emit('I8P_ANDROID_TLS_HOSTNAME=PASS\n'
          'I8P_ANDROID_RECOVERY_MFA_KEYSTORE=PASS\n'
          'Validando revocación...');

      // Remote revoke is explicit. Never log bearer/refresh credentials.
      lab.fence.revoke();
      await port.revoke(refresh: newRefresh);
      // Verify the same bearer is rejected after remote revocation.
      final probe = http.Request(
          'GET', lab.endpoint.resolveApiPath('/api/v1/mobile/me/'))
        ..followRedirects = false
        ..headers['Authorization'] = 'Bearer $access';
      final denial = await client.send(probe);
      await denial.stream.drain<void>();
      if (denial.statusCode != 401 ||
          denial.headers.containsKey('set-cookie')) {
        throw StateError('Remote access token survived revocation');
      }
      await lab.vault.clear();
      if (lab.fence.ticket != null ||
          await lab.vault.read() != null) {
        throw StateError('Logout storage/fence verification failed');
      }
      _emit('I8P_ANDROID_TLS_HOSTNAME=PASS\n'
          'I8P_ANDROID_RECOVERY_MFA_KEYSTORE=PASS\n'
          'I8P_ANDROID_REMOTE_REVOKE=PASS\n'
          'I8P_ANDROID_ACCESS_AFTER_REVOKE_401=PASS\n'
          'I8P_ANDROID_LAB_CLEANUP=PASS');
    } catch (_) {
      lab.fence.revoke();
      // No token values or exception messages ever leave this lab UI.
      _emit('I8P_ANDROID_GATE=FAIL\n'
          'Sesión bloqueada. Comprueba túnel SSH, CA y laboratorio VPS. '
          'Un fallo ambiguo exige recuperación completa.');
    } finally {
      client?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('VENCIRA · Android I8-P')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.verified_user_outlined, size: 52),
              const SizedBox(height: 20),
              const Text('HTTPS + MFA + Keystore',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              const Text('Únicamente laboratorio sintético. '
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
