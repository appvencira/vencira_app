import 'package:flutter/foundation.dart';

import 'android_local_alarm_port.dart';
import 'device_notice_consent.dart';
import 'device_notice_inventory.dart';
import 'device_notice_transaction.dart';

/// Cancellation-only integration used on explicit logout/account switch.
/// Does not obtain notification permissions or schedule any new alarm.
/// On web or non-Android platforms there are no native Android alarms.
Future<void> revokePersistedAndroidAlarms() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  final ledger = EncryptedAlarmInventory();
  final consent = EncryptedDeviceNoticeConsent();
  final stored = await ledger.readStoredScope();
  if (stored != null) {
    final current = await ledger.read(
      workspaceId: stored.workspaceId, userId: stored.userId);
    final pending = await ledger.readPending(
      workspaceId: stored.workspaceId, userId: stored.userId);
    final known = [...current, ...?pending];
    if (known.isNotEmpty) {
      final port = await AndroidLocalAlarmPort.prepareForRevocation(
        encryptedInventoryVerified: true,
        installedAndPending: known,
      );
      await revokeAllDeviceNotices(
        ledger: ledger, revocationPort: port,
        workspaceId: stored.workspaceId, userId: stored.userId,
      );
    }
    await ledger.clear(
      workspaceId: stored.workspaceId, userId: stored.userId);
  }
  final optedIn = await consent.readScope();
  if (optedIn != null) {
    await consent.revoke(optedIn);
  }
}
