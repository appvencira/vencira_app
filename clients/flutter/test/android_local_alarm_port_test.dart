import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/android_local_alarm_port.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';

void main() {
  test('Stable numeric alarm identity is consistent and positive', () {
    const a = '11111111-1111-4111-8111-111111111111/17/'
      '22222222-2222-4222-8222-222222222222/1';
    expect(androidNoticeId(a), androidNoticeId(a));
    expect(androidNoticeId(a), greaterThan(0));
    expect(androidNoticeId(a), lessThan(2147483648));
    expect(androidNoticeId(a), isNot(androidNoticeId('$a/changed')));
  });

  test('Registry allows retrying a verified cancellation without new grants', () {
    final alarm = DeviceNoticeSlot(
      workspaceId: '11111111-1111-4111-8111-111111111111',
      userId: '17',
      occurrenceId: '22222222-2222-4222-8222-222222222222',
      generation: 1, at: DateTime(2027, 3, 12, 9),
    );
    final registry = AndroidNoticeIdRegistry([alarm]);
    final first = registry.authorizedCancelId(alarm);
    expect(registry.authorizedCancelId(alarm), first);
    expect(registry.reserve(alarm), first);
    final foreign = DeviceNoticeSlot(
      workspaceId: alarm.workspaceId, userId: '18',
      occurrenceId: alarm.occurrenceId, generation: 1, at: alarm.at,
    );
    expect(() => registry.authorizedCancelId(foreign), throwsStateError);
  });

  test('Empty alarm key is never accepted', () {
    expect(() => androidNoticeId(''), throwsFormatException);
  });
}
