import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/api/native_workspace_cursor_read_port.dart';
import 'package:vencira/api/native_workspace_read_port.dart';

const ws = '12345678-1234-1234-1234-123456789abc';
const rid = 'abcdef12-abcd-abcd-abcd-abcdef123456';
const access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const signed = 'eJw.test:sig123456789abcdef';

NativeWorkspaceCursorReadPort reader(http.Client client,
    NativeSessionFence fence) => NativeWorkspaceCursorReadPort(
  NativeApiTransport(
    endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
    client: client, sessionFence: fence, accessToken: () async => access,
  ),
);

Map<String, Object?> payload({int count = 50, String? next = signed}) => {
  'workspace_id': ws,
  'results': List.generate(count, (_) =>
      {'id': rid, 'expires_on': '2030-04-03', 'status': 'pending'}),
  'next_cursor': next,
};

void main() {
  test('canonical signed cursor goes to typed HTTPS query only', () async {
    final fence = NativeSessionFence()..activate();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.url.scheme, 'https');
      expect(request.url.host, 'dev.vencira.es');
      expect(request.url.path,
          '/api/v1/mobile/workspaces/$ws/renewals/cursor/');
      expect(request.headers['Authorization'], 'Bearer $access');
      expect(request.followRedirects, false);
      if (calls == 1) {
        expect(request.url.hasQuery, false);
        return http.Response(jsonEncode(payload()), 200,
            headers: {'content-type': 'application/json'});
      }
      expect(request.url.queryParameters, {'cursor': signed});
      return http.Response(jsonEncode(payload(count: 25, next: null)), 200,
          headers: {'content-type': 'application/json'});
    });
    final port = reader(client, fence);
    final first = await port.loadPage(ws);
    expect(first.results, hasLength(50));
    expect(first.nextCursor, signed);
    final second = await port.loadPage(ws, cursor: first.nextCursor);
    expect(second.results, hasLength(25));
    expect(second.nextCursor, isNull);
    expect(calls, 2);
    expect(() => second.results.clear(), throwsUnsupportedError);
    client.close();
  });

  test('reject forged cursor and workspace without accessing network', () async {
    final fence = NativeSessionFence()..activate();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final port = reader(client, fence);
    for (final cursor in ['', 'x', 'unsafe&other=true', 'x' * 1025]) {
      await expectLater(port.loadPage(ws, cursor: cursor),
          throwsA(isA<NativeWorkspacePayloadInvalid>()));
    }
    await expectLater(port.loadPage('../foreign'),
        throwsA(isA<NativeWorkspacePayloadInvalid>()));
    expect(calls, 0);
    client.close();
  });

  test('unexpected PII and malformed next cursor fail closed', () async {
    for (final body in [
      {...payload(count: 1, next: null), 'results': [
        {'id': rid, 'expires_on': '2030-04-03', 'status': 'pending',
         'full_name': 'PII forbidden'},
      ]},
      payload(count: 1, next: signed),
      payload(count: 51, next: null),
      {...payload(count: 1, next: null), 'next_cursor': 'unsafe?a=1'},
    ]) {
      final fence = NativeSessionFence()..activate();
      final client = MockClient((request) async => http.Response(
        jsonEncode(body), 200, headers: {'content-type': 'application/json'},
      ));
      await expectLater(reader(client, fence).loadPage(ws),
          throwsA(isA<NativeWorkspacePayloadInvalid>()));
      client.close();
    }
  });
}
