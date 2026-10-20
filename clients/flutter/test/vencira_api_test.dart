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

  test('interpreta límite contractual explícito opcional', () async {
    const data = <String, dynamic>{
      'id': 'b2222222-2222-4222-8222-222222222222',
      'customer_reference': 'DEMO',
      'expires_on': '2027-05-01',
      'notice_deadline_on': '2027-03-31',
      'status': 'pending',
    };
    final renewal = VenciraRenewal.fromJson(data);
    expect(renewal.noticeDeadlineOn, DateTime(2027, 3, 31));
    expect(renewal.expiresOn, DateTime(2027, 5, 1));
    final without = VenciraRenewal.fromJson({...data, 'notice_deadline_on': null});
    expect(without.noticeDeadlineOn, isNull);
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

  test('crear vencimiento solicita CSRF y envía JSON válido', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (request.url.path == '/api/v1/csrf/') {
        expect(request.method, 'GET');
        return http.Response('{"csrfToken":"abcdefghijklmnopqrstuvwxyz123456"}', 200);
      }
      expect(request.method, 'POST');
      expect(request.headers['x-csrftoken'], 'abcdefghijklmnopqrstuvwxyz123456');
      expect(request.body, contains('"customer_reference":"DEMO"'));
      expect(request.body, contains('"notice_deadline_on":"2027-03-31"'));
      return http.Response('{"id":"b2222222-2222-4222-8222-222222222222",'
          '"customer_reference":"DEMO","expires_on":"2027-05-01",'
          '"notice_deadline_on":"2027-03-31","status":"pending"}', 201);
    });
    final api = HttpVenciraApi(client: client,
        baseUri: Uri.parse('http://localhost:18731/'));
    final created = await api.createRenewal(
      workspaceId,
      VenciraRenewalInput(
        reference: 'DEMO',
        expiresOn: DateTime(2027, 5, 1),
        noticeDeadlineOn: DateTime(2027, 3, 31),
      ),
    );
    expect(calls, 2);
    expect(created.noticeDeadlineOn, DateTime(2027, 3, 31));
  });

  test('editar vencimiento usa PATCH con CSRF', () async {
    var writes = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/csrf/') {
        return http.Response('{"csrfToken":"abcdefghijklmnopqrstuvwxyz123456"}', 200);
      }
      writes += 1;
      expect(request.method, 'PATCH');
      expect(request.headers['x-csrftoken'], isNotEmpty);
      return http.Response('{"id":"b2222222-2222-4222-8222-222222222222",'
          '"customer_reference":"DEMO","expires_on":"2027-05-01",'
          '"notice_deadline_on":null,"status":"closed"}', 200);
    });
    final api = HttpVenciraApi(client: client,
        baseUri: Uri.parse('http://localhost:18731/'));
    final updated = await api.updateRenewal(
      workspaceId, 'b2222222-2222-4222-8222-222222222222',
      VenciraRenewalInput(reference: 'DEMO',
          expiresOn: DateTime(2027, 5, 1), status: 'closed'),
    );
    expect(writes, 1);
    expect(updated.status, 'closed');
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
