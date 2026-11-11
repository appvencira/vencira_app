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
    // Never allow a query delimiter in an untrusted raw path.
    final base = endpoint.resolveApiPath(path);
    if (query.isNotEmpty) {
      if (query.length != 1) throw const FormatException('Invalid API query');
      final workspacePrefix = '/api/v1/mobile/workspaces/';
      final validWorkspacePath = base.path.startsWith(workspacePrefix) &&
          base.path.length >= workspacePrefix.length + 36 &&
          RegExp(r'^[0-9a-f-]{36}').hasMatch(
            base.path.substring(workspacePrefix.length),
          );
      if (!validWorkspacePath) {
        throw const FormatException('Invalid API query path');
      }
      if (query.containsKey('offset') &&
          base.path.endsWith('/renewals/')) {
        final rawOffset = query['offset']!;
        if (rawOffset.isEmpty || rawOffset.length > 5 ||
            rawOffset.codeUnits.any((c) => c < 48 || c > 57) ||
            (rawOffset.length > 1 && rawOffset.startsWith('0')) ||
            base.path.length != workspacePrefix.length + 36 + '/renewals/'.length) {
          throw const FormatException('Invalid API offset');
        }
        final offset = int.tryParse(rawOffset);
        if (offset == null || offset > 10000 || offset % 50 != 0) {
          throw const FormatException('Invalid API offset');
        }
      } else if (query.containsKey('cursor') &&
          base.path.endsWith('/renewals/cursor/')) {
        final cursor = query['cursor']!;
        if (base.path.length != workspacePrefix.length + 36 +
                '/renewals/cursor/'.length ||
            cursor.length < 10 || cursor.length > 1024 ||
            cursor.codeUnits.any((c) => !((c >= 48 && c <= 57) ||
                (c >= 65 && c <= 90) || (c >= 97 && c <= 122) ||
                c == 45 || c == 95 || c == 58 || c == 46))) {
          throw const FormatException('Invalid API cursor');
        }
      } else {
        throw const FormatException('Invalid API query');
      }
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
      if (sessionFence.accepts(ticket)) sessionFence.revoke();
      throw const NativeApiSessionUnavailable();
    }
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
