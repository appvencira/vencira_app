import '../api/vencira_api.dart';

/// Pure reconciliation for a future *local* OS alarm adapter.
///
/// No alarm is created here. The input is an authenticated, complete,
/// authorized server preview. A future caller must provide a trustworthy
/// encrypted inventory of previously installed alarms and native cancellation.
class DeviceNoticeSlot {
  const DeviceNoticeSlot({
    required this.workspaceId,
    required this.userId,
    required this.occurrenceId,
    required this.generation,
    required this.at,
  });

  final String workspaceId;
  final String userId;
  final String occurrenceId;
  final int generation;
  final DateTime at;

  /// Tenant + session + generation keys prevent stale alarms crossing accounts.
  String get key => '$workspaceId/$userId/$occurrenceId/$generation';

  bool sameAs(DeviceNoticeSlot other) =>
      key == other.key && at.isAtSameMomentAs(other.at);
}

class DeviceNoticeDiff {
  const DeviceNoticeDiff({required this.cancel, required this.schedule});
  final List<DeviceNoticeSlot> cancel;
  final List<DeviceNoticeSlot> schedule;
}

/// Returns only changes; it does not execute, persist or claim notification.
///
/// Requires a complete preview (no silent pagination), a declared local
/// Europe/Madrid timezone, a successful permission and storage preflight.
/// authorizedForNativeUse must remain false until Android native + offline
/// encryption + revocation and cross-device reconciliation are accepted.
/// Even with all gates true this function has *no side effects*.
DeviceNoticeDiff planDeviceNoticeReconciliation({
  required VenciraDeviceNoticePreview preview,
  required String workspaceId,
  required String userId,
  required List<DeviceNoticeSlot> existing,
  required DateTime today,
  required String deviceTimeZone,
  required bool permissionGranted,
  required bool encryptedInventoryReady,
  required bool authorizedForNativeUse,
  int hour = 9,
}) {
  final scope = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
  if (!scope.hasMatch(workspaceId) ||
      !RegExp(r'^[0-9]{1,20}$').hasMatch(userId) ||
      today.year < 2000 || today.year > 2100 ||
      hour < 0 || hour > 23) {
    throw const FormatException('Invalid device notification scope');
  }
  if (!authorizedForNativeUse || !permissionGranted ||
      !encryptedInventoryReady || deviceTimeZone != 'Europe/Madrid') {
    // A real transport must revoke any previously installed alarms whenever
    // permission, key custody, account ownership or rollout is lost.
    return DeviceNoticeDiff(cancel: List.unmodifiable(existing),
        schedule: const []);
  }
  // Never delete an installed schedule using a partial/failed server page.
  if (preview.hasNext || preview.total != preview.items.length ||
      preview.items.length > 50) {
    throw const FormatException('Incomplete authorized notice snapshot');
  }
  final nowDay = DateTime(today.year, today.month, today.day);
  final allowedFrom = DateTime(preview.from.year, preview.from.month, preview.from.day);
  final allowedThrough = DateTime(preview.through.year, preview.through.month,
      preview.through.day);
  if (allowedFrom.isAfter(nowDay) || allowedThrough.isBefore(nowDay)) {
    throw const FormatException('Preview must include current civil day');
  }
  final desired = <String, DeviceNoticeSlot>{};
  for (final item in preview.items) {
    final when = DateTime(item.scheduledFor.year, item.scheduledFor.month,
        item.scheduledFor.day, hour);
    if (when.isBefore(today)) continue;
    final slot = DeviceNoticeSlot(
      workspaceId: workspaceId, userId: userId,
      occurrenceId: item.id, generation: item.generation, at: when,
    );
    if (desired.containsKey(slot.key)) {
      throw const FormatException('Duplicate device notice identity');
    }
    desired[slot.key] = slot;
  }

  final installed = <String, DeviceNoticeSlot>{};
  for (final item in existing) {
    if (installed.containsKey(item.key)) {
      throw const FormatException('Duplicate installed notice identity');
    }
    installed[item.key] = item;
  }
  final cancel = <DeviceNoticeSlot>[];
  final schedule = <DeviceNoticeSlot>[];
  for (final old in existing) {
    final next = desired[old.key];
    if (next == null || !old.sameAs(next)) cancel.add(old);
  }
  for (final next in desired.values) {
    final old = installed[next.key];
    if (old == null || !old.sameAs(next)) schedule.add(next);
  }
  return DeviceNoticeDiff(
    cancel: List.unmodifiable(cancel),
    schedule: List.unmodifiable(schedule),
  );
}
