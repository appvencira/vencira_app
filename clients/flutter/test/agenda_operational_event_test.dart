import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';

const opId = '11111111-1111-4111-8111-111111111111';

Map<String, dynamic> operationalEvent() => {
  'kind': 'operational_reminder',
  'reminder_id': opId,
  'reason': 'Confirmar no renovación',
  'state': 'snoozed',
  'delivery_status': 'not_implemented',
};

void main() {
  test('M3 agenda: authorized operational event is parsed with reason', () {
    final event = VenciraAgendaEvent.fromJson(operationalEvent());
    expect(event.kind, 'operational_reminder');
    expect(event.operationalReminderId, opId);
    expect(event.operationalReason, 'Confirmar no renovación');
    expect(event.operationalState, 'snoozed');
  });

  test('M3 agenda: forged delivered and invalid operational payloads fail', () {
    for (final change in <Map<String, dynamic>>[
      {'delivery_status': 'delivered'},
      {'delivery_status': null},
      {'reminder_id': 'not-a-uuid'},
      {'reason': ''},
      {'reason': ' '},
      {'reason': List.filled(161, 'x').join()},
      {'reason': null},
      {'state': 'completed'},
      {'state': 'unknown'},
      {'basis': 'expiry'},
    ]) {
      final raw = {...operationalEvent(), ...change};
      expect(() => VenciraAgendaEvent.fromJson(raw),
          throwsFormatException, reason: '$change');
    }
  });

  test('M3 agenda: legacy event types remain supported', () {
    expect(VenciraAgendaEvent.fromJson({'kind': 'expiry'}).kind, 'expiry');
    expect(VenciraAgendaEvent.fromJson({'kind': 'follow_up'}).kind,
        'follow_up');
    expect(VenciraAgendaEvent.fromJson({
      'kind': 'reminder',
      'candidate_id': opId,
      'basis': 'expiry',
    }).basis, 'expiry');
  });
}
