import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'device_notice_reconciliation.dart';
import 'device_notice_sync.dart';

/// Stable 31-bit identifier for the Android notification system.
///
/// A hash alone is not globally collision-free: the adapter MUST inspect the
/// encrypted inventory of all installed keys before sending to Android.
int androidNoticeId(String opaqueKey) {
  if (opaqueKey.isEmpty) throw const FormatException('Empty alarm identity');
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(opaqueKey)) {
    hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

/// Real Android OS adapter: intentionally NOT initialized from main.dart.
///
/// Never construct without explicit consent, a verified encrypted inventory
/// and an authenticated current session. Inexact OS scheduling may be delayed.
class AndroidLocalAlarmPort implements DeviceNoticeAlarmPort {
  AndroidLocalAlarmPort._(
    this._plugin, this._location, this._idOwners,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final tz.Location _location;
  final Map<int, String> _idOwners;

  static Future<AndroidLocalAlarmPort> prepare({
    required bool explicitUserOptIn,
    required bool encryptedInventoryVerified,
    required List<DeviceNoticeSlot> installedInventory,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        !explicitUserOptIn || !encryptedInventoryVerified) {
      throw StateError('Android local alarms not authorized');
    }
    final zone = await FlutterTimezone.getLocalTimezone();
    if (zone.identifier != 'Europe/Madrid') {
      throw StateError('Device timezone mismatch; manual review required');
    }
    tzdata.initializeTimeZones();
    final location = tz.getLocation('Europe/Madrid');
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    final result = await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (result != true) throw StateError('Notification plugin not initialized');
    final android = notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null || await android.areNotificationsEnabled() != true) {
      // Permission prompts MUST be a separate explicit UI action.
      throw StateError('Android notification permission not granted');
    }
    final ids = <int, String>{};
    for (final slot in installedInventory) {
      final id = androidNoticeId(slot.key);
      if (ids.containsKey(id)) {
        throw StateError('Android notification ID collision');
      }
      ids[id] = slot.key;
    }
    return AndroidLocalAlarmPort._(notifications, location, ids);
  }

  int _verifiedId(DeviceNoticeSlot slot) {
    final id = androidNoticeId(slot.key);
    final owner = _idOwners[id];
    if (owner != null && owner != slot.key) {
      throw StateError('Notification ID belongs to a different alarm');
    }
    return id;
  }

  @override
  Future<void> cancel(DeviceNoticeSlot slot) async {
    final id = _verifiedId(slot);
    if (_idOwners[id] != slot.key) {
      throw StateError('Untracked alarm cannot be cancelled silently');
    }
    await _plugin.cancel(id: id);
    _idOwners.remove(id);
  }

  @override
  Future<void> schedule(DeviceNoticeSlot slot) async {
    final id = _verifiedId(slot);
    final local = tz.TZDateTime(
      _location, slot.at.year, slot.at.month, slot.at.day,
      slot.at.hour, slot.at.minute,
    );
    if (!local.isAfter(tz.TZDateTime.now(_location)) ||
        local.year != slot.at.year || local.month != slot.at.month ||
        local.day != slot.at.day || local.hour != slot.at.hour) {
      throw StateError('Alarm day or civil time is not valid');
    }
    await _plugin.zonedSchedule(
      id: id, scheduledDate: local,
      title: 'VENCIRA',
      body: 'Tienes una tarea pendiente en la aplicación.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'vencira_internal_tasks_v1',
          'Avisos internos de VENCIRA',
          channelDescription: 'Recordatorios locales sin datos de clientes',
          visibility: NotificationVisibility.secret,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    _idOwners[id] = slot.key;
  }
}
