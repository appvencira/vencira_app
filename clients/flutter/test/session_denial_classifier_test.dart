import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/session_denial_classifier.dart';

void main() {
  for (final code in [401, 403]) {
    test('$code with confirmed anonymous identity means expired', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unauthenticated),
        SessionDenial.expired);
    });
    test('$code with valid identity cannot revoke the whole session', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.authenticated),
        SessionDenial.forbidden);
    });
    test('$code with unavailable probe remains unknown', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unavailable),
        SessionDenial.unknown);
    });
  }

  for (final status in [401, 403]) {
    test('GET denial $status with valid identity is not session expiry', () async {
      final api = HttpVenciraApi(
        baseUri: Uri.parse('https://unit.test/'),
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/me/') {
            return http.Response(jsonEncode({'id': 7}), 200);
          }
          return http.Response('{}', status);
        }),
      );
      await expectLater(api.fetchWorkspaces(),
          throwsA(isA<VenciraApiException>()));
      api.close();
    });

    test('GET denial $status with denied identity revokes session', () async {
      final api = HttpVenciraApi(
        baseUri: Uri.parse('https://unit.test/'),
        client: MockClient((request) async => http.Response('{}', status)),
      );
      await expectLater(api.fetchWorkspaces(),
          throwsA(isA<VenciraUnauthorized>()));
      api.close();
    });
  }

  test('network failure on identity probe never claims session expired', () async {
    final api = HttpVenciraApi(
      baseUri: Uri.parse('https://unit.test/'),
      client: MockClient((request) async {
        if (request.url.path == '/api/v1/me/') {
          throw StateError('offline');
        }
        return http.Response('{}', 403);
      }),
    );
    await expectLater(api.fetchWorkspaces(),
        throwsA(isA<VenciraApiException>()));
    api.close();
  });

  test('unrelated status cannot be mistaken for expiration', () {
    for (final code in [0, 200, 400, 404, 409, 422, 500, 503]) {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unauthenticated),
        SessionDenial.unknown);
    }
  });
}
