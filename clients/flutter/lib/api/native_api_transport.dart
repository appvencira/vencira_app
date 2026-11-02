import 'dart:convert';

import 'package:http/http.dart' as http;

import 'native_api_endpoint.dart';
import 'native_session_fence.dart';

/// A transport primitive for a FUTURE, separately authorised Android/iOS
/// session. Not connected to the app until the backend MFA/token contract is
/// approved. Web sessions continue to use HttpVenciraApi.
class NativeApiTransport {
  NativeApiTransport({
    required this.endpoint,
    required this.client,
    required this.accessToken,
    required this.sessionFence,
  });

  final NativeApiEndpoint endpoint;
  final http.Client client;
  final NativeSessionFence sessionFence;

  /// Supplied by the future secure mobile session controller, never by
  /// SharedPreferences or a compile-time secret.
  final Future<String?> Function() accessToken;

  static const int maxResponseBytes = 1024 * 1024;
  // Do not accidentally use a refresh credential as a request access token.
  // This canonical v1.a format matches Django's isolated N1 token contract.
  static final RegExp _accessTokenShape =
      RegExp(r'^v1\\.a\\.[0-9a-f]{32}\\.([A-Za-z0-9_-]{43})
  Future<Object> getJson(String path) async {
    // Validate both path and active session before reading credentials.
    final uri = endpoint.resolveApiPath(path);
    final ticket = sessionFence.ticket;
    if (ticket == null) throw const NativeApiSessionUnavailable();
    final String? token;
    try {
      token = await accessToken();
    } catch (_) {
      throw const NativeApiSessionUnavailable();
    }
    if (!sessionFence.accepts(ticket) || token == null ||
        !_validAccessToken(token)) {
      throw const NativeApiSessionUnavailable();
    }

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    late http.StreamedResponse response;
    try {
      response = await client.send(request);
    } catch (_) {
      throw const NativeApiTransportFailure();
    }
    if (!sessionFence.accepts(ticket)) {
      throw const NativeApiSessionUnavailable();
    }
    if (response.statusCode == 401) {
      // Only revoke the generation which actually sent this request.
      if (sessionFence.accepts(ticket)) sessionFence.revoke();
      throw const NativeApiSessionUnavailable();
    }
    // Never follow login redirects or an unapproved destination with a token.
    if (response.statusCode != 200) {
      throw const NativeApiTransportFailure();
    }
    final contentType = response.headers['content-type'] ?? '';
    final mediaType = contentType.toLowerCase().split(';').first.trim();
    if (mediaType != 'application/json' && !mediaType.endsWith('+json')) {
      throw const NativeApiTransportFailure();
    }
    final bytes = <int>[];
    try {
      await for (final chunk in response.stream) {
        if (chunk.length > maxResponseBytes - bytes.length) {
          throw const NativeApiTransportFailure();
        }
        bytes.addAll(chunk);
      }
      final result = jsonDecode(utf8.decode(bytes));
      if (!sessionFence.accepts(ticket)) {
        throw const NativeApiSessionUnavailable();
      }
      if (result is Map<String, dynamic> || result is List<dynamic>) {
        return result;
      }
    } on NativeApiSessionUnavailable {
      rethrow;
    } on NativeApiTransportFailure {
      rethrow;
    } catch (_) {
      throw const NativeApiTransportFailure();
    }
    throw const NativeApiTransportFailure();
  }
}

class NativeApiSessionUnavailable implements Exception {
  const NativeApiSessionUnavailable();
}

class NativeApiTransportFailure implements Exception {
  const NativeApiTransportFailure();
}
);

  static bool _validAccessToken(String token) {
    final match = _accessTokenShape.firstMatch(token);
    if (match == null) return false;
    final encoded = match.group(1)!;
    try {
      final raw = base64Url.decode('$encoded=');
      return raw.length == 32 &&
          base64UrlEncode(raw).replaceAll('=', '') == encoded;
    } on FormatException {
      return false;
    }
  }

  Future<Object> getJson(String path) async {
    // Validate both path and active session before reading credentials.
    final uri = endpoint.resolveApiPath(path);
    final ticket = sessionFence.ticket;
    if (ticket == null) throw const NativeApiSessionUnavailable();
    final String? token;
    try {
      token = await accessToken();
    } catch (_) {
      throw const NativeApiSessionUnavailable();
    }
    if (!sessionFence.accepts(ticket) || token == null ||
        token.length < 16 ||
        token.length > 4096 ||
        !_tokenCharacters.hasMatch(token)) {
      throw const NativeApiSessionUnavailable();
    }

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    late http.StreamedResponse response;
    try {
      response = await client.send(request);
    } catch (_) {
      throw const NativeApiTransportFailure();
    }
    if (!sessionFence.accepts(ticket)) {
      throw const NativeApiSessionUnavailable();
    }
    if (response.statusCode == 401) {
      // Only revoke the generation which actually sent this request.
      if (sessionFence.accepts(ticket)) sessionFence.revoke();
      throw const NativeApiSessionUnavailable();
    }
    // Never follow login redirects or an unapproved destination with a token.
    if (response.statusCode != 200) {
      throw const NativeApiTransportFailure();
    }
    final contentType = response.headers['content-type'] ?? '';
    final mediaType = contentType.toLowerCase().split(';').first.trim();
    if (mediaType != 'application/json' && !mediaType.endsWith('+json')) {
      throw const NativeApiTransportFailure();
    }
    final bytes = <int>[];
    try {
      await for (final chunk in response.stream) {
        if (chunk.length > maxResponseBytes - bytes.length) {
          throw const NativeApiTransportFailure();
        }
        bytes.addAll(chunk);
      }
      final result = jsonDecode(utf8.decode(bytes));
      if (!sessionFence.accepts(ticket)) {
        throw const NativeApiSessionUnavailable();
      }
      if (result is Map<String, dynamic> || result is List<dynamic>) {
        return result;
      }
    } on NativeApiSessionUnavailable {
      rethrow;
    } on NativeApiTransportFailure {
      rethrow;
    } catch (_) {
      throw const NativeApiTransportFailure();
    }
    throw const NativeApiTransportFailure();
  }
}

class NativeApiSessionUnavailable implements Exception {
  const NativeApiSessionUnavailable();
}

class NativeApiTransportFailure implements Exception {
  const NativeApiTransportFailure();
}
