import 'dart:async';

import '../api/vencira_api.dart';
import 'device_alarm_scope.dart';
import 'device_notice_consent.dart';
import 'device_notice_inventory.dart';
import 'device_notice_reconciliation.dart';
import 'device_notice_sync.dart';
import 'device_notice_transaction.dart';

typedef DeviceAlarmPortFactory = Future<DeviceNoticeAlarmPort> Function(
    List<DeviceNoticeSlot> installedAndPending, bool cancellationOnly);

/// Serialized, server-identity-bound operations for one authenticated app
/// session. No work is scheduled automatically; rollout remains disabled
/// unless explicitly approved at construction and by a user consent action.
class DeviceNoticeSessionCoordinator {
  DeviceNoticeSessionCoordinator({
    required VenciraApi api,
    required DeviceNoticeVault vault,
    required DeviceNoticeConsentPort consent,
    required DeviceAlarmPortFactory portFactory,
    required DateTime Function() clock,
    bool nativeRolloutApproved = false,
  }) : _api = api, _vault = vault, _consent = consent,
       _portFactory = portFactory, _clock = clock,
       _nativeRolloutApproved = nativeRolloutApproved;

  final VenciraApi _api;
  final DeviceNoticeVault _vault;
  final DeviceNoticeConsentPort _consent;
  final DeviceAlarmPortFactory _portFactory;
  final DateTime Function() _clock;
  final bool _nativeRolloutApproved;
  DeviceAlarmScope? _active;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() work) {
    final previous = _tail;
    final gate = Completer<void>();
    _tail = gate.future;
    return () async {
      await previous;
      try {
        return await work();
      } finally {
        gate.complete();
      }
    }();
  }

  /// Validate the session against BOTH authenticated identity and workspace
  /// membership, not a stale client-selected workspace or owner-only report.
  Future<DeviceAlarmScope> _verify(String workspaceId) async {
    final userId = await _api.fetchAuthenticatedUserId();
    final workspaces = await _api.fetchWorkspaces();
    if (!workspaces.any((w) => w.id == workspaceId)) {
      throw StateError('Session has no membership in selected workspace');
    }
    return DeviceAlarmScope(workspaceId: workspaceId, userId: userId);
  }

  Future<List<DeviceNoticeSlot>> _knownAlarms(DeviceAlarmScope scope) async {
    final committed = await _vault.read(
        workspaceId: scope.workspaceId, userId: scope.userId);
    final pending = await _vault.readPending(
        workspaceId: scope.workspaceId, userId: scope.userId);
    return [...committed, ...?pending];
  }

  Future<void> _revoke(DeviceAlarmScope scope) async {
    final known = await _knownAlarms(scope);
    if (known.isNotEmpty) {
      final port = await _portFactory(known, true);
      await revokeAllDeviceNotices(
        ledger: _vault, revocationPort: port,
        workspaceId: scope.workspaceId, userId: scope.userId);
    }
    // Clearing secure storage or consent BEFORE native cancellation would
    // discard the only recoverable identity of OS alarms.
    await _vault.clear(
        workspaceId: scope.workspaceId, userId: scope.userId);
    await _consent.revoke(scope);
  }

  Future<void> _revokeOldAccounts(DeviceAlarmScope next) async {
    final stored = await _vault.readStoredScope();
    if (stored != null && stored != next) {
      await _revoke(stored);
    }
    final consentScope = await _consent.readScope();
    if (consentScope != null && consentScope != next) {
      // A consent-only record is safe to clear if its alarm inventory was
      // already removed. Otherwise _revoke() fails closed above.
      await _consent.revoke(consentScope);
    }
    if (_active != null && _active != next) {
      await _revoke(_active!);
    }
  }

  /// Called after a successful login/workspace selection. There are NO alarm
  /// side effects for a newly selected account. Any previous account must
  /// first be revoked, including its pending journal after an app crash.
  Future<void> bindAuthenticatedWorkspace(String workspaceId) =>
      _serialize(() async {
        final next = await _verify(workspaceId);
        await _revokeOldAccounts(next);
        _active = next;
      });

  /// Explicit user choice only. The OS port must check that platform
  /// permission is already granted; this function never prompts for it.
  /// Native rollout stays OFF in VENCIRA's current app composition.
  Future<void> enableFromExplicitAction() => _serialize(() async {
    final scope = _active;
    if (scope == null || !_nativeRolloutApproved) {
      throw StateError('Device notices not released or no active session');
    }
    if (await _verify(scope.workspaceId) != scope) {
      throw StateError('Authenticated session changed');
    }
    final known = await _knownAlarms(scope);
    await _portFactory(known, false); // Check OS permissions before consent.
    await _consent.grant(scope);
  });

  /// Poll a complete server preview ONLY after opt-in. Lock serializes login,
  /// server reconciliation and logout, preventing stale responses from
  /// installing notifications for an account already selected away from.
  Future<void> synchronizeAfterExplicitAction() => _serialize(() async {
    final scope = _active;
    if (scope == null || !_nativeRolloutApproved ||
        !await _consent.isEnabled(scope)) {
      throw StateError('Device notification activation not authorized');
    }
    if (await _verify(scope.workspaceId) != scope) {
      throw StateError('Authenticated session changed');
    }
    final now = _clock();
    final from = DateTime(now.year, now.month, now.day);
    final through = DateTime(now.year, now.month, now.day + 30);
    final preview = await _api.fetchDeviceNoticePreview(
        scope.workspaceId, from, through);
    if (preview.hasNext || preview.total != preview.items.length) {
      throw StateError('Incomplete authorized notice snapshot');
    }
    // If a previous transaction was interrupted, first cancel all touched
    // OS IDs before deriving the new complete snapshot.
    final knownBefore = await _knownAlarms(scope);
    final pending = await _vault.readPending(
        workspaceId: scope.workspaceId, userId: scope.userId);
    if (pending != null) {
      final cancellationPort = await _portFactory(knownBefore, true);
      await recoverInterruptedDeviceNotices(
        ledger: _vault, port: cancellationPort,
        workspaceId: scope.workspaceId, userId: scope.userId);
    }
    final existing = await _vault.read(
        workspaceId: scope.workspaceId, userId: scope.userId);
    final diff = planDeviceNoticeReconciliation(
      preview: preview, workspaceId: scope.workspaceId,
      userId: scope.userId, existing: existing,
      today: now, deviceTimeZone: 'Europe/Madrid',
      permissionGranted: true, encryptedInventoryReady: true,
      authorizedForNativeUse: true,
    );
    if (diff.cancel.isEmpty && diff.schedule.isEmpty) return;
    final port = await _portFactory(existing, false);
    await applyDurableDeviceNoticeDiff(
      ledger: _vault, port: port,
      workspaceId: scope.workspaceId, userId: scope.userId,
      diff: diff);
  });

  Future<void> disableFromExplicitAction() => _serialize(() async {
    final scope = _active;
    if (scope != null) await _revoke(scope);
    _active = null;
  });

  /// Must complete BEFORE the server logout or workspace switch removes
  /// authority/context. If cancellation fails, abort logout and preserve the
  /// secure journal so the app can retry safely.
  Future<void> revokeBeforeLogout() => _serialize(() async {
    final stored = await _vault.readStoredScope();
    if (stored != null) await _revoke(stored);
    if (_active != null && _active != stored) await _revoke(_active!);
    final consentScope = await _consent.readScope();
    if (consentScope != null) await _consent.revoke(consentScope);
    _active = null;
  });
}
