import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/session_denial_classifier.dart';

void main() {
  for (final code in [401, 403]) {
    test('$code with confirmed anonymous identity means expired', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unauthenticated),
        SessionDenial.expired);
    });
    test('$code with valid identity cannot revoke the whole session', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.authenticated),
        SessionDenial.forbidden);
    });
    test('$code with unavailable probe remains unknown', () {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unavailable),
        SessionDenial.unknown);
    });
  }

  test('unrelated status cannot be mistaken for expiration', () {
    for (final code in [0, 200, 400, 404, 409, 422, 500, 503]) {
      expect(classifySessionDenial(
        statusCode: code, identity: IdentityProbe.unauthenticated),
        SessionDenial.unknown);
    }
  });
}
