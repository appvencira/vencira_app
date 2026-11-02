import 'dart:convert';

import 'package:http/http.dart' as http;

import 'native_api_endpoint.dart';
import 'native_mobile_token_shape.dart';
import 'native_recovery_login_gateway.dart';
import 'native_session_coordinator.dart';

/// Browserless password/MFA transport contract. Not instantiated by main.dart
/// and NOT operational until the N1 server endpoints pass release gates.
///
/// Does not accept web cookies, redirects, SessionAuthentication, or CSRF
/// tokens. No automatic retries for password, one-time MFA or revocation.
class NativeHttpAuthPort implements NativeAuthPort, NativeRecoveryAuthPort {
  NativeHttpAuthPort({
    required this.endpoint,
    required this.client,
    this.connectTimeout = const Duration(seconds: 15),
    this.streamIdleTimeout = const Duration(seconds: 15),
  });

  final NativeApiEndpoint endpoint;
  final http.Client client;
  final Duration connectTimeout;
  final Duration streamIdleTimeout;

  static const int maxResponseBytes = 8192;
  static const int maxRequestBytes = 4096;

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> payload,
  ) async {
    final uri = endpoint.resolveApiPath(path);
    final json = jsonEncode(payload);
    if (utf8.encode(json).length > maxRequestBytes) {
      throw const NativeHttpAuthFailure();
    }
    final request = http.Request('POST', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Content-Type'] = 'application/json'
      ..body = json;
    late http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(connectTimeout);
      if (response.statusCode != 200 ||
          response.headers.containsKey('set-cookie')) {
        throw const NativeHttpAuthFailure();
      }
      final mediaType = (response.headers['content-type'] ?? '')
          .toLowerCase()
          .split(';')
          .first
          .trim();
      if (mediaType != 'application/json') {
        throw const NativeHttpAuthFailure();
      }
      final data = <int>[];
      await for (final chunk in response.stream.timeout(streamIdleTimeout)) {
        if (chunk.length > maxResponseBytes - data.length) {
          throw const NativeHttpAuthFailure();
        }
        data.addAll(chunk);
      }
      final decoded = jsonDecode(utf8.decode(data));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      throw const NativeHttpAuthFailure();
    }
    throw const NativeHttpAuthFailure();
  }

  NativeIssuedTokens _tokens(Map<String, dynamic> body) {
    final a = body['access'];
    final r = body['refresh'];
    if (body.length != 3 ||
        body['status'] != 'authenticated' ||
        a is! String || r is! String ||
        !NativeMobileTokenShape.accepts(a, kind: 'a') ||
        !NativeMobileTokenShape.accepts(r, kind: 'r')) {
      throw const NativeHttpAuthFailure();
    }
    return NativeIssuedTokens(access: a, refresh: r);
  }

  @override
  Future<NativePasswordResponse> password({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || username.length > 150 ||
        password.isEmpty || password.length > 4096) {
      throw const NativeHttpAuthFailure();
    }
    final body = await _post('/api/v1/mobile/auth/password/', {
      'username': username,
      'password': password,
    });
    if (body['status'] == 'mfa_required' &&
        body.length == 2 && body['challenge'] is String) {
      // The coordinator independently checks the challenge's full shape.
      return NativePasswordMfaRequired(body['challenge'] as String);
    }
    return NativePasswordGranted(_tokens(body));
  }

  /// Full reauthentication after an ambiguous token response.
  /// The future server MUST revoke existing sessions atomically only after
  /// the account's entire password/MFA challenge has succeeded. Test-only.
  Future<NativePasswordResponse> recoverPassword({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || username.length > 150 ||
        password.isEmpty || password.length > 4096) {
      throw const NativeHttpAuthFailure();
    }
    final body = await _post('/api/v1/mobile/auth/recover/password/', {
      'username': username, 'password': password,
    });
    if (body['status'] == 'mfa_required' &&
        body.length == 2 && body['challenge'] is String) {
      return NativePasswordMfaRequired(body['challenge'] as String);
    }
    return NativePasswordGranted(_tokens(body));
  }

  Future<NativeIssuedTokens> recoverMfa({
    required String challenge,
    required String code,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code) ||
        challenge.length > 256) {
      throw const NativeHttpAuthFailure();
    }
    return _tokens(await _post('/api/v1/mobile/auth/recover/mfa/', {
      'challenge': challenge, 'code': code,
    }));
  }

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge,
    required String code,
  }) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code) ||
        challenge.length > 256) {
      throw const NativeHttpAuthFailure();
    }
    return _tokens(await _post('/api/v1/mobile/auth/mfa/', {
      'challenge': challenge, 'code': code,
    }));
  }

  /// Stateless refresh exchange only: coordinating process crashes and
  /// protected storage replacement is explicitly NOT implemented here.
  Future<NativeIssuedTokens> rotateRefresh(String refresh) async {
    if (!NativeMobileTokenShape.accepts(refresh, kind: 'r')) {
      throw const NativeHttpAuthFailure();
    }
    final next = _tokens(await _post('/api/v1/mobile/token/refresh/', {
      'refresh': refresh,
    }));
    if (next.refresh == refresh) {
      throw const NativeHttpAuthFailure();
    }
    return next;
  }

  @override
  Future<void> revoke({required String refresh}) async {
    if (!NativeMobileTokenShape.accepts(refresh, kind: 'r')) {
      throw const NativeHttpAuthFailure();
    }
    final body = await _post('/api/v1/mobile/token/revoke/', {
      'refresh': refresh,
    });
    if (body.length != 1 || body['status'] != 'revoked') {
      throw const NativeHttpAuthFailure();
    }
  }
}

class NativeHttpAuthFailure implements Exception {
  const NativeHttpAuthFailure();
}
