import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';

void main() {
  final sample = <String, dynamic>{
    'day': '2027-03-10', 'scope': 'due', 'count': 1,
    'next': null, 'previous': null,
    'counts': {'overdue': 1, 'today': 0, 'upcoming': 2},
    'results': [{
      'id': '11111111-1111-4111-8111-111111111111',
      'renewal_id': '22222222-2222-4222-8222-222222222222',
      'reference': 'DEMO-1', 'kind': 'expiry',
      'scheduled_for': '2027-03-09', 'original_scheduled_for': '2027-03-09',
      'state': 'planned', 'reason': 'Seguimiento ficticio',
      'control_question': false, 'overdue': true,
      'delivery_status': 'not_implemented',
    }],
  };

  test('B: inbox parses civil dates, counts and overdue without delivery', () {
    final inbox = VenciraOperationalInbox.fromJson(sample);
    expect(inbox.overdue, 1);
    expect(inbox.today, 0);
    expect(inbox.upcoming, 2);
    expect(inbox.items.single.overdue, true);
    expect(inbox.items.single.reference, 'DEMO-1');
    expect(inbox.items.single.reminder.state, 'planned');
    expect(inbox.items.single.reminder.day.day, 9);
  });

  test('B: invalid counters rejected', () {
    final malformed = <String, dynamic>{
      ...sample, 'counts': {'overdue': -1, 'today': 0, 'upcoming': 2}
    };
    expect(() => VenciraOperationalInbox.fromJson(malformed),
      throwsFormatException);
  });

  test('B: delivery cannot be represented as implemented', () {
    final invalid = <String, dynamic>{
      ...sample, 'results': [
        {...((sample['results'] as List).first as Map<String, dynamic>),
         'delivery_status': 'delivered'}
      ],
    };
    expect(() => VenciraOperationalInbox.fromJson(invalid),
      throwsFormatException);
  });
}
