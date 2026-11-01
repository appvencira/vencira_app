import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/device_notice_inventory.dart';
import 'package:vencira/notifications/device_notice_reconciliation.dart';

const ws = '11111111-1111-4111-8111-111111111111';
const otherWs = '99999999-9999-4999-8999-999999999999';
const occurrence = '22222222-2222-4222-8222-222222222222';

DeviceNoticeSlot slot({int generation = 1, String workspace = ws}) =>
    DeviceNoticeSlot(
      workspaceId: workspace, userId: '17', occurrenceId: occurrence,
      generation: generation, at: DateTime(2027, 3, 31, 9),
    );

void main() {
  test('Encrypted inventory codec stores no policy reference or reason', () {
    final json = encodeAlarmInventory(
      workspaceId: ws, userId: '17', slots: [slot()]);
    final rows = decodeAlarmInventory(
      json, workspaceId: ws, userId: '17');
    expect(rows, hasLength(1));
    expect(rows.single.key, slot().key);
    expect(rows.single.at, DateTime(2027, 3, 31, 9));
    expect(json, isNot(contains('customer_reference')));
    expect(json, isNot(contains('reason')));
    expect(json, isNot(contains('email')));
    expect(json, isNot(contains('policy')));
  });

  test('User or workspace mismatch fails rather than sharing inventory', () {
    final json = encodeAlarmInventory(
        workspaceId: ws, userId: '17', slots: [slot()]);
    expect(() => decodeAlarmInventory(
        json, workspaceId: otherWs, userId: '17'), throwsFormatException);
    expect(() => decodeAlarmInventory(
        json, workspaceId: ws, userId: '18'), throwsFormatException);
  });

  test('Stored encrypted scope cannot be silently replaced by another account',
      () {
    final encoded = encodeAlarmInventory(
        workspaceId: ws, userId: '17', slots: [slot()]);
    expect(() => verifyAlarmInventoryOwnership(
      encoded, workspaceId: ws, userId: '17'), returnsNormally);
    expect(() => verifyAlarmInventoryOwnership(
      encoded, workspaceId: ws, userId: '18'), throwsFormatException);
    expect(() => verifyAlarmInventoryOwnership(
      encoded, workspaceId: otherWs, userId: '17'), throwsFormatException);
    expect(() => verifyAlarmInventoryOwnership(
      null, workspaceId: ws, userId: '17'), returnsNormally);
  });

  test('Duplicate, cross-tenant or invalid generation cannot persist', () {
    expect(() => encodeAlarmInventory(
      workspaceId: ws, userId: '17', slots: [slot(), slot()],
    ), throwsFormatException);
    expect(() => encodeAlarmInventory(
      workspaceId: ws, userId: '17', slots: [slot(workspace: otherWs)],
    ), throwsFormatException);
    expect(() => encodeAlarmInventory(
      workspaceId: ws, userId: '17', slots: [slot(generation: 0)],
    ), throwsFormatException);
  });

  test('Malformed, over-capacity and reused occurrence are rejected', () {
    final clean = jsonDecode(encodeAlarmInventory(
      workspaceId: ws, userId: '17', slots: [slot()]))
        as Map<String, dynamic>;
    for (final bad in <String>[
      '{',
      jsonEncode({...clean, 'version': 2}),
      jsonEncode({...clean, 'slots': [clean['slots'][0], clean['slots'][0]]}),
      jsonEncode({...clean, 'slots': List.filled(501, clean['slots'][0])}),
      jsonEncode({...clean, 'slots': [
        {...(clean['slots'][0] as Map), 'at': '2027-03-32T09:00:00.000'},
      ]}),
    ]) {
      expect(() => decodeAlarmInventory(
        bad, workspaceId: ws, userId: '17'), throwsFormatException);
    }
  });
}
