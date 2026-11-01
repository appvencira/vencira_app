import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/vencira_api.dart';

const workspace = '11111111-1111-4111-8111-111111111111';
const reminder = '22222222-2222-4222-8222-222222222222';
const renewal = '33333333-3333-4333-8333-333333333333';

Map<String, dynamic> payload() => {
  'from': '2027-03-01', 'through': '2027-03-31',
  'timezone': 'Europe/Madrid', 'count': 1,
  'next': null, 'previous': null,
  'capabilities': {
    'native_alarm_scheduling': false, 'offline_storage': false,
    'delivery': false,
  },
  'results': [{
    'id': reminder, 'renewal_id': renewal, 'scheduled_for': '2027-03-08',
    'state': 'planned', 'reason': 'Revisar documento',
    'control_question': true, 'generation': 2,
    'delivery_status': 'not_implemented',
  }],
};

void main() {
  test('M3: preview parses candidate but no delivery capability', () {
    final preview = VenciraDeviceNoticePreview.fromJson(payload());
    expect(preview.total, 1);
    expect(preview.hasNext, false);
    expect(preview.items.single.id, reminder);
    expect(preview.items.single.generation, 2);
    expect(preview.items.single.scheduledFor, DateTime(2027, 3, 8));
  });

  test('M3: fail closed on fictitious delivery, offline capability and PII', () {
    final original = payload();
    for (final caps in [
      {'native_alarm_scheduling': true, 'offline_storage': false, 'delivery': false},
      {'native_alarm_scheduling': false, 'offline_storage': true, 'delivery': false},
      {'native_alarm_scheduling': false, 'offline_storage': false, 'delivery': true},
    ]) {
      expect(() => VenciraDeviceNoticePreview.fromJson({
        ...original, 'capabilities': caps,
      }), throwsFormatException);
    }
    for (final changes in [
      {'delivery_status': 'delivered'},
      {'scheduled_for': '2027-04-01'},
      {'state': 'sent'},
      {'generation': -1},
      {'id': 'bogus'},
    ]) {
      final row = {...((original['results'] as List).first as Map<String, dynamic>),
        ...changes};
      expect(() => VenciraDeviceNoticePreview.fromJson({
        ...original, 'results': [row],
      }), throwsFormatException);
    }
  });

  test('M3: rejects duplicate occurrence and >31 days', () {
    final body = payload();
    final record = (body['results'] as List).single;
    expect(() => VenciraDeviceNoticePreview.fromJson({
      ...body, 'results': [record, record], 'count': 2,
    }), throwsFormatException);
    expect(() => VenciraDeviceNoticePreview.fromJson({
      ...body, 'through': '2027-04-01',
    }), throwsFormatException);
  });

  test('M3: HTTP adapter uses only local endpoint and rejects extra window', () async {
    final api = HttpVenciraApi(
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.host, 'notice-unit.invalid');
        expect(request.url.path,
            '/api/v1/workspaces/$workspace/device-notice-preview/');
        expect(request.url.queryParameters['from'], '2027-03-01');
        expect(request.url.queryParameters['through'], '2027-03-31');
        expect(request.url.queryParameters['page'], '1');
        return http.Response(jsonEncode(payload()), 200);
      }),
      baseUri: Uri.parse('https://notice-unit.invalid/'),
    );
    final preview = await api.fetchDeviceNoticePreview(
      workspace, DateTime(2027, 3, 1), DateTime(2027, 3, 31));
    expect(preview.items.single.reason, 'Revisar documento');
    await expectLater(
      api.fetchDeviceNoticePreview(
          workspace, DateTime(2027, 3, 1), DateTime(2027, 4, 1)),
      throwsA(isA<VenciraApiException>()),
    );
    api.close();
  });

  test('M3: HTTP adapter rejects altered response window', () async {
    final response = payload()..['from'] = '2027-03-02';
    final api = HttpVenciraApi(
      client: MockClient((request) async =>
          http.Response(jsonEncode(response), 200)),
      baseUri: Uri.parse('https://notice-unit.invalid/'),
    );
    await expectLater(
      api.fetchDeviceNoticePreview(
          workspace, DateTime(2027, 3, 1), DateTime(2027, 3, 31)),
      throwsA(isA<VenciraApiException>()),
    );
    api.close();
  });
}
