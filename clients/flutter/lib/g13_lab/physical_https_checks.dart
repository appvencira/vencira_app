// G13 physical Android -> verified TLS -> disposable Django only.
// No operational backend: TCP is forced through localhost ADB reverse,
// with a fresh test CA and strict dev.vencira.es hostname verification.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/native_api_endpoint.dart';
import '../api/native_first_issuance_entry.dart';
import '../api/native_http_auth_port.dart';
import '../api/native_mobile_recovery_entry.dart';
import '../api/native_mobile_startup_gate.dart';
import '../api/native_recovery_login_gateway.dart';
import '../api/native_refresh_credential_vault.dart';
import '../api/native_refresh_recovery_journal.dart';
import '../api/native_session_coordinator.dart';
import '../api/native_session_fence.dart';
import '../ui/native_login_screen.dart';

const _labCa = String.fromEnvironment('G13_LAB_PUBLIC_CA_BASE64');
const _labPort = 18743;
const _markerKey = 'vencira.mobile.dev.uncertain.v1';
const _refreshKey = 'vencira.mobile.dev.refresh.v1';
const _pidKey = 'vencira.g13.physical.restart_pid.v1';
const _markerValue = 'full-reauth-required-v1';
const _username = 'g7-d2-synthetic';
const _password = 'G7-D2-Only-Synthetic-Password-2026!';
const _mfaUsername = 'g7-e-mfa-synthetic';
const _mfaPassword = 'G7-E-Only-Synthetic-Mfa-Password-2026!';

void _require(bool condition, String code) {
  if (!condition) throw StateError('G13_' + code);
}

NativeApiEndpoint get _endpoint =>
    NativeApiEndpoint.parse('https://dev.vencira.es');

class _G13Client extends http.BaseClient {
  _G13Client(this.inner, this.store, this.fence);

  final http.Client inner;
  final NativeSecretStore store;
  final NativeSessionFence fence;
  int issues = 0;
  int mfa = 0;
  int revokes = 0;
  int recovery = 0;
  bool loseIssueResponse = false;
  bool failRevokeBeforeSend = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final p = request.url.path;
    final approved = p == '/api/v1/mobile/auth/password/' ||
        p == '/api/v1/mobile/auth/mfa/' ||
        p == '/api/v1/mobile/auth/recover/password/' ||
        p == '/api/v1/mobile/auth/recover/mfa/' ||
        p == '/api/v1/mobile/token/revoke/' ||
        p == '/api/v1/mobile/me/';
    if (!approved || request.url.host != 'dev.vencira.es' ||
        request.url.scheme != 'https' || request.url.port != 443) {
      throw StateError('G13_UNEXPECTED_REQUEST_TARGET');
    }
    if (request.method == 'POST') {
      if (fence.ticket != null ||
          await store.read(_markerKey) != _markerValue) {
        throw StateError('G13_REQUEST_WITHOUT_DURABLE_CHECKPOINT');
      }
      if (p.endsWith('/password/') && !p.contains('/recover/')) issues++;
      if (p.endsWith('/mfa/') && !p.contains('/recover/')) mfa++;
      if (p.contains('/recover/')) recovery++;
      if (p.endsWith('/revoke/')) {
        revokes++;
        if (failRevokeBeforeSend) {
          failRevokeBeforeSend = false;
          throw const SocketException('G13_OFFLINE_FAULT_PRE_REVOKE');
        }
      }
    }
    final response = await inner.send(request);
    if (p == '/api/v1/mobile/auth/password/' && loseIssueResponse) {
      loseIssueResponse = false;
      // Django has committed an issuance. Discard the response WITHOUT
      // reading, recording or logging access/refresh token material.
      await response.stream.drain<void>();
      throw const SocketException('G13_POST_COMMIT_ISSUANCE_RESPONSE_LOST');
    }
    return response;
  }

  @override
  void close() {} // The owning lab scenario closes the underlying client.
}

http.Client _createTlsClient({required bool trustLabCa}) {
  _require(Platform.isAndroid && _labCa.isNotEmpty,
      'DEBUG_ANDROID_AND_CA_REQUIRED');
  final trust = SecurityContext(withTrustedRoots: false);
  if (trustLabCa) {
    final pem = utf8.decode(base64.decode(_labCa));
    _require(pem.contains('-----BEGIN CERTIFICATE-----') &&
        pem.contains('-----END CERTIFICATE-----') &&
        !pem.contains('PRIVATE KEY') && pem.length < 16384,
        'INVALID_PUBLIC_CA');
    trust.setTrustedCertificatesBytes(utf8.encode(pem));
  }
  final client = HttpClient(context: trust)
    ..findProxy = (_) => 'DIRECT'
    ..connectionTimeout = const Duration(seconds: 5)
    ..idleTimeout = const Duration(seconds: 3);

  client.connectionFactory = (uri, proxyHost, proxyPort) {
    if (uri.scheme != 'https' || uri.host != 'dev.vencira.es' ||
        uri.port != 443 || proxyHost != null || proxyPort != null) {
      throw StateError('G13_NONLAB_DESTINATION_BLOCKED');
    }
    // ADB reverse maps Android 127.0.0.1:18743 to host 127.0.0.1:18743.
    // The host proxy forwards raw TLS to the isolated Docker fixture.
    // Hostname and SNI remain dev.vencira.es, certificate validation enabled.
    return Socket.startConnect(InternetAddress.loopbackIPv4, _labPort)
        .then((task) {
      Socket? active;
      final Future<Socket> verified = task.socket.then((raw) async {
        active = raw;
        try {
          final secure = await SecureSocket.secure(
            raw, host: uri.host, context: trust,
          );
          active = secure;
          return secure;
        } catch (_) {
          raw.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket<Socket>(verified, () {
        task.cancel();
        active?.destroy();
      });
    });
  };
  return IOClient(client);
}

Future<int> _meStatus(http.Client client, String? access) async {
  final request = http.Request(
      'GET', _endpoint.resolveApiPath('/api/v1/mobile/me/'))
    ..followRedirects = false;
  if (access != null) request.headers['Authorization'] = 'Bearer ' + access;
  final response = await client.send(request).timeout(
      const Duration(seconds: 10));
  await response.stream.drain<void>();
  return response.statusCode;
}

String _publicTotp() {
  // RFC 6238 public 20-byte sample secret; fixture only, never account data.
  final counter = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
  final timestamp = ByteData(8)..setUint64(0, counter, Endian.big);
  final digest = Hmac(sha1, utf8.encode('12345678901234567890'))
      .convert(timestamp.buffer.asUint8List()).bytes;
  final index = digest.last & 0x0f;
  final number = ((digest[index] & 0x7f) << 24) |
      ((digest[index + 1] & 0xff) << 16) |
      ((digest[index + 2] & 0xff) << 8) |
      (digest[index + 3] & 0xff);
  return (number % 1000000).toString().padLeft(6, '0');
}

class _Case {
  _Case(this.store, http.Client trusted) {
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: _endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
        endpoint: _endpoint, store: store, fence: fence);
    observed = _G13Client(trusted, store, fence);
    port = NativeHttpAuthPort(endpoint: _endpoint, client: observed);
    coordinator = NativeSessionCoordinator(
      port: port, vault: vault, fence: fence,
      firstIssuanceJournal: journal,
    );
    entry = NativeFirstIssuanceEntry(
      startup: NativeMobileStartupGate(
          fence: fence, vault: vault, journal: journal),
      coordinator: coordinator, journal: journal,
    );
  }

  final NativeSecretStore store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final _G13Client observed;
  late final NativeHttpAuthPort port;
  late final NativeSessionCoordinator coordinator;
  late final NativeFirstIssuanceEntry entry;
}

class G13PhoneHttpsCheck {
  static const _namespace = 'vencira_g13_phone_tls_v1';

  static NativeSecretStore _newStore() => FlutterNativeSecretStore(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: _namespace,
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
    ),
  );

  static Future<bool> hasPendingRestart() async =>
      (await SharedPreferences.getInstance()).containsKey(_pidKey);

  static Future<List<String>> prepare() async {
    _require(Platform.isAndroid, 'ANDROID_ONLY');
    final prefs = await SharedPreferences.getInstance();
    _require(!prefs.containsKey(_pidKey), 'RESTART_ALREADY_PENDING');
    final store = _newStore();
    _require(await store.read(_markerKey) == null &&
        await store.read(_refreshKey) == null, 'LAB_STORE_NOT_CLEAN');

    final trusted = _createTlsClient(trustLabCa: true);
    try {
      _require(await _meStatus(trusted, null) == 401,
          'VERIFIED_TLS_PREFLIGHT_FAILED');
      final untrusted = _createTlsClient(trustLabCa: false);
      try {
        var rejected = false;
        try {
          await _meStatus(untrusted, null);
        } on HandshakeException {
          rejected = true;
        } on TlsException {
          rejected = true;
        }
        _require(rejected, 'UNTRUSTED_CA_NOT_REJECTED');
      } finally {
        untrusted.close();
      }

      final standard = _Case(store, trusted);
      _require(await standard.entry.inspect() ==
          NativeStartupDisposition.cleanLogin, 'CLEAN_LOGIN_REQUIRED');
      _require(await standard.entry.verifyPassword(
          username: _username, password: _password,
        ) == NativePasswordDecision.authenticated &&
        standard.observed.issues == 1 &&
        standard.fence.ticket != null &&
        await standard.vault.read() != null &&
        !await standard.journal.requiresReauthentication(),
        'FIRST_ISSUANCE_COMMIT');
      final access = await standard.entry.accessToken();
      _require(access != null && await _meStatus(trusted, access) == 200,
          'SERVER_BEARER_DENIED_AFTER_ISSUE');
      final closing = standard.entry.logout();
      _require(standard.fence.ticket == null,
          'LOGOUT_FENCE_NOT_SYNCHRONOUS');
      await closing;
      _require(standard.observed.revokes == 1 &&
          await standard.vault.read() == null &&
          !await standard.journal.requiresReauthentication() &&
          await _meStatus(trusted, access) == 401,
          'DJANGO_LOGOUT_NOT_CONFIRMED');

      final mfa = _Case(store, trusted);
      _require(await mfa.entry.inspect() ==
          NativeStartupDisposition.cleanLogin, 'MFA_PREFLIGHT_FAILED');
      _require(await mfa.entry.verifyPassword(
          username: _mfaUsername, password: _mfaPassword,
        ) == NativePasswordDecision.mfaRequired &&
        await mfa.journal.requiresReauthentication() &&
        mfa.fence.ticket == null, 'MFA_PASSWORD_UNLOCKED_EARLY');
      await mfa.entry.verifyTotp(_publicTotp());
      final mfaAccess = await mfa.entry.accessToken();
      _require(mfa.observed.mfa == 1 && mfaAccess != null &&
          mfa.fence.ticket != null &&
          await _meStatus(trusted, mfaAccess) == 200,
          'MFA_DJANGO_TLS_COMMIT_FAILED');
      await mfa.entry.logout();
      _require(await mfa.vault.read() == null &&
          !await mfa.journal.requiresReauthentication() &&
          await _meStatus(trusted, mfaAccess) == 401,
          'MFA_REVOKE_FAILED');

      final uncertain = _Case(store, trusted);
      _require(await uncertain.entry.inspect() ==
          NativeStartupDisposition.cleanLogin, 'UNCERTAIN_PREFLIGHT_FAILED');
      uncertain.observed.loseIssueResponse = true;
      var responseLost = false;
      try {
        await uncertain.entry.verifyPassword(
            username: _username, password: _password);
      } on NativeHttpAuthFailure {
        responseLost = true;
      }
      _require(responseLost && uncertain.observed.issues == 1 &&
          uncertain.fence.ticket == null &&
          await uncertain.vault.read() == null &&
          await uncertain.journal.requiresReauthentication(),
          'UNKNOWN_ISSUANCE_DID_NOT_FENCE');

      _require(await prefs.setInt(_pidKey, pid),
          'RESTART_PID_NOT_DURABLY_SAVED');
      return const [
        'G13_ANDROID_TLS_CERT_VERIFIED=OK',
        'G13_ANDROID_UNTRUSTED_CA_DENIED=OK',
        'G13_ANDROID_REAL_FIRST_ISSUE=OK',
        'G13_ANDROID_DJANGO_LOGOUT_REVOKED=OK',
        'G13_ANDROID_MFA_TLS_COMMITTED=OK',
        'G13_ANDROID_UNKNOWN_ISSUANCE_FENCED=OK',
        'G13_ANDROID_FORCE_STOP_REQUIRED=1',
      ];
    } finally {
      trusted.close();
    }
  }

  static Future<List<String>> verifyAfterRestart() async {
    _require(Platform.isAndroid, 'ANDROID_ONLY');
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getInt(_pidKey);
    _require(previous != null && previous != pid,
        'REAL_ANDROID_PROCESS_RESTART_REQUIRED');
    final store = _newStore();
    final fence = NativeSessionFence();
    final vault = NativeRefreshCredentialVault(
        endpoint: _endpoint, store: store);
    final journal = NativeRefreshRecoveryJournal(
        endpoint: _endpoint, store: store, fence: fence);
    _require(await journal.requiresReauthentication() &&
        await vault.read() == null && fence.ticket == null,
        'DURABLE_MARKER_MISSING_AFTER_RESTART');

    final trusted = _createTlsClient(trustLabCa: true);
    try {
      _require(await _meStatus(trusted, null) == 401,
          'RESTART_TLS_CONNECTION_UNAVAILABLE');
      final observed = _G13Client(trusted, store, fence);
      final port = NativeHttpAuthPort(endpoint: _endpoint, client: observed);
      final recovery = NativeMobileRecoveryEntry(
        startup: NativeMobileStartupGate(
          fence: fence, vault: vault, journal: journal,
        ),
        recovery: NativeRecoveryLoginGateway(
          port: port, journal: journal, vault: vault, fence: fence,
        ),
      );
      _require(await recovery.inspect() ==
          NativeStartupDisposition.fullReauthentication,
          'RECOVERY_GATE_DID_NOT_ROUTE');
      _require(await recovery.verifyPassword(
          username: _username, password: _password,
        ) == NativePasswordDecision.authenticated &&
        observed.recovery == 1 &&
        await vault.read() != null &&
        !await journal.requiresReauthentication() &&
        fence.ticket != null, 'SERVER_ACCOUNT_RECOVERY_FAILED');
      final access = await recovery.accessToken();
      _require(access != null && await _meStatus(trusted, access) == 200,
          'RECOVERED_ACCESS_DENIED_BY_DJANGO');

      // G6 recovery gateway has no dedicated safe logout API. Test the G10
      // journal/vault logout primitives explicitly, with real server revoke.
      await journal.arm();
      await port.revoke(refresh: (await vault.read())!);
      await vault.clear();
      await journal.confirmLogoutCompleted(vault: vault);
      _require(fence.ticket == null &&
          await vault.read() == null &&
          !await journal.requiresReauthentication() &&
          await _meStatus(trusted, access) == 401,
          'RECOVERY_SERVER_LOGOUT_FAILED');

      await store.write(_markerKey, 'g13-test-invalid-marker');
      var blocked = false;
      try {
        await journal.requiresReauthentication();
      } on StateError {
        blocked = true;
      }
      _require(blocked && fence.ticket == null,
          'CORRUPTED_MARKER_DOWNGRADED');

      await cleanup();
      return const [
        'G13_ANDROID_NEW_PROCESS=OK',
        'G13_ANDROID_TLS_CONNECTION_AFTER_RESTART=OK',
        'G13_ANDROID_DURABLE_MARKER_SURVIVED=OK',
        'G13_ANDROID_G9_RECOVERY_REQUIRED=OK',
        'G13_ANDROID_SERVER_RECOVERY_COMMITTED=OK',
        'G13_ANDROID_RECOVERED_SESSION_REVOKED=OK',
        'G13_ANDROID_CORRUPT_MARKER_BLOCKED=OK',
        'G13_ANDROID_STORAGE_CLEANED=OK',
        'G13_ANDROID_REAL_HTTPS_RESULT=0',
      ];
    } finally {
      trusted.close();
    }
  }

  static Future<void> cleanup() async {
    final store = _newStore();
    await store.delete(_markerKey);
    await store.delete(_refreshKey);
    _require(await store.read(_markerKey) == null &&
        await store.read(_refreshKey) == null,
        'CLEANUP_UNVERIFIED');
    final prefs = await SharedPreferences.getInstance();
    _require(await prefs.remove(_pidKey), 'PID_CLEANUP_UNVERIFIED');
  }
}
