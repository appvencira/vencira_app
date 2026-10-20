import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/vencira_api.dart';

void main() {
  const workspaceId = '11111111-1111-4111-8111-111111111111';

  test('carga organizaciones desde URL fija del mismo origen', () async {
    final client = MockClient((request) async {
      expect(request.url.origin, 'http://localhost:18731');
      expect(request.url.path, '/api/v1/workspaces/');
      return http.Response(
        '[{"id":"$workspaceId","name":"Organización demo","role":"owner"}]',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = HttpVenciraApi(client: client, baseUri: Uri.parse('http://localhost:18731/'));
    final items = await api.fetchWorkspaces();
    expect(items.single.name, 'Organización demo');
    expect(items.single.role, 'owner');
  });

  test('carga página con estado y vencimiento', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/workspaces/$workspaceId/renewals/');
      expect(request.url.queryParameters['page'], '2');
      return http.Response(
        '{"count":2,"next":null,"previous":"prev","results":['
        '{"id":"b2222222-2222-4222-8222-222222222222",'
        '"customer_reference":"REFERENCIA DEMO","expires_on":"2027-07-11",'
        '"status":"pending"}]}',
        200,
      );
    });
    final api = HttpVenciraApi(client: client, baseUri: Uri.parse('http://localhost:18731/'));
    final result = await api.fetchRenewals(workspaceId, page: 2);
    expect(result.total, 2);
    expect(result.hasNext, false);
    expect(result.items.single.reference, 'REFERENCIA DEMO');
    expect(result.items.single.expiresOn.day, 11);
  });

  test('rechaza identificadores manipulados antes de hacer peticiones', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls += 1;
      return http.Response('{}', 200);
    });
    final api = HttpVenciraApi(client: client, baseUri: Uri.parse('http://localhost:18731/'));
    await expectLater(
      api.fetchRenewals('../workspace/otro'), throwsA(isA<VenciraApiException>()),
    );
    expect(calls, 0);
  });

  test('sin sesión no muestra datos', () async {
    final client = MockClient((_) async => http.Response('{"detail":"No"}', 403));
    final api = HttpVenciraApi(client: client, baseUri: Uri.parse('http://localhost:18731/'));
    await expectLater(api.fetchWorkspaces(), throwsA(isA<VenciraUnauthorized>()));
  });

  test('error técnico no revela contenido del servidor', () async {
    final client = MockClient((_) async => http.Response('información interna', 503));
    final api = HttpVenciraApi(client: client, baseUri: Uri.parse('http://localhost:18731/'));
    await expectLater(api.fetchWorkspaces(), throwsA(isA<VenciraApiException>()));
  });
}
