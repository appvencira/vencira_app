import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';
import 'package:vencira/notifications/device_notice_sync.dart';
import 'package:vencira/notifications/device_notice_transaction.dart';

const ws = '11111111-1111-4111-8111-111111111111';
const user = '17';
const idA = '22222222-2222-4222-8222-222222222222';
const idB = '33333333-3333-4333-8333-333333333333';
DeviceNoticeSlot slot(String id, int day) => DeviceNoticeSlot(
  workspaceId: ws, userId: user, occurrenceId: id, generation: 1,
  at: DateTime(2027, 3, day, 9),
);

class Ledger implements DeviceAlarmLedger {
  List<DeviceNoticeSlot> inventory = [];
  List<DeviceNoticeSlot>? pending;
  bool failWrite = false;
  final events = <String>[];

  @override
  Future<List<DeviceNoticeSlot>> read({
    required String workspaceId, required String userId,
  }) async => List.of(inventory);
  @override
  Future<List<DeviceNoticeSlot>?> readPending({
    required String workspaceId, required String userId,
  }) async => pending == null ? null : List.of(pending!);
  @override
  Future<void> write({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    events.add('commit');
    if (failWrite) throw StateError('encrypted storage failed');
    inventory = List.of(slots);
  }
  @override
  Future<void> writePending({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    events.add('journal');
    if (pending != null) throw StateError('existing journal');
    pending = List.of(slots);
  }
  @override
  Future<void> clearPending() async {
    events.add('clear');
    pending = null;
  }
}

class Port implements DeviceNoticeAlarmPort {
  Port(this.events);
  final List<String> events;
  final active = <String>{};
  bool failCancel = false;
  bool failSchedule = false;

  @override
  Future<void> cancel(DeviceNoticeSlot slot) async {
    events.add('cancel');
    if (failCancel) throw StateError('OS cancellation failed');
    active.remove(slot.key);
  }
  @override
  Future<void> schedule(DeviceNoticeSlot slot) async {
    events.add('schedule');
    active.add(slot.key);
    if (failSchedule) throw StateError('OS ACK lost');
  }
}

Future<void> run(Ledger ledger, Port port, DeviceNoticeDiff diff) =>
    applyDurableDeviceNoticeDiff(
      ledger: ledger, port: port, workspaceId: ws,
      userId: user, diff: diff,
    );
Future<void> recover(Ledger ledger, Port port) =>
    recoverInterruptedDeviceNotices(
      ledger: ledger, port: port, workspaceId: ws, userId: user,
    );

void main() {
  test('Journals BEFORE OS action and commits after successful scheduling',
      () async {
    final ledger = Ledger();
    final port = Port(ledger.events);
    await run(ledger, port, DeviceNoticeDiff(
        cancel: const [], schedule: [slot(idA, 12)]));
    expect(ledger.events, ['journal', 'schedule', 'commit', 'clear']);
    expect(ledger.pending, isNull);
    expect(ledger.inventory, hasLength(1));
    expect(port.active, {slot(idA, 12).key});
  });

  test('Lost Android ACK leaves journal until recovery', () async {
    final ledger = Ledger();
    final port = Port(ledger.events)..failSchedule = true;
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: const [], schedule: [slot(idA, 12)],
    )), throwsStateError);
    expect(ledger.events.first, 'journal');
    expect(ledger.pending, isNotNull);
    port.failSchedule = false;
    await recover(ledger, port);
    expect(ledger.pending, isNull);
    expect(ledger.inventory, isEmpty);
    expect(port.active, isEmpty);
  });

  test('Process crash after OS write is caught by pending journal', () async {
    final ledger = Ledger();
    final port = Port(ledger.events);
    final alarm = slot(idA, 12);
    ledger.pending = [alarm]; // Crash before durable COMMIT.
    port.active.add(alarm.key);
    await recover(ledger, port);
    expect(port.active, isEmpty);
    expect(ledger.pending, isNull);
    expect(ledger.inventory, isEmpty);
  });

  test('Storage commit failure cannot erase journal or claim success',
      () async {
    final ledger = Ledger()..failWrite = true;
    final port = Port(ledger.events);
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: const [], schedule: [slot(idA, 12)],
    )), throwsStateError);
    expect(ledger.pending, isNotNull);
    expect(port.active, hasLength(1));
    ledger.failWrite = false;
    await recover(ledger, port);
    expect(port.active, isEmpty);
    expect(ledger.pending, isNull);
  });

  test('Recovery cancellation failure blocks new scheduling and stays journalled',
      () async {
    final ledger = Ledger()..pending = [slot(idA, 12)];
    final port = Port(ledger.events)..failCancel = true;
    await expectLater(recover(ledger, port), throwsStateError);
    expect(ledger.pending, isNotNull);
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: const [], schedule: [slot(idB, 13)],
    )), throwsStateError);
    expect(ledger.events, ['cancel']);
  });

  test('Changed day with same alarm ID only journals once', () async {
    final previous = slot(idA, 12), changed = slot(idA, 13);
    final ledger = Ledger()..inventory = [previous];
    final port = Port(ledger.events)..active.add(previous.key);
    await run(ledger, port, DeviceNoticeDiff(
      cancel: [previous], schedule: [changed],
    ));
    expect(ledger.events, ['journal', 'cancel', 'schedule', 'commit', 'clear']);
    expect(ledger.inventory.single.at, changed.at);
    expect(ledger.pending, isNull);
  });

  test('Logout revokes all verified alarms before returning empty inventory',
      () async {
    final ledger = Ledger()..inventory = [slot(idA, 12), slot(idB, 13)];
    final port = Port(ledger.events)
      ..active.addAll(ledger.inventory.map((alarm) => alarm.key));
    await revokeAllDeviceNotices(
      ledger: ledger, revocationPort: port,
      workspaceId: ws, userId: user,
    );
    expect(ledger.inventory, isEmpty);
    expect(ledger.pending, isNull);
    expect(port.active, isEmpty);
    expect(ledger.events, [
      'journal', 'cancel', 'cancel', 'commit', 'clear',
    ]);
  });

  test('Revocation cancellation error preserves journal; retry recovers',
      () async {
    final ledger = Ledger()..inventory = [slot(idA, 12)];
    final port = Port(ledger.events)
      ..active.add(slot(idA, 12).key)
      ..failCancel = true;
    await expectLater(revokeAllDeviceNotices(
      ledger: ledger, revocationPort: port,
      workspaceId: ws, userId: user,
    ), throwsStateError);
    expect(ledger.inventory, hasLength(1));
    expect(ledger.pending, isNotNull);
    port.failCancel = false;
    await revokeAllDeviceNotices(
      ledger: ledger, revocationPort: port,
      workspaceId: ws, userId: user,
    );
    expect(ledger.inventory, isEmpty);
    expect(ledger.pending, isNull);
    expect(port.active, isEmpty);
  });

  test('Refuses stale cancellation, cross-account insertion and conflicting IDs',
      () async {
    final ledger = Ledger()..inventory = [slot(idA, 12)];
    final port = Port(ledger.events);
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: [slot(idA, 13)], schedule: const [],
    )), throwsStateError);
    final cross = DeviceNoticeSlot(
      workspaceId: '99999999-9999-4999-8999-999999999999',
      userId: user, occurrenceId: idB, generation: 1,
      at: DateTime(2027, 3, 13, 9),
    );
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: const [], schedule: [cross],
    )), throwsStateError);
    await expectLater(run(ledger, port, DeviceNoticeDiff(
      cancel: const [], schedule: [slot(idA, 13)],
    )), throwsStateError);
    expect(ledger.events, isEmpty);
  });
}
