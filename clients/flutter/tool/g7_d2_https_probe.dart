/// G7-D2: a real HTTPS / TLS integration probe for VENCIRA native session.
///
/// THIS IS NOT AN APP ENTRYPOINT. Run only inside the Docker --internal lab
/// network where "dev.vencira.es" resolves to an isolated test server.
/// A private test CA is provided at runtime. No production tokens, keys,
/// credentials, trust-bypass callbacks, or operational URLs are used.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _username = 'g7-d2-synthetic';
const _password = 'G7-D2-Only-Synthetic-Password-2026!';
const _serverAlias = 'dev.vencira.es';
const _tlsPort = 8443;

InternetAddress _privateLabPeer() {
  final value = Platform.environment['G7_D2_PEER_IPV4'];
  final address = InternetAddress.tryParse(value ?? '');
  if (address == null || address.type != InternetAddressType.IPv4) {
    throw StateError('G7_D2_PRIVATE_PEER_REQUIRED');
  }
  final bytes = address.rawAddress;
  final privateRange = bytes[0] == 10 ||
      (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
      (bytes[0] == 192 && bytes[1] == 168);
  if (!privateRange) {
    throw StateError('G7_D2_PUBLIC_PEER_FORBIDDEN');
  }
  return address;
}

void _require(bool passed, String name) {
  if (!passed) throw StateError('G7_D2_${name}_FAILED');
  stdout.writeln('G7_D2_${name}=OK');
}

/// Use the real HttpClient and real TLS certificate validation, but force
/// the TCP connection into a Docker-internal network alias. The original
/// URI hostname remains unchanged for SNI and SAN verification. Never
/// resolve or connect to the public operational domain over the internet.
HttpClient _httpsClient(SecurityContext trust, {String host = _serverAlias}) {
  // Keep assignments separate: a cascade immediately after a function
  // expression could otherwise bind to the function's String return value.
  final client = HttpClient(context: trust);
  client.findProxy = (_) => 'DIRECT';
  client.connectionTimeout = const Duration(seconds: 5);
  client.idleTimeout = const Duration(seconds: 3);
  client.connectionFactory = (uri, proxyHost, proxyPort) {
    if (proxyHost != null ||
        proxyPort != null ||
        uri.host != host ||
        uri.scheme != 'https' ||
        uri.port != 443) {
      stdout.writeln(
        'G7_D2_FACTORY_REJECTED: '
        'schemeHttps=${uri.scheme == 'https'} '
        'port443=${uri.port == 443} '
        'expectedHost=${uri.host == host} '
        'proxyPresent=${proxyHost != null || proxyPort != null}',
      );
      throw StateError('G7_D2_UNEXPECTED_REMOTE_TARGET');
    }
    stdout.writeln('G7_D2_FACTORY_PRIVATE_TCP=OK');
    // Setting connectionFactory replaces Dart's automatic HTTPS socket.
    // We MUST return a TLS-upgraded socket, not a plaintext Socket:
    // HttpClient will otherwise send an HTTP request to the TLS listener.
    // TCP goes only to Docker's inspected private IPv4 (no public DNS).
    // SecureSocket.secure verifies the trusted temporary CA and the
    // ORIGINAL URI host as the peer identity/SNI; never bypass verification.
    return Socket.startConnect(_privateLabPeer(), _tlsPort).then((task) {
      Socket? active;
      final Future<Socket> verified = task.socket.then((raw) async {
        active = raw;
        try {
          final secure = await SecureSocket.secure(
            raw, host: uri.host, context: trust,
          );
          active = secure;
          stdout.writeln('G7_D2_FACTORY_VERIFIED_TLS=OK');
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
  return client;
}

/// Independent strict TLS handshake. It uses a private TCP peer and the
/// original DNS name for SNI/certificate verification, with no DNS lookup.
Future<void> _preflightTls(SecurityContext trust) async {
  Socket? raw;
  try {
    raw = await Socket.connect(
      _privateLabPeer(), _tlsPort,
      timeout: const Duration(seconds: 5),
    );
    final secure = await SecureSocket.secure(
      raw, host: _serverAlias, context: trust,
    );
    raw = null; // SecureSocket now owns the underlying connection.
    secure.destroy();
    stdout.writeln('G7_D2_TLS_PREFLIGHT=OK');
  } catch (error) {
    // Only the runtime type, never host addresses, certificates or secrets.
    stdout.writeln('G7_D2_TLS_PREFLIGHT_FAILURE_TYPE=${error.runtimeType}');
    rethrow;
  } finally {
    raw?.destroy();
  }
}

/// Observe only transport metadata; leave the production auth parser intact.
/// In particular, no authorization headers, request bodies, cookies, tokens,
/// response bodies or exception strings are ever sent to stdout.
class _SafeHttpTraceClient extends http.BaseClient {
  _SafeHttpTraceClient(this._inner);
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final kind = switch (path) {
      '/api/v1/mobile/auth/password/' => 'PASSWORD',
      '/api/v1/mobile/auth/mfa/' => 'MFA',
      '/api/v1/mobile/auth/recover/password/' => 'RECOVER_PASSWORD',
      '/api/v1/mobile/auth/recover/mfa/' => 'RECOVER_MFA',
      '/api/v1/mobile/token/refresh/' => 'REFRESH',
      '/api/v1/mobile/me/' => 'ME',
      '/api/v1/mobile/token/revoke/' => 'REVOKE',
      _ => 'UNEXPECTED_PATH',
    };
    try {
      final response = await _inner.send(request);
      stdout.writeln('G7_D2_HTTP_${kind}_STATUS=${response.statusCode}');
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase().split(';').first.trim();
      stdout.writeln(
        'G7_D2_HTTP_${kind}_JSON_CONTENT_TYPE=${contentType == 'application/json'}',
      );
      stdout.writeln(
        'G7_D2_HTTP_${kind}_HAS_SET_COOKIE=${response.headers.containsKey('set-cookie')}',
      );
      return response;
    } catch (error) {
      stdout.writeln('G7_D2_HTTP_${kind}_TRANSPORT_FAILURE_TYPE=${error.runtimeType}');
      rethrow;
    }
  }

  @override
  void close() => _inner.close();
}

class _DisposableSecretStore implements NativeSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Future<void> _expectHttpAuthDenied(Future<Object?> Function() operation) async {
  var denied = false;
  try {
    await operation();
  } on NativeHttpAuthFailure {
    denied = true;
  }
  if (!denied) throw StateError('G7_D2_EXPECTED_DENIAL_MISSING');
}

/// RFC 6238/HMAC-SHA1, computed only for the disposable MFA fixture.
/// The 20-byte ASCII secret is the public RFC test vector (not a real key).
/// Never print the generated code or export encrypted MFA key material.
String _syntheticTotp([DateTime? at]) {
  final counter =
      (at ?? DateTime.now()).toUtc().millisecondsSinceEpoch ~/ 30000;
  final timestamp = ByteData(8)..setUint64(0, counter, Endian.big);
  final digest = Hmac(
    sha1, utf8.encode('12345678901234567890'),
  ).convert(timestamp.buffer.asUint8List()).bytes;
  final offset = digest.last & 0x0f;
  final value = ((digest[offset] & 0x7f) << 24) |
      ((digest[offset + 1] & 0xff) << 16) |
      ((digest[offset + 2] & 0xff) << 8) |
      (digest[offset + 3] & 0xff);
  return (value % 1000000).toString().padLeft(6, '0');
}

/// A direct Bearer check verifies what Django accepts, independently of
/// any already-revoked local coordinator fence. No token reaches logs.
Future<int> _bearerHttpStatus(
  http.Client client, NativeApiEndpoint endpoint, String access,
) async {
  final request = http.Request(
    'GET', endpoint.resolveApiPath('/api/v1/mobile/me/'),
  )
    ..followRedirects = false
    ..maxRedirects = 0
    ..headers['Authorization'] = 'Bearer $access';
  final response = await client.send(request);
  await response.stream.drain<void>();
  return response.statusCode;
}

/// G7-E1: real Django-issued MFA challenge + RFC TOTP over verified HTTPS.
/// Password alone must never open the request gate or write a refresh token.
Future<void> _verifyMfaHttps(
  NativeApiEndpoint endpoint, http.Client client,
) async {
  // RFC 6238 Appendix B at 59 s: SHA-1 eight-digit 94287082,
  // six-digit projection 287082, using ASCII 12345678901234567890.
  _require(
    _syntheticTotp(DateTime.fromMillisecondsSinceEpoch(
      59000, isUtc: true,
    )) == '287082',
    'RFC6238_TOTP_VECTOR',
  );
  final store = _DisposableSecretStore();
  final fence = NativeSessionFence();
  final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
  final coordinator = NativeSessionCoordinator(
    port: port,
    vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
    fence: fence,
  );
  final transport = NativeApiTransport(
    endpoint: endpoint, client: client,
    accessToken: coordinator.accessToken,
    sessionFence: fence,
  );

  final passwordDecision = await coordinator.verifyPassword(
    username: 'g7-e-mfa-synthetic',
    password: 'G7-E-Only-Synthetic-Mfa-Password-2026!',
  );
  _require(
    passwordDecision == NativePasswordDecision.mfaRequired &&
        fence.ticket == null &&
        store.values.isEmpty &&
        await coordinator.accessToken() == null,
    'MFA_PASSWORD_ONLY_CHALLENGE',
  );
  var protectedReadDenied = false;
  try {
    await transport.getJson('/api/v1/mobile/me/');
  } on NativeApiSessionUnavailable {
    protectedReadDenied = true;
  }
  _require(
    protectedReadDenied && fence.ticket == null,
    'MFA_PENDING_BEARER_DENIED',
  );

  final consumedCode = _syntheticTotp();
  await coordinator.verifyTotp(consumedCode);
  final access = await coordinator.accessToken();
  _require(
    fence.ticket != null && store.values.length == 1 &&
        access != null && access.startsWith('v1.a.'),
    'MFA_VERIFIED_SESSION_ISSUED',
  );
  final me = await transport.getJson('/api/v1/mobile/me/');
  _require(
    me is Map<String, dynamic> && me['authenticated'] == true,
    'MFA_VERIFIED_BEARER_ME',
  );

  // An already-consumed OTP must not open another challenge. Keep the
  // original authenticated session unaffected until explicit logout.
  final another = await port.password(
    username: 'g7-e-mfa-synthetic',
    password: 'G7-E-Only-Synthetic-Mfa-Password-2026!',
  );
  if (another is! NativePasswordMfaRequired) {
    throw StateError('G7_E_EXPECTED_NEW_MFA_CHALLENGE');
  }
  await _expectHttpAuthDenied(
    () => port.mfa(challenge: another.challenge, code: consumedCode),
  );
  _require(
    fence.ticket != null && store.values.length == 1,
    'MFA_REUSED_TOTP_DENIED',
  );

  final logout = coordinator.logout();
  _require(fence.ticket == null, 'MFA_LOGOUT_FENCE_SYNCHRONOUS');
  await logout;
  _require(
    store.values.isEmpty && fence.ticket == null &&
        await _bearerHttpStatus(client, endpoint, access!) == 401,
    'MFA_REMOTE_REVOKE_AND_VAULT_CLEAR',
  );
  stdout.writeln('G7_E_MFA_HTTPS_RESULT=0');
}

/// G7-E2: HTTP token rotation/replay using NativeHttpAuthPort, not the
/// coordinator (its crash-safe refresh recovery adapter is NOT implemented).
/// A stale refresh replay must invalidate even the newly rotated access.
Future<void> _verifyRefreshHttps(
  NativeApiEndpoint endpoint, http.Client client,
) async {
  final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
  Future<NativeIssuedTokens> login() async {
    final reply = await port.password(
      username: _username, password: _password,
    );
    if (reply is! NativePasswordGranted) {
      throw StateError('G7_E_UNEXPECTED_MFA_ON_ROTATION_ACCOUNT');
    }
    return reply.tokens;
  }

  final oldTokens = await login();
  final rotated = await port.rotateRefresh(oldTokens.refresh);
  _require(
    rotated.access != oldTokens.access &&
        rotated.refresh != oldTokens.refresh,
    'REFRESH_BOTH_TOKENS_ROTATED',
  );
  _require(
    await _bearerHttpStatus(client, endpoint, oldTokens.access) == 401 &&
        await _bearerHttpStatus(client, endpoint, rotated.access) == 200,
    'REFRESH_OLD_ACCESS_DENIED',
  );

  await _expectHttpAuthDenied(
    () => port.rotateRefresh(oldTokens.refresh),
  );
  _require(
    await _bearerHttpStatus(client, endpoint, rotated.access) == 401,
    'REFRESH_REPLAY_REVOKES_NEW_ACCESS',
  );

  // Also test normal rotation then a successful remote revoke, separately
  // from the replay-invalidated device.
  final fresh = await login();
  final active = await port.rotateRefresh(fresh.refresh);
  await port.revoke(refresh: active.refresh);
  _require(
    await _bearerHttpStatus(client, endpoint, active.access) == 401,
    'REFRESH_NEW_CREDENTIAL_REVOKED',
  );
  stdout.writeln('G7_E_REFRESH_REPLAY_RESULT=0');
}

/// G7-F1: password reauthentication after the backend committed a refresh
/// rotation but the response was discarded. The journal is armed and checked
/// BEFORE the one-use refresh can be sent. The gateway must not retry refresh:
/// it must obtain fresh credentials via the separate recover/password route.
Future<void> _verifyAmbiguousRefreshRecoveryHttps(
  NativeApiEndpoint endpoint, http.Client client,
) async {
  final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
  final original = await port.password(
    username: _username, password: _password,
  );
  if (original is! NativePasswordGranted) {
    throw StateError('G7_F_EXPECTED_PASSWORD_CREDENTIALS');
  }

  final fence = NativeSessionFence();
  final store = _DisposableSecretStore();
  final vault = NativeRefreshCredentialVault(
    endpoint: endpoint, store: store,
  );
  final journal = NativeRefreshRecoveryJournal(
    endpoint: endpoint, store: store, fence: fence,
  );
  final gateway = NativeRecoveryLoginGateway(
    port: port, journal: journal, vault: vault, fence: fence,
  );

  await vault.replace(original.tokens.refresh);
  await journal.arm();
  _require(
    fence.ticket == null &&
        await journal.requiresReauthentication() &&
        await vault.read() == original.tokens.refresh,
    'RECOVERY_MARKER_DURABLE_BEFORE_NETWORK',
  );

  // This exchange represents a successfully committed backend rotation
  // whose response is LOST to the app. The test retains only the new access
  // as an oracle to verify that Django revoked it after recovery.
  final lostResponse = await port.rotateRefresh(original.tokens.refresh);
  _require(
    await _bearerHttpStatus(
      client, endpoint, lostResponse.access,
    ) == 200 &&
        await vault.read() == original.tokens.refresh &&
        fence.ticket == null,
    'RECOVERY_LOST_ROTATION_RESPONSE_LOCKED',
  );

  // Simulate cold start: no access token is ever reconstructed from the
  // stale refresh; the durable marker requires a full password exchange.
  _require(
    await gateway.requiresRecovery() &&
        await gateway.accessToken() == null &&
        fence.ticket == null,
    'RECOVERY_COLD_START_DENIES_ACCESS',
  );

  await _expectHttpAuthDenied(
    () => gateway.verifyPassword(
      username: _username, password: 'incorrect-synthetic-only',
    ),
  );
  _require(
    await journal.requiresReauthentication() &&
        fence.ticket == null &&
        await _bearerHttpStatus(
          client, endpoint, lostResponse.access,
        ) == 200,
    'RECOVERY_WRONG_PASSWORD_PRESERVES_OLD_DEVICE',
  );

  final result = await gateway.verifyPassword(
    username: _username, password: _password,
  );
  final access = await gateway.accessToken();
  final refresh = await vault.read();
  _require(
    result == NativePasswordDecision.authenticated &&
        access != null &&
        refresh != null &&
        refresh != original.tokens.refresh &&
        refresh != lostResponse.refresh &&
        !await journal.requiresReauthentication() &&
        fence.ticket != null &&
        store.values.length == 1,
    'RECOVERY_REAUTH_COMMIT_AND_CLEAR_MARKER',
  );
  _require(
    await _bearerHttpStatus(
      client, endpoint, lostResponse.access,
    ) == 401 &&
        await _bearerHttpStatus(client, endpoint, access!) == 200,
    'RECOVERY_ACCOUNT_WIDE_REVOKE',
  );
  await _expectHttpAuthDenied(
    () => port.rotateRefresh(lostResponse.refresh),
  );

  // Explicitly revoke the newly recovered session before ending the
  // disposable laboratory, so a recovered token never remains live.
  fence.revoke();
  await port.revoke(refresh: refresh!);
  await vault.clear();
  _require(
    fence.ticket == null &&
        store.values.isEmpty &&
        await _bearerHttpStatus(client, endpoint, access!) == 401,
    'RECOVERY_FINAL_REVOKE_CLEARS_VAULT',
  );
  stdout.writeln('G7_F_AMBIGUOUS_REFRESH_RECOVERY_RESULT=0');
}

/// G7-G: full MFA recovery via the distinct /recover/* contract after a
/// refresh response is lost. Both OTPs use the RFC public synthetic vector.
/// The initial login consumes the previous accepted 30-second step, and the
/// reauthentication consumes the current later step. Never print either OTP.
Future<void> _verifyMfaRecoveryHttps(
  NativeApiEndpoint endpoint, http.Client client,
) async {
  const username = 'g7-g-mfa-recovery';
  const password = 'G7-G-Only-Synthetic-Mfa-Password-2026!';
  final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
  final first = await port.password(username: username, password: password);
  if (first is! NativePasswordMfaRequired) {
    throw StateError('G7_G_BASELINE_MFA_REQUIRED');
  }
  final priorCode = _syntheticTotp(
    DateTime.now().subtract(const Duration(seconds: 30)),
  );
  final previous = await port.mfa(
    challenge: first.challenge, code: priorCode,
  );
  _require(
    await _bearerHttpStatus(client, endpoint, previous.access) == 200,
    'MFA_RECOVERY_BASELINE_AUTHENTICATED',
  );

  final store = _DisposableSecretStore();
  final previousFence = NativeSessionFence();
  final originalVault = NativeRefreshCredentialVault(
    endpoint: endpoint, store: store,
  );
  final originalJournal = NativeRefreshRecoveryJournal(
    endpoint: endpoint, store: store, fence: previousFence,
  );
  await originalVault.replace(previous.refresh);
  await originalJournal.arm();
  _require(
    previousFence.ticket == null &&
        await originalJournal.requiresReauthentication(),
    'MFA_RECOVERY_CHECKPOINT_BEFORE_ROTATION',
  );
  // Backend commits refresh rotation. The client discards the new tokens.
  final unseen = await port.rotateRefresh(previous.refresh);
  _require(
    await _bearerHttpStatus(client, endpoint, unseen.access) == 200 &&
        await originalVault.read() == previous.refresh,
    'MFA_RECOVERY_LOST_REFRESH_RESPONSE',
  );

  // A new gateway and journal simulate a restart with the same synthetic
  // protected store. No access is rehydrated from the old credential.
  final fence = NativeSessionFence();
  final vault = NativeRefreshCredentialVault(
    endpoint: endpoint, store: store,
  );
  final journal = NativeRefreshRecoveryJournal(
    endpoint: endpoint, store: store, fence: fence,
  );
  final gateway = NativeRecoveryLoginGateway(
    port: port, journal: journal, vault: vault, fence: fence,
  );
  _require(
    await gateway.requiresRecovery() &&
        await gateway.accessToken() == null &&
        fence.ticket == null,
    'MFA_RECOVERY_COLD_START_FENCED',
  );

  final decision = await gateway.verifyPassword(
    username: username, password: password,
  );
  _require(
    decision == NativePasswordDecision.mfaRequired &&
        await journal.requiresReauthentication() &&
        fence.ticket == null &&
        await vault.read() == previous.refresh &&
        await _bearerHttpStatus(client, endpoint, unseen.access) == 200,
    'MFA_RECOVERY_PASSWORD_CANNOT_REVOKE',
  );

  // Replaying the TOTP already consumed at baseline must fail without
  // consuming the pending challenge or revoking any existing device.
  await _expectHttpAuthDenied(() => gateway.verifyTotp(priorCode));
  _require(
    await journal.requiresReauthentication() &&
        fence.ticket == null &&
        await _bearerHttpStatus(client, endpoint, unseen.access) == 200,
    'MFA_RECOVERY_REPLAY_NO_ACCOUNT_REVOKE',
  );

  await gateway.verifyTotp(_syntheticTotp());
  final freshAccess = await gateway.accessToken();
  final freshRefresh = await vault.read();
  _require(
    freshAccess != null &&
        freshRefresh != null &&
        freshRefresh != previous.refresh &&
        freshRefresh != unseen.refresh &&
        fence.ticket != null &&
        !await journal.requiresReauthentication(),
    'MFA_RECOVERY_VERIFIED_COMMIT',
  );
  _require(
    await _bearerHttpStatus(client, endpoint, unseen.access) == 401 &&
        await _bearerHttpStatus(client, endpoint, freshAccess!) == 200,
    'MFA_RECOVERY_ACCOUNT_WIDE_REVOKE',
  );
  await _expectHttpAuthDenied(
    () => port.rotateRefresh(unseen.refresh),
  );

  // Explicit cleanup; all accounts and credentials are disposable test data.
  fence.revoke();
  await port.revoke(refresh: freshRefresh!);
  await vault.clear();
  _require(
    fence.ticket == null &&
        store.values.isEmpty &&
        await _bearerHttpStatus(client, endpoint, freshAccess!) == 401,
    'MFA_RECOVERY_FINAL_LOGOUT_REVOKES',
  );
  stdout.writeln('G7_G_MFA_RECOVERY_HTTPS_RESULT=0');
}

Future<void> main() async {
  final group = Platform.environment['G7_LAB_GROUP'] ?? 'all';
  if (group != 'all' && group != 'd2' && group != 'e' && group != 'f' && group != 'g') {
    throw StateError('G7_LAB_GROUP_NOT_ALLOWED');
  }
  if (Platform.environment['G7_D2_ISOLATED_NETWORK_ACK'] != '1') {
    throw StateError('G7_D2_ISOLATION_REQUIRED');
  }
  final caPath = Platform.environment['G7_D2_CA_FILE'];
  if (caPath == null || caPath != '/tmp/g7d2-public-ca.pem') {
    throw StateError('G7_D2_TEMP_CA_REQUIRED');
  }
  final caBytes = await File(caPath).readAsBytes();
  final trust = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(caBytes);
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  await _preflightTls(trust);
  final httpClient = _SafeHttpTraceClient(IOClient(_httpsClient(trust)));

  try {
    if (group == 'all' || group == 'd2') {
      final store = _DisposableSecretStore();
      final fence = NativeSessionFence();
      final port = NativeHttpAuthPort(endpoint: endpoint, client: httpClient);
      final coordinator = NativeSessionCoordinator(
        port: port,
        vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
        fence: fence,
      );
      final transport = NativeApiTransport(
        endpoint: endpoint,
        client: httpClient,
        accessToken: coordinator.accessToken,
        sessionFence: fence,
      );

      // Server must never see an unauthenticated read attempt at this step.
      var lockedBeforeLogin = false;
      try {
        await transport.getJson('/api/v1/mobile/me/');
      } on NativeApiSessionUnavailable {
        lockedBeforeLogin = true;
      }
      _require(lockedBeforeLogin && fence.ticket == null, 'INITIAL_FENCE');

      final decision = await coordinator.verifyPassword(
        username: _username, password: _password,
      );
      _require(
        decision == NativePasswordDecision.authenticated &&
            fence.ticket != null &&
            store.values.length == 1,
        'REAL_HTTPS_LOGIN_AND_VAULT',
      );

      final access = await coordinator.accessToken();
      _require(access != null && access.startsWith('v1.a.'),
          'REAL_HTTPS_ACCESS_SHAPE');
      final result = await transport.getJson('/api/v1/mobile/me/');
      _require(
        result is Map<String, dynamic> &&
            result['authenticated'] == true &&
            result['user_id'] is int,
        'REAL_HTTPS_BEARER_ME',
      );

      final closing = coordinator.logout();
      _require(fence.ticket == null, 'LOGOUT_FENCE_SYNCHRONOUS');
      await closing;
      _require(store.values.isEmpty && fence.ticket == null,
          'REMOTE_REVOKE_AND_LOCAL_CLEAR');

      // The server must refuse the previously issued Bearer, not just the
      // local fence. Nothing from this request is persisted or printed.
      final oldAccessRequest = http.Request(
        'GET', endpoint.resolveApiPath('/api/v1/mobile/me/'),
      )..headers['Authorization'] = 'Bearer $access';
      final oldAccessReply = await httpClient.send(oldAccessRequest);
      await oldAccessReply.stream.drain<void>();
      _require(oldAccessReply.statusCode == 401,
          'SERVER_REJECTS_REVOKED_ACCESS');

      final deniedStore = _DisposableSecretStore();
      final deniedFence = NativeSessionFence();
      final deniedCoordinator = NativeSessionCoordinator(
        port: port,
        vault: NativeRefreshCredentialVault(
          endpoint: endpoint, store: deniedStore,
        ),
        fence: deniedFence,
      );
      await _expectHttpAuthDenied(() => deniedCoordinator.verifyPassword(
        username: _username, password: 'incorrect-synthetic-only',
      ));
      _require(deniedFence.ticket == null && deniedStore.values.isEmpty,
          'INVALID_PASSWORD_FAILS_CLOSED');

      // Deliberately send a *synthetic* cookie: the native issuer must
      // never accept browser sessions.
      final cookieRequest = http.Request(
        'POST', endpoint.resolveApiPath('/api/v1/mobile/auth/password/'),
      )
        ..headers['Content-Type'] = 'application/json'
        ..headers['Cookie'] = 'vencira_sessionid=synthetic'
        ..body = jsonEncode({'username': _username, 'password': _password});
      final cookieReply = await httpClient.send(cookieRequest);
      await cookieReply.stream.drain<void>();
      _require(cookieReply.statusCode == 403, 'WEB_COOKIE_DENIED');

      // On a rejected browser-cookie request, Django's SessionMiddleware may
      // delete the supplied invalid cookie. Distinguish cookie deletion from
      // issuing an active session without ever logging a Set-Cookie value.
      final cookieHeader = cookieReply.headers['set-cookie'];
      if (cookieHeader != null) {
        final cookieName = cookieHeader.split('=').first.trim();
        final isSessionCookie = cookieName == 'vencira_sessionid';
        final isDeletion = RegExp(
          r'(?:^|;)\s*max-age=0(?:;|$)', caseSensitive: false,
        ).hasMatch(cookieHeader);
        stdout.writeln(
          'G7_D2_REJECT_COOKIE_SESSION_NAME=$isSessionCookie',
        );
        stdout.writeln(
          'G7_D2_REJECT_COOKIE_DELETION=$isDeletion',
        );
        _require(
          isSessionCookie && isDeletion,
          'WEB_COOKIE_RESPONSE_ONLY_DELETES_SESSION',
        );
      } else {
        stdout.writeln('G7_D2_REJECT_COOKIE_ABSENT=OK');
      }

      final invalidTrustClient = IOClient(
        _httpsClient(SecurityContext(withTrustedRoots: false)),
      );
      try {
        await _expectHttpAuthDenied(() => NativeHttpAuthPort(
          endpoint: endpoint,
          client: invalidTrustClient,
        ).password(username: _username, password: 'incorrect-synthetic-only'));
        stdout.writeln('G7_D2_UNTRUSTED_CA_DENIED=OK');
      } finally {
        invalidTrustClient.close();
      }

      // "vencira.es" is policy-allowlisted in general, but this lab leaf is
      // valid ONLY for dev.vencira.es. Route it to the same isolated service
      // and require a TLS hostname mismatch, never a trust-bypass.
      final wrongHost = NativeApiEndpoint.parse('https://vencira.es');
      final wrongHostClient = IOClient(_httpsClient(trust, host: 'vencira.es'));
      try {
        await _expectHttpAuthDenied(() => NativeHttpAuthPort(
          endpoint: wrongHost,
          client: wrongHostClient,
        ).password(username: _username, password: 'incorrect-synthetic-only'));
        stdout.writeln('G7_D2_HOSTNAME_MISMATCH_DENIED=OK');
      } finally {
        wrongHostClient.close();
      }

      stdout.writeln('G7_D2_HTTPS_FLUTTER_DJANGO_RESULT=0');
    }
    if (group == 'all' || group == 'e') {
      await _verifyMfaHttps(endpoint, httpClient);
      await _verifyRefreshHttps(endpoint, httpClient);
    }
    if (group == 'all' || group == 'f') {
      await _verifyAmbiguousRefreshRecoveryHttps(endpoint, httpClient);
    }
    if (group == 'all' || group == 'g') {
      await _verifyMfaRecoveryHttps(endpoint, httpClient);
    }
    stdout.writeln('G7_LAB_GROUP_COMPLETE=$group');
  } finally {
    httpClient.close();
  }
}
