// G15: explicit, synthetic, OFFLINE Android notification experiment.
// No backend calls, sessions, customer data or production scheduling.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

const bool g15LabEnabled = bool.fromEnvironment('VENCIRA_G15_LAB_BUILD');

class G15NoticePolicy {
  G15NoticePolicy();
  bool _explicitPermissionAction = false;
  bool _osGranted = false;

  void recordPermissionAction(bool granted) {
    _explicitPermissionAction = true;
    _osGranted = granted;
  }

  void updateCurrentPermission(bool granted) {
    // A user may revoke the OS permission outside the app at any time.
    _osGranted = granted;
  }

  bool get maySchedule =>
      _explicitPermissionAction && _osGranted && g15LabEnabled && !kReleaseMode;
}

class G15PhysicalNoticeCheck {
  G15PhysicalNoticeCheck({
    FlutterLocalNotificationsPlugin? notifications,
  }) : _plugin = notifications ?? FlutterLocalNotificationsPlugin();

  static const int _id = 150015;
  static const String _channel = 'vencira_g15_synthetic_v1';

  final FlutterLocalNotificationsPlugin _plugin;
  final G15NoticePolicy policy = G15NoticePolicy();
  bool _initialized = false;

  void _requireLab() {
    if (!g15LabEnabled || kReleaseMode || !Platform.isAndroid) {
      throw StateError('G15_ANDROID_DEBUG_ONLY');
    }
  }

  Future<AndroidFlutterLocalNotificationsPlugin> _android() async {
    _requireLab();
    if (!_initialized) {
      final ready = await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      if (ready != true) throw StateError('G15_PLUGIN_INIT_DENIED');
      _initialized = true;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) throw StateError('G15_NOT_ANDROID_PLUGIN');
    return android;
  }

  /// Only invoked from the explicit UI permission button.
  Future<List<String>> requestPermission() async {
    final android = await _android();
    final decision = await android.requestNotificationsPermission();
    final current = await android.areNotificationsEnabled();
    policy.recordPermissionAction(decision == true && current == true);
    return [
      'G15_OS_PERMISSION_GRANTED=${current == true ? "YES" : "NO"}',
      'G15_EXPLICIT_OPT_IN=${policy.maySchedule ? "YES" : "NO"}',
    ];
  }

  Future<List<String>> checkPermission() async {
    final android = await _android();
    final current = await android.areNotificationsEnabled();
    policy.updateCurrentPermission(current == true);
    return [
      'G15_OS_PERMISSION_CURRENT=${current == true ? "YES" : "NO"}',
      'G15_SCHEDULE_GATE=${policy.maySchedule ? "OPEN" : "LOCKED"}',
    ];
  }

  Future<List<String>> scheduleSyntheticNotice() async {
    final android = await _android();
    policy.updateCurrentPermission(
        await android.areNotificationsEnabled() == true);
    if (!policy.maySchedule) throw StateError('G15_PERMISSION_REQUIRED');
    final zone = await FlutterTimezone.getLocalTimezone();
    if (zone.identifier != 'Europe/Madrid') {
      throw StateError('G15_DEVICE_ZONE_UNSUPPORTED');
    }
    tzdata.initializeTimeZones();
    final madrid = tz.getLocation('Europe/Madrid');
    final when = tz.TZDateTime.now(madrid).add(const Duration(minutes: 15));
    // The system may deliver late due to OEM power restrictions. Inexact
    // scheduling deliberately requires NO exact-alarm exemption.
    await _plugin.zonedSchedule(
      id: _id,
      scheduledDate: when,
      title: 'VENCIRA · prueba G15',
      body: 'Aviso sintético. No contiene datos reales.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channel, 'Pruebas G15',
          channelDescription: 'Pruebas aisladas de avisos Android',
          visibility: NotificationVisibility.secret,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return [
      'G15_SYNTHETIC_INEXACT_SCHEDULE=OK',
      'G15_EXPECT_DELAYED_DELIVERY=YES',
      'G15_NO_CUSTOMER_DATA=1',
    ];
  }

  /// Cancellation is always available, even when permission has been revoked.
  Future<List<String>> cancelSyntheticNotice() async {
    await _android();
    await _plugin.cancel(id: _id);
    return ['G15_SYNTHETIC_CANCEL=OK'];
  }

  Future<List<String>> pendingState() async {
    await _android();
    final pending = await _plugin.pendingNotificationRequests();
    final exists = pending.any((request) => request.id == _id);
    return [
      'G15_PENDING_SYNTHETIC=${exists ? "YES" : "NO"}',
      'G15_PENDING_IS_NOT_DELIVERY_PROOF=1',
    ];
  }
}
