import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/vencira_api.dart';

const ws = '11111111-1111-4111-8111-111111111111';
const renewal = '22222222-2222-4222-8222-222222222222';
const reminderId = '33333333-3333-4333-8333-333333333333';

VenciraOperationalReminder item() => VenciraOperationalReminder(
  id: reminderId, state: 'planned', day: DateTime(2027, 2, 8),
  reason: 'Control interno', controlQuestion: true,
  latestControlRepeatOn: DateTime(2027, 2, 14),
);

HttpVenciraApi apiWithReply(Map<String, dynamic> actionReply,
    {int status = 200, void Function(http.Request)? checkRequest}) {
  final client = MockClient((request) async {
    if (request.uri.path == '/api/v1/csrf/') {
      return http.Response(
        jsonEncode({'csrfToken': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}),
        200, headers: {'content-type': 'application/json'},
      );
    }
    checkRequest?.call(request);
    return http.Response(jsonEncode(actionReply), status,
      headers: {'content-type': 'application/json'});
  });
  return HttpVenciraApi(client: client, baseUri: Uri.parse('https://unit.test/'));
}

Map<String, dynamic> validReply() => {
  'id': reminderId, 'state': 'snoozed', 'scheduled_for': '2027-02-10',
  'delivery_status': 'not_implemented',
};

void main() {
  test('HTTP action: successful internal result preserves control bound', () async {
    final api = apiWithReply(validReply(), checkRequest: (req) {
      expect(req.method, 'POST');
      expect(req.uri.path, contains('/operational-reminders/$reminderId/action/'));
      expect(req.headers['X-CSRFToken'], isNotEmpty);
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['action'], 'another_day');
      expect(body['expected_state'], 'planned');
      expect(body['expected_day'], '2027-02-08');
      expect(body['days_later'], 2);
    });
    final result = await api.updateOperationalReminder(
      ws, renewal, item(), 'another_day',
      '44444444-4444-4444-8444-444444444444', daysLater: 2,
    );
    expect(result.state, 'snoozed');
    expect(result.day, DateTime(2027, 2, 10));
    expect(result.latestControlRepeatOn, DateTime(2027, 2, 14));
    api.close();
  });

  test('HTTP action: forged identity, state or delivery never accepted', () async {
    final invalid = <Map<String, dynamic>>[
      {...validReply(), 'id': '55555555-5555-4555-8555-555555555555'},
      {...validReply(), 'state': 'delivered'},
      {...validReply(), 'delivery_status': 'delivered'},
      {...validReply(), 'delivery_status': null},
      {...validReply(), 'scheduled_for': '2027-2-10'},
      {...validReply(), 'scheduled_for': '2027-02-30'},
    ];
    for (final reply in invalid) {
      final api = apiWithReply(reply);
      await expectLater(
        api.updateOperationalReminder(ws, renewal, item(), 'complete',
            '44444444-4444-4444-8444-444444444444'),
        throwsA(isA<VenciraApiException>()),
      );
      api.close();
    }
  });

  test('HTTP action: stale revision conflict triggers reload', () async {
    final api = apiWithReply({'detail': 'stale'}, status: 409);
    await expectLater(
      api.updateOperationalReminder(ws, renewal, item(), 'complete',
          '44444444-4444-4444-8444-444444444444'),
      throwsA(isA<VenciraConflictException>()),
    );
    api.close();
  });

  test('HTTP action: unauthorized is a distinct failure', () async {
    final api = apiWithReply({'detail': 'unauthorized'}, status: 403);
    await expectLater(
      api.updateOperationalReminder(ws, renewal, item(), 'complete',
          '44444444-4444-4444-8444-444444444444'),
      throwsA(isA<VenciraUnauthorized>()),
    );
    api.close();
  });
}
