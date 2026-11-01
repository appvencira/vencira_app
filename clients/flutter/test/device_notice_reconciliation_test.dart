import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';

const workspace = '11111111-1111-4111-8111-111111111111';
const otherWorkspace = '99999999-9999-4999-8999-999999999999';
const occurrence = '22222222-2222-4222-8222-222222222222';
const renewal = '33333333-3333-4333-8333-333333333333';

VenciraDeviceNoticePreview preview({
  String day = '2027-03-12',
  int generation = 1,
  bool hasNext = false,
  int count = 1,
}) => VenciraDeviceNoticePreview.fromJson({
  'from': '2027-03-08', 'through': '2027-03-31',
  'timezone': 'Europe/Madrid', 'count': count,
  'next': hasNext ? 'page2' : null,
  'capabilities': {
    'native_alarm_scheduling': false,
    'offline_storage': false, 'delivery': false,
  },
  'results': [{
    'id': occurrence, 'renewal_id': renewal,
    'scheduled_for': day, 'state': 'planned',
    'reason': 'Información confidencial de prueba',
    'control_question': false, 'generation': generation,
    'delivery_status': 'not_implemented',
  }],
});

DeviceNoticeDiff diff({
  required VenciraDeviceNoticePreview snapshot,
  List<DeviceNoticeSlot> existing = const [],
  bool permission = true,
  bool store = true,
  bool authorized = true,
  String tz = 'Europe/Madrid',
  DateTime? today,
  String ws = workspace,
  String user = '17',
}) => planDeviceNoticeReconciliation(
  preview: snapshot, workspaceId: ws, userId: user,
  existing: existing, today: today ?? DateTime(2027, 3, 8),
  deviceTimeZone: tz, permissionGranted: permission,
  encryptedInventoryReady: store,
  authorizedForNativeUse: authorized,
);

void main() {
  test('Preparation is side-effect-free and contains no PII', () {
    final result = diff(snapshot: preview());
    expect(result.cancel, isEmpty);
    expect(result.schedule, hasLength(1));
    final slot = result.schedule.single;
    expect(slot.at, DateTime(2027, 3, 12, 9));
    expect(slot.key, '$workspace/17/$occurrence/1');
    expect(slot.toString(), isNot(contains('Información confidencial')));
    expect(slot.key, isNot(contains('Información confidencial')));
  });

  test('Full repeated snapshot is idempotent', () {
    final first = diff(snapshot: preview());
    final second = diff(snapshot: preview(), existing: first.schedule);
    expect(second.cancel, isEmpty);
    expect(second.schedule, isEmpty);
  });

  test('Moved day cancels old alarm before scheduling replacement', () {
    final before = diff(snapshot: preview()).schedule;
    final change = diff(snapshot: preview(day: '2027-03-13'),
      existing: before);
    expect(change.cancel, hasLength(1));
    expect(change.schedule, hasLength(1));
    expect(change.cancel.single.key, change.schedule.single.key);
    expect(change.schedule.single.at, DateTime(2027, 3, 13, 9));
  });

  test('Changed generation cancels superseded alarm', () {
    final before = diff(snapshot: preview()).schedule;
    final change = diff(snapshot: preview(generation: 2), existing: before);
    expect(change.cancel, hasLength(1));
    expect(change.schedule, hasLength(1));
    expect(change.cancel.single.key, isNot(change.schedule.single.key));
  });

  test('Denied permission, rollout, storage or timezone requires revocation', () {
    final before = diff(snapshot: preview()).schedule;
    for (final options in <DeviceNoticeDiff>[
      diff(snapshot: preview(), existing: before, permission: false),
      diff(snapshot: preview(), existing: before, authorized: false),
      diff(snapshot: preview(), existing: before, store: false),
      diff(snapshot: preview(), existing: before, tz: 'UTC'),
    ]) {
      expect(options.cancel, hasLength(1));
      expect(options.schedule, isEmpty);
    }
  });

  test('Cross-tenant and user change revoke old identity', () {
    final before = diff(snapshot: preview()).schedule;
    final move = diff(snapshot: preview(), existing: before,
        ws: otherWorkspace, user: '18');
    expect(move.cancel, hasLength(1));
    expect(move.schedule, hasLength(1));
    expect(move.cancel.single.key, isNot(move.schedule.single.key));
  });

  test('Partial pagination fails closed instead of cancelling current alarms', () {
    final before = diff(snapshot: preview()).schedule;
    for (final snap in [preview(hasNext: true, count: 2),
                        preview(count: 2)]) {
      expect(() => diff(snapshot: snap, existing: before),
          throwsFormatException);
    }
  });

  test('Already elapsed alarm is not scheduled retroactively', () {
    final result = diff(snapshot: preview(day: '2027-03-08'),
        today: DateTime(2027, 3, 8, 10));
    expect(result.schedule, isEmpty);
  });

  test('Reject malformed scope and duplicate encrypted inventory', () {
    expect(() => diff(snapshot: preview(), user: '../escape'),
        throwsFormatException);
    final before = diff(snapshot: preview()).schedule.single;
    expect(() => diff(snapshot: preview(), existing: [before, before]),
        throwsFormatException);
  });
}
