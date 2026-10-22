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
      expect(request.headers.entries.any((header) =>
          header.key.toLowerCase() == 'x-csrftoken' &&
          header.value == 'abcdefghijklmnopqrstuvwxyz123456'), isTrue);
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
      expect(request.headers.entries.any((header) =>
          header.key.toLowerCase() == 'x-csrftoken' && header.value.isNotEmpty), isTrue);
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

  test('logout usa POST con CSRF para cerrar la sesión', () async {
    var posts = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/csrf/') {
        return http.Response('{"csrfToken":"abcdefghijklmnopqrstuvwxyz123456"}', 200);
      }
      posts += 1;
      expect(request.url.path, '/accounts/logout/');
      expect(request.method, 'POST');
      expect(request.headers.entries.any((header) =>
          header.key.toLowerCase() == 'x-csrftoken' && header.value.isNotEmpty), isTrue);
      return http.Response('', 200);
    });
    final api = HttpVenciraApi(client: client,
        baseUri: Uri.parse('http://localhost:18731/'));
    await api.logout();
    expect(posts, 1);
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
  test('codifica búsqueda y estado como parámetros seguros', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/workspaces/$workspaceId/renewals/');
      expect(request.url.queryParameters['page'], '1');
      expect(request.url.queryParameters['q'], 'CASA Nº 1');
      expect(request.url.queryParameters['status'], 'contacted');
      return http.Response('{"count":0,"next":null,"results":[]}', 200);
    });
    final api = HttpVenciraApi(
      client: client, baseUri: Uri.parse('http://localhost:18731/'));
    final result = await api.fetchRenewals(
      workspaceId, search: ' CASA Nº 1 ', status: 'contacted');
    expect(result.total, 0);
  });

  test('rechaza filtros no válidos antes de consultar', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final api = HttpVenciraApi(
      client: client, baseUri: Uri.parse('http://localhost:18731/'));
    await expectLater(
      api.fetchRenewals(workspaceId, status: 'otro'),
      throwsA(isA<VenciraApiException>()),
    );
    await expectLater(
      api.fetchRenewals(workspaceId, search: List.filled(81, 'A').join()),
      throwsA(isA<VenciraApiException>()),
    );
    expect(calls, 0);
  });

  test('agenda usa día civil ISO y no sigue URLs next externas', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.url.origin, 'http://localhost:18731');
      expect(request.url.path, '/api/v1/workspaces/$workspaceId/agenda/');
      expect(request.url.queryParameters['day'], '2027-03-31');
      expect(request.url.queryParameters['page'], '2');
      return http.Response(
        '{"day":"2027-03-31","count":12,'
        '"next":"https://host-malicioso.invalid/robar",'
        '"results":[{"renewal":{'
        '"id":"b2222222-2222-4222-8222-222222222222",'
        '"customer_reference":"DEMO-AVISO",'
        '"expires_on":"2027-05-01","status":"pending"},'
        '"events":[{"kind":"reminder",'
        '"candidate_id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa",'
        '"basis":"notice_deadline"}]}]}',
        200,
      );
    });
    final api = HttpVenciraApi(
      client: client, baseUri: Uri.parse('http://localhost:18731/'));
    final result = await api.fetchAgendaDay(workspaceId, DateTime(2027, 3, 31),
        page: 2);
    expect(result.total, 12);
    expect(result.hasNext, true);
    expect(result.day, DateTime(2027, 3, 31));
    expect(result.entries.single.events.single.kind, 'reminder');
    expect(result.entries.single.events.single.basis, 'notice_deadline');
    expect(calls, 1);
  });

  test('acepta evento contractual sin candidato ni envío programado', () {
    final event = VenciraAgendaEvent.fromJson(
      {'kind': 'notice_deadline'},
    );
    expect(event.kind, 'notice_deadline');
    expect(event.candidateId, isNull);
    expect(event.basis, isNull);
    expect(
      () => VenciraAgendaEvent.fromJson({'kind': 'reminder'}),
      throwsFormatException,
    );
  });

  test('resumen mensual usa el mismo origen y valida las cantidades', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/workspaces/$workspaceId/agenda/month/');
      expect(request.url.queryParameters, {'month': '2027-03'});
      expect(request.url.origin, 'http://localhost:18731');
      return http.Response(
        '{"month":"2027-03","days":[{"day":"2027-03-31",'
        '"expiry":{"pending":1,"contacted":1},'
        '"notice_deadline":{"pending":0,"contacted":1},'
        '"reminder":{"pending":2,"contacted":0}}]}', 200,
      );
    });
    final api = HttpVenciraApi(
      client: client, baseUri: Uri.parse('http://localhost:18731/'));
    final month = await api.fetchAgendaMonth(workspaceId, DateTime(2027, 3, 31));
    expect(month.days.single.expiry.total, 2);
    expect(month.days.single.notice.contacted, 1);
    expect(month.days.single.reminder.pending, 2);
  });

  test('resumen mensual rechaza meses discordantes, ajenos y cantidades negativas',
      () async {
    final bad = [
      '{"month":"2027-04","days":[]}',
      '{"month":"2027-03","days":[{"day":"2027-04-01",'
        '"expiry":{"pending":1,"contacted":0},'
        '"notice_deadline":{"pending":0,"contacted":0},'
        '"reminder":{"pending":0,"contacted":0}}]}',
      '{"month":"2027-03","days":[{"day":"2027-03-31",'
        '"expiry":{"pending":-1,"contacted":0},'
        '"notice_deadline":{"pending":0,"contacted":0},'
        '"reminder":{"pending":0,"contacted":0}}]}',
    ];
    for (final payload in bad) {
      final api = HttpVenciraApi(
        client: MockClient((_) async => http.Response(payload, 200)),
        baseUri: Uri.parse('http://localhost:18731/'),
      );
      await expectLater(
        api.fetchAgendaMonth(workspaceId, DateTime(2027, 3, 1)),
        throwsA(isA<VenciraApiException>()),
      );
    }
    final api = HttpVenciraApi(
      client: MockClient((_) async => http.Response('{}', 200)),
      baseUri: Uri.parse('http://localhost:18731/'),
    );
    await expectLater(api.fetchAgendaMonth('../otro', DateTime(2027, 3, 1)),
        throwsA(isA<VenciraApiException>()));
  });

  test('agenda rechaza parámetros manipulados antes de consultar', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final api = HttpVenciraApi(
      client: client, baseUri: Uri.parse('http://localhost:18731/'));
    await expectLater(
      api.fetchAgendaDay('../otra', DateTime(2027, 3, 31)),
      throwsA(isA<VenciraApiException>()),
    );
    await expectLater(
      api.fetchAgendaDay(workspaceId, DateTime(2027, 3, 31), page: 0),
      throwsA(isA<VenciraApiException>()),
    );
    expect(calls, 0);
  });

  test('agenda no acepta otra fecha o eventos desconocidos del servidor', () async {
    final api = HttpVenciraApi(
      client: MockClient((_) async => http.Response(
        '{"day":"2027-04-01","count":0,"next":null,"results":[]}', 200)),
      baseUri: Uri.parse('http://localhost:18731/'),
    );
    await expectLater(
      api.fetchAgendaDay(workspaceId, DateTime(2027, 3, 31)),
      throwsA(isA<VenciraApiException>()),
    );
    expect(
      () => VenciraAgendaEvent.fromJson({'kind': 'delivered'}),
      throwsFormatException,
    );
  });

}
