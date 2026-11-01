import 'device_notice_reconciliation.dart';

/// Port for a future OS-specific adapter. No implementation is registered in
/// the shipping app, and no native plugin is installed in this phase.
abstract class DeviceNoticeAlarmPort {
  Future<void> cancel(DeviceNoticeSlot slot);
  Future<void> schedule(DeviceNoticeSlot slot);
}

/// Apply a verified diff in fail-closed order: remove old alarms first.
///
/// A cancelled or scheduled notification is NOT evidence of delivery.
/// A lost ACK during schedule is ambiguous: attempt to cancel that slot and
/// any newly scheduled slots. Native implementations must also reconcile their
/// persistent inventory on every app start, permission change and logout.
Future<void> applyDeviceNoticeDiff(
    DeviceNoticeDiff diff, DeviceNoticeAlarmPort port) async {
  for (final item in diff.cancel) {
    await port.cancel(item); // Never schedule more if cancellation failed.
  }
  final installedNow = <DeviceNoticeSlot>[];
  for (final item in diff.schedule) {
    try {
      await port.schedule(item);
      installedNow.add(item);
    } catch (error, stack) {
      // The failed call may have written to Android before losing its ACK.
      for (final possible in [item, ...installedNow.reversed]) {
        try {
          await port.cancel(possible);
        } catch (_) {
          // Keep the original failure; a future inventory reconciliation
          // is mandatory, rather than reporting a successful schedule.
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }
}
