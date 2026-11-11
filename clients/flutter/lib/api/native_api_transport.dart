import 'dart:convert';

import 'package:http/http.dart' as http;

import 'native_api_endpoint.dart';
import 'native_session_fence.dart';
import 'native_mobile_token_shape.dart';

/// A transport primitive for a FUTURE, separately authorised Android/iOS
/// session. Not connected to the app until the backend MFA/token contract is
/// approved. Web sessions continue to use HttpVenciraApi.
class NativeApiTransport {
  NativeApiTransport({
    required this.endpoint,
    required this.client,
    required this.accessToken,
    required this.sessionFence,
    this.connectTimeout = const Duration(seconds: 15),
    this.streamIdleTimeout = const Duration(seconds: 15),
  });

  final NativeApiEndpoint endpoint;
  final http.Client client;
  final NativeSessionFence sessionFence;
  /// Per-request time limits prevent a disconnected mobile transport from
  /// keeping stale requests open indefinitely.
  final Duration connectTimeout;
  final Duration streamIdleTimeout;

  /// Supplied by the future secure mobile session controller, never by
  /// SharedPreferences or a compile-time secret.
  final Future<String?> Function() accessToken;

  static const int maxResponseBytes = 1024 * 1024;
  Future<Object> getJson(String path, {Map<String, String> query = const {}}) async {
    // Validate the canonical path first. Query strings are never accepted in
    // paths; only the explicitly supported workspace-page offset can be added.
    final base = endpoint.resolveApiPath(path);
    if (query.isNotEmpty &&
        (query.length != 1 || !query.containsKey('offset') ||
         !RegExp(r'^(0|[1-9][0-9]{0,4})
    final ticket = sessionFence.ticket;
    if (ticket == null) throw const NativeApiSessionUnavailable();
    final String? token;
    try {
      token = await accessToken();
    } catch (_) {
      throw const NativeApiSessionUnavailable();
    }
    if (!sessionFence.accepts(ticket) || token == null ||
        !NativeMobileTokenShape.accepts(token, kind: 'a')) {
      throw const NativeApiSessionUnavailable();
    }

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    late http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(connectTimeout);
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
      await for (final chunk in response.stream.timeout(streamIdleTimeout)) {
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
).hasMatch(query['offset']!) ||
         int.parse(query['offset']!) > 10000 ||
         int.parse(query['offset']!) % 50 != 0 ||
         !RegExp(r'^/api/v1/mobile/workspaces/[0-9a-f-]{36}/renewals/
    final ticket = sessionFence.ticket;
    if (ticket == null) throw const NativeApiSessionUnavailable();
    final String? token;
    try {
      token = await accessToken();
    } catch (_) {
      throw const NativeApiSessionUnavailable();
    }
    if (!sessionFence.accepts(ticket) || token == null ||
        !NativeMobileTokenShape.accepts(token, kind: 'a')) {
      throw const NativeApiSessionUnavailable();
    }

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    late http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(connectTimeout);
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
      await for (final chunk in response.stream.timeout(streamIdleTimeout)) {
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
)
             .hasMatch(base.path))) {
      throw const FormatException('Invalid API query');
    }
    final uri = query.isEmpty ? base : base.replace(queryParameters: query);
    final ticket = sessionFence.ticket;
    if (ticket == null) throw const NativeApiSessionUnavailable();
    final String? token;
    try {
      token = await accessToken();
    } catch (_) {
      throw const NativeApiSessionUnavailable();
    }
    if (!sessionFence.accepts(ticket) || token == null ||
        !NativeMobileTokenShape.accepts(token, kind: 'a')) {
      throw const NativeApiSessionUnavailable();
    }

    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..maxRedirects = 0
      ..headers['Accept'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $token';
    late http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(connectTimeout);
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
      await for (final chunk in response.stream.timeout(streamIdleTimeout)) {
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
