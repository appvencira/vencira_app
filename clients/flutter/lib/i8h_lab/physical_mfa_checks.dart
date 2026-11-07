/// I8-H: physical Android HTTPS -> disposable candidate PG17 MFA issuer.
///
/// Debug only. Credentials are synthetic and the HTTPS TCP peer is Android
/// localhost:18743 over a user-controlled SSH forward/USB reverse.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../api/native_api_endpoint.dart';
import '../api/native_api_transport.dart';
import '../api/native_first_issuance_entry.dart';
import '../api/native_http_auth_port.dart';
import '../api/native_mobile_startup_gate.dart';
import '../api/native_refresh_credential_vault.dart';
import '../api/native_refresh_recovery_journal.dart';
import '../api/native_session_coordinator.dart';
import '../api/native_session_fence.dart';
import '../ui/native_login_screen.dart';

const _ca64 = String.fromEnvironment('I8H_PUBLIC_CA_BASE64');
const _port = 18743;
const _username = 'i8e-synthetic-logout';
const _password = 'synthetic-i8e-password';
const _namespace = 'vencira_i8h_candidate_pg17_v1';

String i8hDiagnosticStage = 'START';
void _stage(String value) { i8hDiagnosticStage = value; }

const _store = FlutterSecureStorage(
  aOptions: AndroidOptions(
    storageNamespace: _namespace,
    resetOnError: false,
    migrateOnAlgorithmChange: false,
  ),
);

void _require(bool condition, String code) {
  if (!condition) throw StateError('NATIVE_I8H_$code');
}

NativeApiEndpoint get _endpoint =>
    NativeApiEndpoint.parse('https://dev.vencira.es');

http.Client _client({required bool trusted}) {
  _require(Platform.isAndroid && _ca64.isNotEmpty, 'DEBUG_CA_REQUIRED');
  final pem = utf8.decode(base64.decode(_ca64));
  _require(pem.contains('-----BEGIN CERTIFICATE-----') &&
      pem.contains('-----END CERTIFICATE-----') &&
      !pem.contains('PRIVATE KEY') && pem.length < 16384,
      'PUBLIC_CA_FORMAT');
  final context = SecurityContext(withTrustedRoots: false);
  if (trusted) context.setTrustedCertificatesBytes(utf8.encode(pem));
  // Keep assignments separate: chaining a cascade after a callback
  // assignment can bind the next cascade to the callback's String result.
  final client = HttpClient(context: context);
  client.findProxy = (_) => 'DIRECT';
  client.connectionTimeout = const Duration(seconds: 5);
  client.idleTimeout = const Duration(seconds: 4);
  client.connectionFactory = (uri, proxyHost, proxyPort) {
    if (proxyHost != null || proxyPort != null ||
        uri.scheme != 'https' || uri.host != 'dev.vencira.es' ||
        uri.port != 443) {
      throw StateError('NATIVE_I8H_REMOTE_TARGET_FORBIDDEN');
    }
    return Socket.startConnect(InternetAddress.loopbackIPv4, _port)
        .then((task) {
      final Future<Socket> verified = task.socket.then((raw) async {
        try {
          return await SecureSocket.secure(
            raw, host: uri.host, context: context,
          );
        } catch (_) {
          raw.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket<Socket>(verified, () {
        task.cancel();
        verified.then((socket) => socket.destroy(), onError: (_) {});
      });
    });
  };
  return IOClient(client);
}

String _totp() {
  // Public RFC 6238 test material; fixture in ephemeral PG17 only.
  final count = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
  final b = ByteData(8)..setUint64(0, count, Endian.big);
  final digest = Hmac(sha1, utf8.encode('12345678901234567890'))
      .convert(b.buffer.asUint8List()).bytes;
  final offset = digest.last & 15;
  final value = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
  return (value % 1000000).toString().padLeft(6, '0');
}

Future<int> _me(http.Client client, String? access) async {
  final req = http.Request(
    'GET', _endpoint.resolveApiPath('/api/v1/mobile/me/'),
  )..followRedirects = false;
  if (access != null) req.headers['Authorization'] = 'Bearer $access';
  final res = await client.send(req).timeout(const Duration(seconds: 15));
  await res.stream.drain<void>();
  _require(!res.headers.containsKey('set-cookie'), 'COOKIE_ISSUANCE_DENIED');
  return res.statusCode;
}

Future<List<String>> runPhysicalMfa() async {
  _stage('VAULT_START');
  final store = FlutterNativeSecretStore(storage: _store);
  final fence = NativeSessionFence();
  final vault = NativeRefreshCredentialVault(endpoint: _endpoint, store: store);
  final journal = NativeRefreshRecoveryJournal(
    endpoint: _endpoint, store: store, fence: fence,
  );
  final startup = NativeMobileStartupGate(
    fence: fence, vault: vault, journal: journal,
  );
  // MUST verify local storage is empty before any network request.
  // An incomplete previous run must remain fenced for manual cleanup.
  _stage('STARTUP_INSPECTION');
  _require(await startup.inspect() == NativeStartupDisposition.cleanLogin,
      'PREEXISTING_SESSION_REQUIRES_RECOVERY');
  final trusted = _client(trusted: true);
  try {
    _stage('TLS_PREFLIGHT');
    _require(await _me(trusted, null) == 401, 'TLS_PREFLIGHT_401');
    _stage('UNTRUSTED_CA');
    final untrusted = _client(trusted: false);
    try {
      var rejected = false;
      try {
        await _me(untrusted, null);
      } on HandshakeException {
        rejected = true;
      } on TlsException {
        rejected = true;
      }
      _require(rejected, 'UNTRUSTED_CA_WAS_ACCEPTED');
    } finally {
      untrusted.close();
    }

    final port = NativeHttpAuthPort(endpoint: _endpoint, client: trusted);
    final coordinator = NativeSessionCoordinator(
      port: port, vault: vault, fence: fence,
      firstIssuanceJournal: journal,
    );
    final entry = NativeFirstIssuanceEntry(
      startup: NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal,
      ),
      coordinator: coordinator, journal: journal,
    );
    _stage('FIRST_ISSUE_INSPECT');
    _require(await entry.inspect() == NativeStartupDisposition.cleanLogin,
        'FIRST_ISSUANCE_GATE');
    _stage('PASSWORD_CHALLENGE');
    _require(await entry.verifyPassword(
      username: _username, password: _password,
    ) == NativePasswordDecision.mfaRequired, 'PASSWORD_MFA_REQUIRED');
    _require(fence.ticket == null && await vault.read() == null &&
        await journal.requiresReauthentication(), 'PASSWORD_NO_ACCESS');
    _stage('TOTP_ISSUANCE');
    await entry.verifyTotp(_totp());
    final access = await entry.accessToken();
    _require(access != null && fence.ticket != null &&
        await vault.read() != null &&
        !await journal.requiresReauthentication(),
        'ANDROID_PROTECTED_REFRESH_COMMITTED');
    final transport = NativeApiTransport(
      endpoint: _endpoint, client: trusted,
      accessToken: entry.accessToken,
      sessionFence: fence,
    );
    _stage('BEARER_ME');
    final me = await transport.getJson('/api/v1/mobile/me/');
    _require(me is Map<String, dynamic> && me['authenticated'] == true,
        'ANDROID_BEARER_HTTPS_ME');
    _stage('LOGOUT_REVOKE');
    final closing = entry.logout();
    _require(fence.ticket == null, 'LOGOUT_LOCAL_FENCE');
    await closing;
    _require(await vault.read() == null &&
        !await journal.requiresReauthentication() &&
        await _me(trusted, access) == 401,
        'LOGOUT_REMOTE_REVOKED_AND_CLEAN');
    _stage('COMPLETE');
    return const [
      'NATIVE_I8H_ANDROID_CA_VERIFIED=PASS',
      'NATIVE_I8H_ANDROID_UNTRUSTED_CA_DENIED=PASS',
      'NATIVE_I8H_ANDROID_PASSWORD_NO_TOKENS=PASS',
      'NATIVE_I8H_ANDROID_MFA_PG17_ISSUED=PASS',
      'NATIVE_I8H_ANDROID_KEYSTORE_REFRESH=PASS',
      'NATIVE_I8H_ANDROID_BEARER_ME=PASS',
      'NATIVE_I8H_ANDROID_REMOTE_LOGOUT=PASS',
      'NATIVE_I8H_ANDROID_REAL_HTTPS_RESULT=0',
    ];
  } finally {
    trusted.close();
  }
}

