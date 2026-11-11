import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/api/native_workspace_read_port.dart';

const workspace = '12345678-1234-1234-1234-123456789abc';
const renewal = 'abcdef12-abcd-abcd-abcd-abcdef123456';
const access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

http.Response reply(Object body, {int status = 200}) => http.Response(
  jsonEncode(body), status, headers: {'content-type': 'application/json'},
);

Object response({String workspaceId = workspace}) => {
  'workspace_id': workspaceId,
  'next_offset': null,
  'results': [
    {'id': renewal, 'expires_on': '2030-04-03', 'status': 'pending'},
  ],
};

NativeWorkspaceReadPort port(http.Client client, NativeSessionFence fence) =>
    NativeWorkspaceReadPort(NativeApiTransport(
      endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
      client: client, sessionFence: fence, accessToken: () async => access,
    ));

void main() {
  test('scoped GET uses Bearer and parses only safe fields', () async {
    final fence = NativeSessionFence()..activate();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(),
          'https://dev.vencira.es/api/v1/mobile/workspaces/'
          '$workspace/renewals/');
      expect(request.headers['Authorization'], 'Bearer $access');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Cookie'], isNull);
      return reply(response());
    });
    final records = await port(client, fence).load(workspace);
    expect(records, hasLength(1));
    expect(records.single.id, renewal);
    expect(records.single.expiresOn, '2030-04-03');
    expect(records.single.status, 'pending');
    expect(() => records.clear(), throwsUnsupportedError);
    client.close();
  });

  test('page two uses canonical offset and validates next_offset', () async {
    final fence = NativeSessionFence()..activate();
    final client = MockClient((request) async {
      expect(request.url.queryParameters['offset'], '50');
      return reply({
        'workspace_id': workspace,
        'results': [
          {'id': renewal, 'expires_on': '2030-04-03', 'status': 'pending'},
        ],
        'next_offset': null,
      });
    });
    final page = await port(client, fence).loadPage(workspace, offset: 50);
    expect(page.results, hasLength(1));
    expect(page.nextOffset, isNull);
    client.close();
  });

  test('invalid offsets and forged next offsets fail closed', () async {
    final fence = NativeSessionFence()..activate();
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return reply({
        ...response() as Map<String, dynamic>,
        'next_offset': 100,
      });
    });
    for (final offset in [-50, 1, 49, 10050]) {
      await expectLater(port(client, fence).loadPage(workspace, offset: offset),
          throwsA(isA<NativeWorkspacePayloadInvalid>()));
    }
    expect(calls, 0);
    await expectLater(port(client, fence).loadPage(workspace),
        throwsA(isA<NativeWorkspacePayloadInvalid>()));
    client.close();
  });

  test('invalid workspace IDs cannot even reach HTTP', () async {
    final fence = NativeSessionFence()..activate();
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return reply(response());
    });
    for (final invalid in [
      '', 'not-a-uuid', '../admin', workspace.toUpperCase(),
      '$workspace?limit=1000',
    ]) {
      await expectLater(
        port(client, fence).load(invalid),
        throwsA(isA<NativeWorkspacePayloadInvalid>()),
      );
    }
    expect(calls, 0);
    client.close();
  });

  test('foreign workspace 404 does not close the current user session',
      () async {
    final fence = NativeSessionFence()..activate();
    final client = MockClient((_) async => reply(
      {'error': 'native_auth_unavailable'}, status: 404,
    ));
    await expectLater(
      port(client, fence).load(workspace),
      throwsA(isA<NativeApiTransportFailure>()),
    );
    expect(fence.ticket, isNotNull);
    client.close();
  });

  test('expired or revoked Bearer 401 closes session fence', () async {
    final fence = NativeSessionFence()..activate();
    final client = MockClient((_) async => reply(
      {'error': 'native_auth_unavailable'}, status: 401,
    ));
    await expectLater(
      port(client, fence).load(workspace),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(fence.ticket, isNull);
    client.close();
  });

  test('cross-workspace response is rejected, not rendered', () async {
    final fence = NativeSessionFence()..activate();
    final client = MockClient((_) async => reply(response(
      workspaceId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    )));
    await expectLater(
      port(client, fence).load(workspace),
      throwsA(isA<NativeWorkspacePayloadInvalid>()),
    );
    client.close();
  });

  test('unexpected customer PII in response is rejected', () async {
    final fence = NativeSessionFence()..activate();
    final body = {
      'workspace_id': workspace,
      'next_offset': null,
      'results': [
        {'id': renewal, 'expires_on': '2030-04-03',
          'status': 'pending', 'customer_reference': 'secret'},
      ],
    };
    final client = MockClient((_) async => reply(body));
    await expectLater(
      port(client, fence).load(workspace),
      throwsA(isA<NativeWorkspacePayloadInvalid>()),
    );
    client.close();
  });

  test('invalid date, state and oversized list all fail closed', () async {
    for (final body in [
      {'workspace_id': workspace, 'next_offset': null, 'results': [
        {'id': renewal, 'expires_on': '2030-02-30', 'status': 'pending'},
      ]},
      {'workspace_id': workspace, 'next_offset': null, 'results': [
        {'id': renewal, 'expires_on': '2030-04-03', 'status': 'unknown'},
      ]},
      {'workspace_id': workspace, 'results': List.generate(
        51, (_) => {
          'id': renewal, 'expires_on': '2030-04-03', 'status': 'pending',
        },
      )},
    ]) {
      final fence = NativeSessionFence()..activate();
      final client = MockClient((_) async => reply(body));
      await expectLater(
        port(client, fence).load(workspace),
        throwsA(isA<NativeWorkspacePayloadInvalid>()),
      );
      client.close();
    }
  });
}
