import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/android_local_alarm_port.dart';

void main() {
  test('Stable numeric alarm identity is consistent and positive', () {
    const a = '11111111-1111-4111-8111-111111111111/17/'
      '22222222-2222-4222-8222-222222222222/1';
    expect(androidNoticeId(a), androidNoticeId(a));
    expect(androidNoticeId(a), greaterThan(0));
    expect(androidNoticeId(a), lessThan(2147483648));
    expect(androidNoticeId(a), isNot(androidNoticeId('$a/changed')));
  });

  test('Empty alarm key is never accepted', () {
    expect(() => androidNoticeId(''), throwsFormatException);
  });
}
