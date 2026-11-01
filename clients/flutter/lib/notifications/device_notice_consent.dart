import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'device_alarm_scope.dart';

const _key = 'vencira.device.notice.consent.v1';

String encodeDeviceNoticeConsent(DeviceAlarmScope scope) => jsonEncode({
  'version': 1, 'workspace_id': scope.workspaceId,
  'user_id': scope.userId, 'enabled': true,
});

DeviceAlarmScope? decodeDeviceNoticeConsent(String? raw) {
  if (raw == null) return null;
  dynamic data;
  try {
    data = jsonDecode(raw);
  } on FormatException {
    throw const FormatException('Invalid encrypted notification consent');
  }
  if (data is! Map<String, dynamic> ||
      data.length != 4 || data['version'] != 1 ||
      data['enabled'] != true ||
      data['workspace_id'] is! String || data['user_id'] is! String) {
    throw const FormatException('Unsupported notification consent');
  }
  return DeviceAlarmScope(
    workspaceId: data['workspace_id'] as String,
    userId: data['user_id'] as String);
}

/// Requires explicit UI action after OS permission approval. Not invoked by
/// app startup. Persisted only in Android secure storage, never preferences.
class EncryptedDeviceNoticeConsent {
  EncryptedDeviceNoticeConsent({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            storageNamespace: 'vencira_device_consent_v1',
            resetOnError: false,
            migrateOnAlgorithmChange: false,
          ),
        );

  final FlutterSecureStorage _storage;

  Future<DeviceAlarmScope?> readScope() async =>
      decodeDeviceNoticeConsent(await _storage.read(key: _key));

  Future<bool> isEnabled(DeviceAlarmScope scope) async =>
      await readScope() == scope;

  Future<void> grant(DeviceAlarmScope scope) async {
    final old = await readScope();
    if (old != null && old != scope) {
      throw StateError('Old account consent must first be revoked');
    }
    final record = encodeDeviceNoticeConsent(scope);
    await _storage.write(key: _key, value: record);
    if (await _storage.read(key: _key) != record) {
      throw StateError('Encrypted device consent not verified');
    }
  }

  Future<void> revoke(DeviceAlarmScope scope) async {
    final existing = await readScope();
    if (existing == null) return;
    if (existing != scope) {
      throw StateError('Cannot revoke consent of a different user');
    }
    await _storage.delete(key: _key);
    if (await _storage.read(key: _key) != null) {
      throw StateError('Encrypted consent still persisted');
    }
  }
}
