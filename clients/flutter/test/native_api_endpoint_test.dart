import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';

void main() {
  test('permits only explicit approved HTTPS origins', () {
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    expect(endpoint.resolveApiPath('/api/v1/me/').toString(),
        'https://dev.vencira.es/api/v1/me/');
    expect(NativeApiEndpoint.parse('https://vencira.es/').origin.scheme,
        'https');
  });

  test('rejects insecure, foreign or credential-bearing origins', () {
    for (final bad in [
      'http://dev.vencira.es',
      'https://evil.example',
      'https://dev.vencira.es.evil.example',
      'https://user:password@dev.vencira.es',
      'https://dev.vencira.es/api/v1/',
      'https://dev.vencira.es?secret=1',
      'https://dev.vencira.es/#frag',
      'https://dev.vencira.es:8443',
      'not-a-url',
    ]) {
      expect(() => NativeApiEndpoint.parse(bad), throwsFormatException,
          reason: bad);
    }
  });

  test('does not resolve arbitrary external or non-API paths', () {
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    for (final bad in [
      'https://evil.example/api/v1/me/',
      '//evil.example/api/v1/me/',
      '/accounts/login/',
      '/api/v1/../../admin/',
      '/api/v1/me/#fragment',
    ]) {
      expect(() => endpoint.resolveApiPath(bad), throwsFormatException,
          reason: bad);
    }
  });
}
