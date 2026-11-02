import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_session_coordinator.dart';

const access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const rotatedRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE';
const challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');

http.Response jsonReply(Object data, {int status = 200}) =>
    http.Response(jsonEncode(data), status,
        headers: {'content-type': 'application/json'});

class NeverFinishingHttpClient extends http.BaseClient {
  final stream = StreamController<List<int>>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(stream.stream, 200,
          headers: {'content-type': 'application/json'});

  @override
  void close() {
    stream.close();
  }
}

void main() {
  test('password request uses only approved HTTPS native JSON endpoint',
      () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.toString(),
          'https://dev.vencira.es/api/v1/mobile/auth/password/');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], isNull);
      expect(request.headers['Cookie'], isNull);
      expect(request.headers['Origin'], isNull);
      expect(jsonDecode(request.body), {
        'username': 'agent', 'password': 'synthetic-only',
      });
      return jsonReply({
        'status': 'authenticated', 'access': access, 'refresh': refresh,
      });
    });
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    final result = await port.password(
      username: 'agent', password: 'synthetic-only',
    );
    expect(result, isA<NativePasswordGranted>());
    expect((result as NativePasswordGranted).tokens.access, access);
    client.close();
  });

  test('MFA challenge response never contains issued credentials', () async {
    final client = MockClient((_) async => jsonReply({
      'status': 'mfa_required', 'challenge': challenge,
    }));
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    final result = await port.password(username: 'a', password: 'b');
    expect(result, isA<NativePasswordMfaRequired>());
    expect((result as NativePasswordMfaRequired).challenge, challenge);
    client.close();
  });

  test('TOTP completion requires canonical grant and correct POST body',
      () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/mobile/auth/mfa/');
      expect(jsonDecode(request.body), {
        'challenge': challenge, 'code': '123456',
      });
      return jsonReply({
        'status': 'authenticated', 'access': access, 'refresh': refresh,
      });
    });
    final tokens = await NativeHttpAuthPort(
      endpoint: endpoint, client: client,
    ).mfa(challenge: challenge, code: '123456');
    expect(tokens.refresh, refresh);
    client.close();
  });

  test('refresh exchanges only a canonical refresh credential', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/mobile/token/refresh/');
      expect(jsonDecode(request.body), {'refresh': refresh});
      return jsonReply({
        'status': 'authenticated', 'access': access, 'refresh': rotatedRefresh,
      });
    });
    final tokens = await NativeHttpAuthPort(
      endpoint: endpoint, client: client,
    ).rotateRefresh(refresh);
    expect(tokens.access, access);
    expect(tokens.refresh, rotatedRefresh);
    client.close();
  });

  test('access credential cannot be used as a refresh', () async {
    var sent = false;
    final client = MockClient((_) async {
      sent = true;
      return jsonReply({'status': 'error'});
    });
    await expectLater(
      NativeHttpAuthPort(endpoint: endpoint, client: client)
          .rotateRefresh(access),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    expect(sent, isFalse);
    client.close();
  });

  test('refresh replay response without rotation is rejected', () async {
    final client = MockClient((_) async => jsonReply({
      'status': 'authenticated', 'access': access, 'refresh': refresh,
    }));
    await expectLater(
      NativeHttpAuthPort(endpoint: endpoint, client: client)
          .rotateRefresh(refresh),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    client.close();
  });

  test('G6 recovery password uses distinct no-retry endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/mobile/auth/recover/password/');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Authorization'], isNull);
      expect(request.headers['Cookie'], isNull);
      expect(jsonDecode(request.body), {
        'username': 'agent', 'password': 'synthetic-new-auth',
      });
      return jsonReply({
        'status': 'mfa_required', 'challenge': challenge,
      });
    });
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    final result = await port.recoverPassword(
      username: 'agent', password: 'synthetic-new-auth',
    );
    expect(result, isA<NativePasswordMfaRequired>());
    client.close();
  });

  test('G6 recovery MFA uses distinct endpoint and canonical grant', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/mobile/auth/recover/mfa/');
      expect(jsonDecode(request.body), {
        'challenge': challenge, 'code': '123456',
      });
      return jsonReply({
        'status': 'authenticated', 'access': access,
        'refresh': rotatedRefresh,
      });
    });
    final tokens = await NativeHttpAuthPort(
      endpoint: endpoint, client: client,
    ).recoverMfa(challenge: challenge, code: '123456');
    expect(tokens.refresh, rotatedRefresh);
    client.close();
  });

  test('G6 invalid recovery input cannot send a network request', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return jsonReply({'status': 'authenticated'});
    });
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    await expectLater(
      port.recoverPassword(username: 'a', password: ''),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    await expectLater(
      port.recoverMfa(challenge: challenge, code: 'invalid'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    expect(requests, 0);
    client.close();
  });

  test('device revocation requires server acknowledgement', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/mobile/token/revoke/');
      expect(jsonDecode(request.body), {'refresh': refresh});
      return jsonReply({'status': 'revoked'});
    });
    await NativeHttpAuthPort(
      endpoint: endpoint, client: client,
    ).revoke(refresh: refresh);
    client.close();
  });

  test('non-200, redirects, and HTML fail closed', () async {
    for (final response in <http.Response>[
      jsonReply({'error': 'denied'}, status: 401),
      http.Response('', 302, headers: {'location': 'https://fake.example'}),
      http.Response('<html>Login</html>', 200,
          headers: {'content-type': 'text/html'}),
    ]) {
      final client = MockClient((_) async => response);
      await expectLater(
        NativeHttpAuthPort(
          endpoint: endpoint, client: client,
        ).password(username: 'a', password: 'b'),
        throwsA(isA<NativeHttpAuthFailure>()),
      );
      client.close();
    }
  });

  test('cookie-bearing response is never accepted', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode({
        'status': 'authenticated', 'access': access, 'refresh': refresh,
      }),
      200,
      headers: {
        'content-type': 'application/json',
        'set-cookie': 'vencira_sessionid=not-a-native-token',
      },
    ));
    await expectLater(
      NativeHttpAuthPort(endpoint: endpoint, client: client)
          .password(username: 'a', password: 'b'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    client.close();
  });

  test('rejects invalid token kinds and extra grant fields', () async {
    for (final body in [
      {
        'status': 'authenticated', 'access': refresh,
        'refresh': access,
      },
      {
        'status': 'authenticated', 'access': access,
        'refresh': refresh, 'debug': 'not allowed',
      },
      {
        'status': 'authenticated', 'access': 'malformed',
        'refresh': refresh,
      },
    ]) {
      final client = MockClient((_) async => jsonReply(body));
      await expectLater(
        NativeHttpAuthPort(endpoint: endpoint, client: client)
            .password(username: 'a', password: 'b'),
        throwsA(isA<NativeHttpAuthFailure>()),
      );
      client.close();
    }
  });

  test('malformed TOTP and refresh rejected before network', () async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return jsonReply({'status': 'revoked'});
    });
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    await expectLater(
      port.mfa(challenge: challenge, code: 'abcd'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    await expectLater(
      port.revoke(refresh: access),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    await expectLater(
      port.password(username: 'a', password: 'A' * 5000),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    expect(requests, 0);
    client.close();
  });

  test('oversized JSON response rejected before parsing', () async {
    final client = MockClient((_) async => http.Response(
      jsonEncode({'status': 'mfa_required', 'challenge': 'A' * 8500}),
      200, headers: {'content-type': 'application/json'},
    ));
    await expectLater(
      NativeHttpAuthPort(endpoint: endpoint, client: client)
          .password(username: 'a', password: 'b'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    client.close();
  });

  test('stalled network response fails after connect timeout', () async {
    final waiting = Completer<http.Response>();
    final client = MockClient((_) => waiting.future);
    await expectLater(
      NativeHttpAuthPort(
        endpoint: endpoint, client: client,
        connectTimeout: const Duration(milliseconds: 20),
      ).password(username: 'a', password: 'b'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    waiting.complete(jsonReply({'status': 'error'}));
    client.close();
  });

  test('idle streaming reply fails after stream timeout', () async {
    final client = NeverFinishingHttpClient();
    await expectLater(
      NativeHttpAuthPort(
        endpoint: endpoint, client: client,
        streamIdleTimeout: const Duration(milliseconds: 20),
      ).password(username: 'a', password: 'b'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    client.close();
  });
}
