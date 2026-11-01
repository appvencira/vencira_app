import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/notifications/device_alarm_scope.dart';
import 'package:vencira/notifications/device_notice_consent.dart';
import 'package:vencira/notifications/device_notice_inventory.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';
import 'package:vencira/notifications/device_notice_session_coordinator.dart';
import 'package:vencira/notifications/device_notice_sync.dart';

const wsA = '11111111-1111-4111-8111-111111111111';
const wsB = '99999999-9999-4999-8999-999999999999';
const reminderId = '22222222-2222-4222-8222-222222222222';
const renewalId = '33333333-3333-4333-8333-333333333333';

DeviceNoticeSlot slot(String ws, String user, {int day = 12}) =>
    DeviceNoticeSlot(workspaceId: ws, userId: user,
      occurrenceId: reminderId, generation: 1,
      at: DateTime(2027, 3, day, 9));

VenciraDeviceNoticePreview notice() =>
    VenciraDeviceNoticePreview.fromJson({
  'from': '2027-03-08', 'through': '2027-04-07',
  'timezone': 'Europe/Madrid', 'count': 1, 'next': null,
  'capabilities': {
    'native_alarm_scheduling': false,
    'offline_storage': false, 'delivery': false,
  },
  'results': [{
    'id': reminderId, 'renewal_id': renewalId,
    'scheduled_for': '2027-03-12', 'state': 'planned',
    'reason': 'Synthetic task', 'control_question': false,
    'generation': 1, 'delivery_status': 'not_implemented',
  }],
});

class Api implements VenciraApi {
  String user = '17';
  List<VenciraWorkspace> memberships = const [
    VenciraWorkspace(id: wsA, name: 'A', role: 'owner'),
    VenciraWorkspace(id: wsB, name: 'B', role: 'member'),
  ];
  Completer<VenciraDeviceNoticePreview>? pendingPreview;
  int fetchedPreviews = 0;

  @override
  Future<String> fetchAuthenticatedUserId() async => user;
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => memberships;
  @override
  Future<VenciraDeviceNoticePreview> fetchDeviceNoticePreview(
      String workspace, DateTime from, DateTime through, {int page = 1}) {
    fetchedPreviews++;
    if (pendingPreview != null) return pendingPreview!.future;
    return Future.value(notice());
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class Vault implements DeviceNoticeVault {
  DeviceAlarmScope? scope;
  List<DeviceNoticeSlot> committed = [];
  List<DeviceNoticeSlot>? pending;
  final events = <String>[];
  @override
  Future<DeviceAlarmScope?> readStoredScope() async => scope;
  void guard(String workspace, String user) {
    if (scope != null && scope != DeviceAlarmScope(
        workspaceId: workspace, userId: user)) {
      throw const FormatException('Cross-account vault');
    }
  }
  @override
  Future<List<DeviceNoticeSlot>> read({
    required String workspaceId, required String userId,
  }) async {
    guard(workspaceId, userId);
    return List.of(committed);
  }
  @override
  Future<List<DeviceNoticeSlot>?> readPending({
    required String workspaceId, required String userId,
  }) async {
    guard(workspaceId, userId);
    return pending == null ? null : List.of(pending!);
  }
  @override
  Future<void> write({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    guard(workspaceId, userId);
    scope = DeviceAlarmScope(workspaceId: workspaceId, userId: userId);
    committed = List.of(slots);
    events.add('write');
  }
  @override
  Future<void> writePending({
    required String workspaceId, required String userId,
    required List<DeviceNoticeSlot> slots,
  }) async {
    guard(workspaceId, userId);
    if (pending != null) throw StateError('Pending recovery');
    scope = DeviceAlarmScope(workspaceId: workspaceId, userId: userId);
    pending = List.of(slots);
    events.add('journal');
  }
  @override
  Future<void> clearPending() async {
    pending = null;
    events.add('clear-pending');
  }
  @override
  Future<void> clear({
    required String workspaceId, required String userId,
  }) async {
    guard(workspaceId, userId);
    if (pending != null) throw StateError('Cannot clear pending');
    committed.clear();
    scope = null;
    events.add('clear');
  }
}

class Consent implements DeviceNoticeConsentPort {
  DeviceAlarmScope? granted;
  @override
  Future<DeviceAlarmScope?> readScope() async => granted;
  @override
  Future<bool> isEnabled(DeviceAlarmScope scope) async => granted == scope;
  @override
  Future<void> grant(DeviceAlarmScope scope) async {
    if (granted != null && granted != scope) throw StateError('Old consent');
    granted = scope;
  }
  @override
  Future<void> revoke(DeviceAlarmScope scope) async {
    if (granted != null && granted != scope) throw StateError('Wrong owner');
    granted = null;
  }
}

class Port implements DeviceNoticeAlarmPort {
  Port(this.calls, {this.cannotCancel = false});
  final List<String> calls;
  final bool cannotCancel;
  @override
  Future<void> cancel(DeviceNoticeSlot item) async {
    calls.add('cancel:${item.userId}:${item.workspaceId}');
    if (cannotCancel) throw StateError('Android cancellation failed');
  }
  @override
  Future<void> schedule(DeviceNoticeSlot item) async {
    calls.add('schedule:${item.userId}:${item.workspaceId}');
  }
}

void main() {
  late Api api;
  late Vault vault;
  late Consent consent;
  late List<String> actions;
  bool denyCancel = false;
  DeviceNoticeSessionCoordinator build({bool approved = false}) =>
      DeviceNoticeSessionCoordinator(
        api: api, vault: vault, consent: consent,
        portFactory: (slots, cancellationOnly) async =>
            Port(actions, cannotCancel: cancellationOnly && denyCancel),
        clock: () => DateTime(2027, 3, 8, 7),
        nativeRolloutApproved: approved,
      );

  setUp(() {
    api = Api();
    vault = Vault();
    consent = Consent();
    actions = [];
    denyCancel = false;
  });

  test('Fail-closed by default even after valid authenticated bind', () async {
    final coordinator = build();
    await coordinator.bindAuthenticatedWorkspace(wsA);
    await expectLater(coordinator.enableFromExplicitAction(),
        throwsStateError);
    await expectLater(coordinator.synchronizeAfterExplicitAction(),
        throwsStateError);
    expect(api.fetchedPreviews, 0);
    expect(actions, isEmpty);
    expect(consent.granted, isNull);
  });

  test('Unrecognized workspace and stale authenticated identity rejected', () async {
    final coordinator = build(approved: true);
    api.memberships = const [VenciraWorkspace(
        id: wsA, name: 'A', role: 'member')];
    await expectLater(coordinator.bindAuthenticatedWorkspace(wsB),
        throwsStateError);
    await coordinator.bindAuthenticatedWorkspace(wsA);
    api.user = '18';
    await expectLater(coordinator.enableFromExplicitAction(),
        throwsStateError);
    expect(consent.granted, isNull);
  });

  test('Explicit opt-in and preview create only authorized workspace alarms',
      () async {
    final coordinator = build(approved: true);
    await coordinator.bindAuthenticatedWorkspace(wsA);
    await coordinator.enableFromExplicitAction();
    await coordinator.synchronizeAfterExplicitAction();
    expect(consent.granted, DeviceAlarmScope(
        workspaceId: wsA, userId: '17'));
    expect(vault.committed, hasLength(1));
    expect(actions, ['schedule:17:$wsA']);
    await coordinator.synchronizeAfterExplicitAction();
    expect(actions, ['schedule:17:$wsA']); // idempotent
  });

  test('New workspace revokes old encrypted alarm and consent', () async {
    final coordinator = build(approved: true);
    await coordinator.bindAuthenticatedWorkspace(wsA);
    await coordinator.enableFromExplicitAction();
    await coordinator.synchronizeAfterExplicitAction();
    await coordinator.bindAuthenticatedWorkspace(wsB);
    expect(actions, ['schedule:17:$wsA', 'cancel:17:$wsA']);
    expect(vault.committed, isEmpty);
    expect(vault.scope, isNull);
    expect(consent.granted, isNull);
    await expectLater(coordinator.synchronizeAfterExplicitAction(),
        throwsStateError);
  });

  test('Another login revokes previous user after app restart', () async {
    vault.scope = DeviceAlarmScope(workspaceId: wsA, userId: '17');
    vault.committed = [slot(wsA, '17')];
    consent.granted = vault.scope;
    api.user = '18';
    final coordinator = build();
    await coordinator.bindAuthenticatedWorkspace(wsB);
    expect(actions, ['cancel:17:$wsA']);
    expect(vault.committed, isEmpty);
    expect(consent.granted, isNull);
  });

  test('Failed cancellation blocks account switch and preserves journal',
      () async {
    vault.scope = DeviceAlarmScope(workspaceId: wsA, userId: '17');
    vault.committed = [slot(wsA, '17')];
    denyCancel = true;
    api.user = '18';
    final coordinator = build();
    await expectLater(coordinator.bindAuthenticatedWorkspace(wsB),
        throwsStateError);
    expect(vault.pending, isNotNull);
    expect(vault.scope, DeviceAlarmScope(
        workspaceId: wsA, userId: '17'));
  });

  test('Logout revokes before clearing encrypted store, even with no active bind',
      () async {
    vault.scope = DeviceAlarmScope(workspaceId: wsA, userId: '17');
    vault.committed = [slot(wsA, '17')];
    consent.granted = vault.scope;
    final coordinator = build();
    await coordinator.revokeBeforeLogout();
    expect(vault.scope, isNull);
    expect(vault.pending, isNull);
    expect(consent.granted, isNull);
    expect(actions, ['cancel:17:$wsA']);
  });

  test('Pending preview cannot schedule after logout queued behind fetch',
      () async {
    final coordinator = build(approved: true);
    await coordinator.bindAuthenticatedWorkspace(wsA);
    await coordinator.enableFromExplicitAction();
    api.pendingPreview = Completer<VenciraDeviceNoticePreview>();
    final syncing = coordinator.synchronizeAfterExplicitAction();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final logout = coordinator.revokeBeforeLogout();
    api.pendingPreview!.complete(notice());
    await syncing;
    await logout;
    expect(actions, ['schedule:17:$wsA', 'cancel:17:$wsA']);
    expect(vault.committed, isEmpty);
  });

  test('Preview auth change during fetch blocks new notifications', () async {
    final coordinator = build(approved: true);
    await coordinator.bindAuthenticatedWorkspace(wsA);
    await coordinator.enableFromExplicitAction();
    api.pendingPreview = Completer<VenciraDeviceNoticePreview>();
    final syncing = coordinator.synchronizeAfterExplicitAction();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    api.user = '18';
    api.pendingPreview!.complete(notice());
    await expectLater(syncing, throwsStateError);
    expect(actions, isEmpty);
  });
}
