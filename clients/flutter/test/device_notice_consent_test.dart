import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/device_alarm_scope.dart';
import 'package:vencira/notifications/device_notice_consent.dart';

const workspace = '11111111-1111-4111-8111-111111111111';

void main() {
  test('Consent is strictly scoped to an authenticated user', () {
    final owner = DeviceAlarmScope(workspaceId: workspace, userId: '17');
    final encoded = encodeDeviceNoticeConsent(owner);
    expect(decodeDeviceNoticeConsent(encoded), owner);
    expect(decodeDeviceNoticeConsent(null), isNull);
    expect(decodeDeviceNoticeConsent(encoded),
      isNot(DeviceAlarmScope(workspaceId: workspace, userId: '18')));
  });

  test('Missing and malformed explicit consent is not enabled', () {
    for (final bad in <String>[
      '{',
      jsonEncode({'version': 1, 'workspace_id': workspace,
        'user_id': '17', 'enabled': false}),
      jsonEncode({'version': 2, 'workspace_id': workspace,
        'user_id': '17', 'enabled': true}),
      jsonEncode({'version': 1, 'workspace_id': workspace,
        'user_id': '17', 'enabled': true, 'unexpected': 'yes'}),
    ]) {
      expect(() => decodeDeviceNoticeConsent(bad), throwsFormatException);
    }
  });
}
