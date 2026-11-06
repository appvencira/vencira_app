import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'device_notice_reconciliation.dart';
import 'device_alarm_scope.dart';
import 'device_notice_transaction.dart';

const _maxInventory = 500;
const _storageKey = 'vencira.device.alarms.v1';
const _pendingKey = 'vencira.device.alarms.pending.v1';
final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
    r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
final _userId = RegExp(r'^[0-9]{1,20}$');

/// All persisted records are opaque IDs and times, never names or reasons.
/// This codec is pure; only [EncryptedAlarmInventory] touches Android storage.
String encodeAlarmInventory({
  required String workspaceId,
  required String userId,
  required List<DeviceNoticeSlot> slots,
}) {
  if (!_uuid.hasMatch(workspaceId) || !_userId.hasMatch(userId) ||
      slots.length > _maxInventory) {
    throw const FormatException('Invalid alarm inventory scope');
  }
  final keys = <String>{};
  final rows = <Map<String, Object>>[];
  for (final slot in slots) {
    if (slot.workspaceId != workspaceId || slot.userId != userId ||
        !_uuid.hasMatch(slot.occurrenceId) ||
        slot.generation <= 0 || slot.generation > 2147483647 ||
        slot.at.isUtc || slot.at.year < 2000 || slot.at.year > 2100 ||
        !keys.add(slot.key)) {
      throw const FormatException('Invalid alarm inventory record');
    }
    rows.add({
      'occurrence_id': slot.occurrenceId,
      'generation': slot.generation,
      'at': slot.at.toIso8601String(),
    });
  }
  return jsonEncode({
    'version': 1,
    'workspace_id': workspaceId,
    'user_id': userId,
    'slots': rows,
  });
}

/// Reject a record for another user, a corrupted ciphertext, duplicates or
/// a date the native scheduler could not reproduce unambiguously.
List<DeviceNoticeSlot> decodeAlarmInventory(
  String encoded, {
  required String workspaceId,
  required String userId,
}) {
  if (!_uuid.hasMatch(workspaceId) || !_userId.hasMatch(userId) ||
      encoded.length > 100000) {
    throw const FormatException('Invalid inventory request');
  }
  dynamic parsed;
  try {
    parsed = jsonDecode(encoded);
  } on FormatException {
    throw const FormatException('Damaged encrypted inventory');
  }
  if (parsed is! Map<String, dynamic> ||
      parsed['version'] != 1 ||
      parsed['workspace_id'] != workspaceId ||
      parsed['user_id'] != userId ||
      parsed['slots'] is! List ||
      (parsed['slots'] as List).length > _maxInventory) {
    throw const FormatException('Cross-session or invalid inventory');
  }
  final keys = <String>{};
  final slots = <DeviceNoticeSlot>[];
  for (final record in parsed['slots'] as List) {
    if (record is! Map<String, dynamic> ||
        record['occurrence_id'] is! String ||
        !_uuid.hasMatch(record['occurrence_id'] as String) ||
        record['generation'] is! int ||
        (record['generation'] as int) <= 0 ||
        record['at'] is! String) {
      throw const FormatException('Invalid inventory record');
    }
    final text = record['at'] as String;
    final at = DateTime.tryParse(text);
    if (at == null || at.isUtc || at.toIso8601String() != text ||
        at.year < 2000 || at.year > 2100) {
      throw const FormatException('Noncanonical alarm time');
    }
    final slot = DeviceNoticeSlot(
      workspaceId: workspaceId, userId: userId,
      occurrenceId: record['occurrence_id'] as String,
      generation: record['generation'] as int, at: at,
    );
    if (!keys.add(slot.key)) {
      throw const FormatException('Duplicated alarm inventory');
    }
    slots.add(slot);
  }
  return List.unmodifiable(slots);
}

/// Never replace encrypted records belonging to a different account.
/// Stored content is authenticated by Android's encrypted storage and then
/// fully parsed against the requested tenant/session before overwriting.
void verifyAlarmInventoryOwnership(
  String? encryptedRecord, {
  required String workspaceId, required String userId,
}) {
  if (encryptedRecord == null) return;
  decodeAlarmInventory(
    encryptedRecord, workspaceId: workspaceId, userId: userId);
}

/// Read authenticated scope metadata from a verified secure-storage record,
/// never from an untrusted UI preference. The stored payload is still checked
/// against itself with the strict inventory decoder before use.
DeviceAlarmScope? decodeStoredAlarmScope(String? encoded) {
  if (encoded == null) return null;
  dynamic raw;
  try {
    raw = jsonDecode(encoded);
  } on FormatException {
    throw const FormatException('Corrupt stored alarm scope');
  }
  if (raw is! Map<String, dynamic> ||
      raw['workspace_id'] is! String || raw['user_id'] is! String) {
    throw const FormatException('Invalid stored alarm scope');
  }
  final scope = DeviceAlarmScope(
    workspaceId: raw['workspace_id'] as String,
    userId: raw['user_id'] as String,
  );
  decodeAlarmInventory(encoded,
    workspaceId: scope.workspaceId, userId: scope.userId);
  return scope;
}

/// Explicitly scoped encrypted store. No preference, JSON cache, or backup
/// fallback. Callers must revoke native OS alarms before clearing on logout.
abstract class DeviceNoticeVault implements DeviceAlarmLedger {
  Future<DeviceAlarmScope?> readStoredScope();
  Future<void> clear({
    required String workspaceId, required String userId,
  });
}

class EncryptedAlarmInventory implements DeviceNoticeVault {
  EncryptedAlarmInventory({
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'vencira_local_alarm_inventory_v1',
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
  );

  final FlutterSecureStorage _storage;

  Future<DeviceAlarmScope?> readStoredScope() async {
    final committed = decodeStoredAlarmScope(
      await _storage.read(key: _storageKey));
    final pending = decodeStoredAlarmScope(
      await _storage.read(key: _pendingKey));
    if (committed != null && pending != null && committed != pending) {
      throw const FormatException('Cross-account alarm journal conflict');
    }
    return pending ?? committed;
  }


  Future<List<DeviceNoticeSlot>> read({
    required String workspaceId, required String userId,
  }) async {
    final encoded = await _storage.read(key: _storageKey);
    if (encoded == null) return const [];
    return decodeAlarmInventory(
      encoded, workspaceId: workspaceId, userId: userId);
  }

  Future<void> write({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    final encoded = encodeAlarmInventory(
      workspaceId: workspaceId, userId: userId, slots: slots);
    verifyAlarmInventoryOwnership(
      await _storage.read(key: _storageKey),
      workspaceId: workspaceId, userId: userId);
    verifyAlarmInventoryOwnership(
      await _storage.read(key: _pendingKey),
      workspaceId: workspaceId, userId: userId);
    await _storage.write(key: _storageKey, value: encoded);
    final verified = await _storage.read(key: _storageKey);
    if (verified != encoded) {
      throw StateError('Alarm inventory persistence not verified');
    }
  }

  @override
  Future<List<DeviceNoticeSlot>?> readPending({
    required String workspaceId, required String userId,
  }) async {
    final encoded = await _storage.read(key: _pendingKey);
    if (encoded == null) return null;
    return decodeAlarmInventory(
      encoded, workspaceId: workspaceId, userId: userId);
  }

  @override
  Future<void> writePending({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    final encoded = encodeAlarmInventory(
      workspaceId: workspaceId, userId: userId, slots: slots);
    // Do not overwrite unresolved journals; recovery must complete first.
    verifyAlarmInventoryOwnership(
      await _storage.read(key: _storageKey),
      workspaceId: workspaceId, userId: userId);
    if (await _storage.read(key: _pendingKey) != null) {
      throw StateError('Alarm recovery required before scheduling');
    }
    await _storage.write(key: _pendingKey, value: encoded);
    if (await _storage.read(key: _pendingKey) != encoded) {
      throw StateError('Encrypted pending alarm journal not verified');
    }
  }

  @override
  Future<void> clearPending() => _storage.delete(key: _pendingKey);

  /// Only permitted after successful native cancellation of every alarm.
  /// Never clear an unresolved journal to suppress a scheduling error.
  Future<void> clear({
    required String workspaceId, required String userId,
  }) async {
    if (await _storage.read(key: _pendingKey) != null) {
      throw StateError('Cancel journalled alarms before clearing keys');
    }
    verifyAlarmInventoryOwnership(
      await _storage.read(key: _storageKey),
      workspaceId: workspaceId, userId: userId);
    await _storage.delete(key: _storageKey);
  }
}
