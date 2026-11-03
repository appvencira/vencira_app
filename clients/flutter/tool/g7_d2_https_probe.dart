/// G7-D2: a real HTTPS / TLS integration probe for VENCIRA native session.
///
/// THIS IS NOT AN APP ENTRYPOINT. Run only inside the Docker --internal lab
/// network where "dev.vencira.es" resolves to an isolated test server.
/// A private test CA is provided at runtime. No production tokens, keys,
/// credentials, trust-bypass callbacks, or operational URLs are used.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
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

Future<void> main() async {
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
  } finally {
    httpClient.close();
  }
}
