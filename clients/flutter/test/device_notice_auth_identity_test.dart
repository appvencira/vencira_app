import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/vencira_api.dart';

HttpVenciraApi serverReply(Object payload, {int status = 200,
    void Function(http.Request)? validate}) =>
    HttpVenciraApi(
      client: MockClient((request) async {
        validate?.call(request);
        return http.Response(jsonEncode(payload), status,
            headers: const {'content-type': 'application/json'});
      }),
      baseUri: Uri.parse('https://unit.test/'),
    );

void main() {
  test('Authenticated identity derives only from /api/v1/me', () async {
    final api = serverReply({'id': 17, 'username': 'not-an-identity'},
      validate: (request) {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/me/');
        expect(request.headers['Accept'], 'application/json');
      });
    expect(await api.fetchAuthenticatedUserId(), '17');
    api.close();
  });

  test('Missing, forged or invalid identity is always rejected', () async {
    for (final payload in <Object>[
      <String, dynamic>{},
      {'id': true}, {'id': '17'}, {'id': null},
      {'id': 0}, {'id': -1}, {'id': 9007199254740992},
      ['17'],
    ]) {
      final api = serverReply(payload);
      await expectLater(api.fetchAuthenticatedUserId(),
          throwsA(isA<VenciraApiException>()));
      api.close();
    }
  });

  test('Session revocation does not return cached identity', () async {
    final api = serverReply({'detail': 'expired'}, status: 401);
    await expectLater(api.fetchAuthenticatedUserId(),
        throwsA(isA<VenciraUnauthorized>()));
    api.close();
  });
}
