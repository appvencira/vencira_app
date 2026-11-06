import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';
import 'package:vencira/notifications/device_notice_sync.dart';

const ws = '11111111-1111-4111-8111-111111111111';
const uid = '17';
const occ1 = '22222222-2222-4222-8222-222222222222';
const occ2 = '33333333-3333-4333-8333-333333333333';

DeviceNoticeSlot slot(String id, int day) => DeviceNoticeSlot(
  workspaceId: ws, userId: uid, occurrenceId: id, generation: 1,
  at: DateTime(2027, 3, day, 9),
);

class MemoryAlarmPort implements DeviceNoticeAlarmPort {
  final events = <String>[];
  final active = <String>{};
  String? failCancelKey;
  String? failScheduleKey;

  @override
  Future<void> cancel(DeviceNoticeSlot item) async {
    events.add('cancel:${item.occurrenceId}');
    if (item.key == failCancelKey) throw StateError('cancel failed');
    active.remove(item.key);
  }

  @override
  Future<void> schedule(DeviceNoticeSlot item) async {
    events.add('schedule:${item.occurrenceId}');
    active.add(item.key);
    if (item.key == failScheduleKey) {
      // Simulate alarm installed by Android, but platform ACK lost.
      throw StateError('schedule ACK lost');
    }
  }
}

void main() {
  test('Removal precedes creation and leaves only latest alarm', () async {
    final first = slot(occ1, 12);
    final second = slot(occ2, 13);
    final port = MemoryAlarmPort()..active.add(first.key);
    await applyDeviceNoticeDiff(
      DeviceNoticeDiff(cancel: [first], schedule: [second]), port);
    expect(port.events, ['cancel:$occ1', 'schedule:$occ2']);
    expect(port.active, {second.key});
  });

  test('Failed cancellation blocks all new schedules', () async {
    final first = slot(occ1, 12);
    final port = MemoryAlarmPort()
      ..active.add(first.key)
      ..failCancelKey = first.key;
    await expectLater(
      applyDeviceNoticeDiff(DeviceNoticeDiff(
          cancel: [first], schedule: [slot(occ2, 13)]), port),
      throwsStateError,
    );
    expect(port.events, ['cancel:$occ1']);
    expect(port.active, {first.key});
  });

  test('Ambiguous platform ACK compensates newly installed alarms', () async {
    final first = slot(occ1, 12);
    final second = slot(occ2, 13);
    final port = MemoryAlarmPort()..failScheduleKey = second.key;
    await expectLater(
      applyDeviceNoticeDiff(
          DeviceNoticeDiff(cancel: const [], schedule: [first, second]),
          port),
      throwsStateError,
    );
    expect(port.active, isEmpty);
    expect(port.events, [
      'schedule:$occ1', 'schedule:$occ2', 'cancel:$occ2', 'cancel:$occ1',
    ]);
  });

  test('Denied/disabled result has no implicit scheduling', () async {
    final previous = slot(occ1, 12);
    final port = MemoryAlarmPort()..active.add(previous.key);
    await applyDeviceNoticeDiff(
      DeviceNoticeDiff(cancel: [previous], schedule: const []), port);
    expect(port.active, isEmpty);
    expect(port.events, ['cancel:$occ1']);
  });
}
