import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_mobile_token_shape.dart';

void main() {
  const access = 'v1.a.0123456789abcdef0123456789abcdef.'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  const refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

  test('access and refresh formats are strictly separate', () {
    expect(NativeMobileTokenShape.accepts(access, kind: 'a'), isTrue);
    expect(NativeMobileTokenShape.accepts(refresh, kind: 'r'), isTrue);
    expect(NativeMobileTokenShape.accepts(access, kind: 'r'), isFalse);
    expect(NativeMobileTokenShape.accepts(refresh, kind: 'a'), isFalse);
  });

  test('noncanonical, altered, blank and invalid kind fail closed', () {
    for (final invalid in <String?>[
      null, '', 'junk', '$access=', '$access ',
      access.toUpperCase(),
      '${access.substring(0, access.length - 1)}B',
      access.replaceFirst('v1.a.', 'v1.x.'),
      access.replaceFirst('v1.a.', 'v0.a.'),
    ]) {
      expect(NativeMobileTokenShape.accepts(invalid, kind: 'a'), isFalse);
    }
    expect(NativeMobileTokenShape.accepts(access, kind: ''), isFalse);
  });
}
