import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'dart:async';

class IdleNativeStreamClient extends http.BaseClient {
  final StreamController<List<int>> controller =
      StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(controller.stream, 200,
          headers: {'content-type': 'application/json'});

  @override
  void close() {
    controller.close();
  }
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  final testToken = 'v1.a.0123456789abcdef0123456789abcdef.'
      '${List<String>.filled(43, 'A').join()}';
  late NativeSessionFence fence;
  setUp(() => fence = NativeSessionFence()..activate());

  test('GET carries bearer credentials only to approved HTTPS API', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.toString(), 'https://dev.vencira.es/api/v1/me/');
      expect(request.method, 'GET');
      expect(request.headers['Authorization'], 'Bearer $testToken');
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      return http.Response('{"id":12}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final transport = NativeApiTransport(
      endpoint: endpoint, client: client, sessionFence: fence, accessToken: () async => testToken);
    expect(await transport.getJson('/api/v1/me/'), {'id': 12});
    expect(calls, 1);
    client.close();
  });

  test('rejects absent, invalid and failed credentials without sending', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final corrupted = '${testToken.substring(0, testToken.length - 1)}B';
    final refresh = testToken.replaceFirst('v1.a.', 'v1.r.');
    for (final token in <String?>[
      null, '', 'abc', 'unsafe header\r\n', refresh, corrupted,
    ]) {
      final transport = NativeApiTransport(
          endpoint: endpoint, client: client, sessionFence: fence, accessToken: () async => token);
      await expectLater(transport.getJson('/api/v1/me/'),
          throwsA(isA<NativeApiSessionUnavailable>()));
    }
    final failing = NativeApiTransport(
        endpoint: endpoint, client: client, sessionFence: fence,
        accessToken: () async => throw StateError('not unlocked'));
    await expectLater(failing.getJson('/api/v1/me/'),
        throwsA(isA<NativeApiSessionUnavailable>()));
    expect(calls, 0);
    client.close();
  });

  test('invalid path is rejected before reading credentials', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final transport = NativeApiTransport(
        endpoint: endpoint, client: client, sessionFence: fence,
        accessToken: () async {
          calls++;
          return testToken;
        });
    await expectLater(transport.getJson('/accounts/login/'),
        throwsFormatException);
    expect(calls, 0);
    client.close();
  });

  test('never follows redirects carrying bearer credentials', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.followRedirects, false);
      return http.Response('', 302,
          headers: {'location': 'https://evil.example/steal'});
    });
    final transport = NativeApiTransport(
        endpoint: endpoint, client: client, sessionFence: fence, accessToken: () async => testToken);
    await expectLater(transport.getJson('/api/v1/me/'),
        throwsA(isA<NativeApiTransportFailure>()));
    expect(calls, 1);
    client.close();
  });

  test('401 is session unavailable; 403 is not assumed to be logout', () async {
    for (final status in [401, 403]) {
      final caseFence = NativeSessionFence()..activate();
      final client = MockClient((request) async => http.Response('', status));
      final transport = NativeApiTransport(
          endpoint: endpoint, client: client, sessionFence: caseFence,
          accessToken: () async => testToken);
      await expectLater(transport.getJson('/api/v1/me/'),
          throwsA(status == 401
              ? isA<NativeApiSessionUnavailable>()
              : isA<NativeApiTransportFailure>()));
      expect(caseFence.ticket == null, status == 401);
      client.close();
    }
  });

  test('HTML and unbounded responses fail closed', () async {
    for (final response in [
      http.Response('<html/>', 200,
          headers: {'content-type': 'text/html'}),
      http.Response(List<String>.filled(NativeApiTransport.maxResponseBytes + 1, 'x').join(), 200,
          headers: {'content-type': 'application/json'}),
      http.Response('not-json', 200,
          headers: {'content-type': 'application/json'}),
    ]) {
      final client = MockClient((request) async => response);
      final transport = NativeApiTransport(
          endpoint: endpoint, client: client, sessionFence: fence, accessToken: () async => testToken);
      await expectLater(transport.getJson('/api/v1/me/'),
          throwsA(isA<NativeApiTransportFailure>()));
      client.close();
    }
  });
  test('a stalled HTTP send has a finite timeout', () async {
    final pending = Completer<http.Response>();
    final client = MockClient((request) => pending.future);
    final transport = NativeApiTransport(
      endpoint: endpoint, client: client, sessionFence: fence,
      accessToken: () async => testToken,
      connectTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(transport.getJson('/api/v1/me/'),
        throwsA(isA<NativeApiTransportFailure>()));
    pending.complete(http.Response('{}', 200,
        headers: {'content-type': 'application/json'}));
    client.close();
  });

  test('an idle JSON response stream has a finite timeout', () async {
    final client = IdleNativeStreamClient();
    final transport = NativeApiTransport(
      endpoint: endpoint, client: client, sessionFence: fence,
      accessToken: () async => testToken,
      streamIdleTimeout: const Duration(milliseconds: 20),
    );
    await expectLater(transport.getJson('/api/v1/me/'),
        throwsA(isA<NativeApiTransportFailure>()));
    client.close();
  });

  test('late reply after logout is rejected even if server returns 200',
      () async {
    final pending = Completer<http.Response>();
    var requests = 0;
    final client = MockClient((request) {
      requests++;
      return pending.future;
    });
    final transport = NativeApiTransport(
        endpoint: endpoint, client: client, sessionFence: fence,
        accessToken: () async => testToken);
    final request = transport.getJson('/api/v1/me/');
    await Future<void>.delayed(Duration.zero);
    expect(requests, 1);
    fence.revoke();
    pending.complete(http.Response('{"id":12}', 200,
        headers: {'content-type': 'application/json'}));
    await expectLater(request, throwsA(isA<NativeApiSessionUnavailable>()));
    client.close();
  });

  test('new account generation cannot receive prior account response',
      () async {
    final pending = Completer<http.Response>();
    final client = MockClient((request) => pending.future);
    final transport = NativeApiTransport(
        endpoint: endpoint, client: client, sessionFence: fence,
        accessToken: () async => testToken);
    final previous = transport.getJson('/api/v1/me/');
    await Future<void>.delayed(Duration.zero);
    fence.revoke();
    fence.activate();
    pending.complete(http.Response('{"id":12}', 200,
        headers: {'content-type': 'application/json'}));
    await expectLater(previous, throwsA(isA<NativeApiSessionUnavailable>()));
    expect(fence.ticket, isNotNull);
    client.close();
  });

  test('session cannot read credentials after local revocation',
      () async {
    var tokenReads = 0;
    var networkCalls = 0;
    final client = MockClient((request) async {
      networkCalls++;
      return http.Response('{}', 200);
    });
    fence.revoke();
    final transport = NativeApiTransport(
      endpoint: endpoint, client: client, sessionFence: fence,
      accessToken: () async { tokenReads++; return testToken; });
    await expectLater(transport.getJson('/api/v1/me/'),
        throwsA(isA<NativeApiSessionUnavailable>()));
    expect(tokenReads, 0);
    expect(networkCalls, 0);
    client.close();
  });
}
