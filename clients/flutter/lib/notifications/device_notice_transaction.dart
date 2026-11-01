import 'device_notice_reconciliation.dart';
import 'device_notice_sync.dart';

/// The pending journal survives process death and tracks every ID which may
/// have been installed, moved or cancelled in an interrupted transaction.
/// All methods must use the *same authenticated, encrypted storage boundary*.
abstract class DeviceAlarmLedger {
  Future<List<DeviceNoticeSlot>> read({
    required String workspaceId, required String userId,
  });
  Future<List<DeviceNoticeSlot>?> readPending({
    required String workspaceId, required String userId,
  });
  Future<void> write({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  });
  Future<void> writePending({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  });
  Future<void> clearPending();
}

/// Recover before any new scheduling. Retrying cancellation is safe:
/// cancellation must be idempotent even when an alarm no longer exists.
/// If cancellation or encrypted storage fails, KEEP the journal and abort.
Future<void> recoverInterruptedDeviceNotices({
  required DeviceAlarmLedger ledger,
  required DeviceNoticeAlarmPort port,
  required String workspaceId,
  required String userId,
}) async {
  final pending = await ledger.readPending(
      workspaceId: workspaceId, userId: userId);
  if (pending == null) return;
  final committed = await ledger.read(
      workspaceId: workspaceId, userId: userId);
  for (final alarm in pending) {
    await port.cancel(alarm);
  }
  final touched = {for (final alarm in pending) alarm.key};
  final surviving = committed
      .where((alarm) => !touched.contains(alarm.key)).toList();
  await ledger.write(
    workspaceId: workspaceId, userId: userId, slots: surviving,
  );
  await ledger.clearPending();
}

/// Durable two-phase local schedule. Not called by main.dart; native releases
/// require signed-in session, consent, verified OS permission and a complete
/// authorized preview BEFORE constructing the diff.
///
/// A rollback error must not be swallowed. A pending journal prohibits further
/// writes until recoverInterruptedDeviceNotices succeeds.
Future<void> applyDurableDeviceNoticeDiff({
  required DeviceAlarmLedger ledger,
  required DeviceNoticeAlarmPort port,
  required String workspaceId,
  required String userId,
  required DeviceNoticeDiff diff,
}) async {
  final pending = await ledger.readPending(
      workspaceId: workspaceId, userId: userId);
  if (pending != null) {
    throw StateError('Interrupted alarm operation requires recovery');
  }
  final committed = await ledger.read(
      workspaceId: workspaceId, userId: userId);
  final current = {for (final slot in committed) slot.key: slot};
  if (current.length != committed.length) {
    throw const FormatException('Duplicate encrypted inventory');
  }
  final desired = Map<String, DeviceNoticeSlot>.from(current);
  for (final old in diff.cancel) {
    if (old.workspaceId != workspaceId || old.userId != userId ||
        current[old.key] == null || !current[old.key]!.sameAs(old)) {
      throw StateError('Cancellation not backed by encrypted inventory');
    }
    desired.remove(old.key);
  }
  for (final next in diff.schedule) {
    if (next.workspaceId != workspaceId || next.userId != userId ||
        desired.containsKey(next.key)) {
      throw StateError('New alarm collides with retained inventory');
    }
    desired[next.key] = next;
  }
  final touched = <String, DeviceNoticeSlot>{};
  for (final old in diff.cancel) {
    if (touched.containsKey(old.key)) {
      throw StateError('Duplicate cancellation in one batch');
    }
    touched[old.key] = old;
  }
  for (final next in diff.schedule) {
    touched.putIfAbsent(next.key, () => next);
  }
  if (touched.isEmpty) return;

  // WRITE AHEAD: if Android installs an alarm and the process dies before
  // a response, recovery can cancel all potentially affected opaque IDs.
  await ledger.writePending(
    workspaceId: workspaceId, userId: userId,
    slots: touched.values.toList(),
  );
  await applyDeviceNoticeDiff(diff, port);
  await ledger.write(
    workspaceId: workspaceId, userId: userId,
    slots: desired.values.toList(),
  );
  await ledger.clearPending();
}
