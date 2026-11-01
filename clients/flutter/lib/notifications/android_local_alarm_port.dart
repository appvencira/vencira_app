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

/// Preverified ID ownership survives repeated cancels in the same process.
/// A cancelled ID remains reserved to prevent a different task from reusing
/// it after a hash collision. Only a fresh verified inventory can reset it.
class AndroidNoticeIdRegistry {
  AndroidNoticeIdRegistry(Iterable<DeviceNoticeSlot> existing) {
    for (final slot in existing) {
      reserve(slot);
    }
  }

  final Map<int, String> _ownerById = {};

  int reserve(DeviceNoticeSlot slot) {
    final id = androidNoticeId(slot.key);
    final owner = _ownerById[id];
    if (owner != null && owner != slot.key) {
      throw StateError('Local notification ID collision');
    }
    _ownerById[id] = slot.key;
    return id;
  }

  int authorizedCancelId(DeviceNoticeSlot slot) {
    final id = androidNoticeId(slot.key);
    if (_ownerById[id] != slot.key) {
      throw StateError('Untracked local alarm cannot be cancelled');
    }
    return id;
  }
}

/// Real Android OS adapter: intentionally NOT initialized from main.dart.
///
/// Never construct without explicit consent, a verified encrypted inventory
/// and an authenticated current session. Inexact OS scheduling may be delayed.
class AndroidLocalAlarmPort implements DeviceNoticeAlarmPort {
  AndroidLocalAlarmPort._(
    this._plugin, this._location, this._registry,
  );

  final FlutterLocalNotificationsPlugin _plugin;
  final tz.Location _location;
  final AndroidNoticeIdRegistry _registry;

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
    final registry = AndroidNoticeIdRegistry(installedInventory);
    return AndroidLocalAlarmPort._(notifications, location, registry);
  }

  /// Cancellation-only path for logout, revoked notification permission or
  /// revoked account membership. Must be supplied a verified encrypted
  /// inventory (including pending journal keys) from the previous session.
  /// It never asks for a notification permission and cannot schedule on its
  /// own: callers must only pass this port to a revocation operation.
  static Future<AndroidLocalAlarmPort> prepareForRevocation({
    required bool encryptedInventoryVerified,
    required List<DeviceNoticeSlot> installedAndPending,
    FlutterLocalNotificationsPlugin? plugin,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android ||
        !encryptedInventoryVerified) {
      throw StateError('Android alarm revocation inventory not verified');
    }
    tzdata.initializeTimeZones();
    final location = tz.getLocation('Europe/Madrid');
    final notifications = plugin ?? FlutterLocalNotificationsPlugin();
    final initialized = await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    if (initialized != true) {
      throw StateError('Android alarm cancellation service unavailable');
    }
    return AndroidLocalAlarmPort._(
      notifications, location, AndroidNoticeIdRegistry(installedAndPending),
    );
  }

  @override
  Future<void> cancel(DeviceNoticeSlot slot) async {
    final id = _registry.authorizedCancelId(slot);
    // Keep the ID authorized so a cancellation can be retried after a lost
    // acknowledgement or a partial batch failure, without leaking an alarm.
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> schedule(DeviceNoticeSlot slot) async {
    final id = _registry.reserve(slot);
    final local = tz.TZDateTime(
      _location, slot.at.year, slot.at.month, slot.at.day,
      slot.at.hour, slot.at.minute,
    );
    if (!local.isAfter(tz.TZDateTime.now(_location)) ||
        local.year != slot.at.year || local.month != slot.at.month ||
        local.day != slot.at.day || local.hour != slot.at.hour) {
      throw StateError('Alarm day or civil time is not valid');
    }
    // Reserve ownership BEFORE the OS call: an alarm may be installed even
    // when the platform response is lost. The caller can then compensate by
    // cancelling this exact slot instead of leaving a stray notification.
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
  }
}
