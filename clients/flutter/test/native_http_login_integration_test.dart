import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

/// G7-B: in-process HTTP integration, without a live network or issuer.
///
/// Run with test() rather than testWidgets(): this suite tests streamed HTTP,
/// vault futures, session fencing and Bearer authorization with real async
/// streams. The G7-A native_lab_login_shell_test.dart suite separately tests
/// the widget/callback transitions under Flutter's FakeAsync zone.
const _access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

http.Response _reply(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store, max-age=0',
    });

http.Response _grant() => _reply({
  'status': 'authenticated',
  'access': _access,
  'refresh': _refresh,
});

class _MemoryProtectedStore implements NativeSecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _Fixture {
  _Fixture(this.client)
      : endpoint = NativeApiEndpoint.parse('https://dev.vencira.es'),
        store = _MemoryProtectedStore(),
        fence = NativeSessionFence() {
    coordinator = NativeSessionCoordinator(
      port: NativeHttpAuthPort(endpoint: endpoint, client: client),
      vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
      fence: fence,
    );
    transport = NativeApiTransport(
      endpoint: endpoint,
      client: client,
      sessionFence: fence,
      accessToken: coordinator.accessToken,
    );
  }

  final http.Client client;
  final NativeApiEndpoint endpoint;
  final _MemoryProtectedStore store;
  final NativeSessionFence fence;
  late final NativeSessionCoordinator coordinator;
  late final NativeApiTransport transport;
}

void _requireNativeRequest(http.Request request, String path) {
  expect(request.url.scheme, 'https');
  expect(request.url.host, 'dev.vencira.es');
  expect(request.url.path, path);
  expect(request.followRedirects, isFalse);
  expect(request.headers['Cookie'], isNull);
  expect(request.headers['Origin'], isNull);
}

void main() {
  test('G7-B HTTP password, verified vault, scoped Bearer GET and logout',
      () async {
    var passwordCalls = 0;
    var bearerReads = 0;
    var revokeCalls = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/mobile/auth/password/':
          passwordCalls++;
          _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
          expect(request.method, 'POST');
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'username': 'lab-user', 'password': 'lab-password',
          });
          return _grant();
        case '/api/v1/mobile/me/':
          bearerReads++;
          _requireNativeRequest(request, '/api/v1/mobile/me/');
          expect(request.method, 'GET');
          expect(request.headers['Authorization'], 'Bearer $_access');
          return _reply({'authenticated': true, 'user_id': 27});
        case '/api/v1/mobile/token/revoke/':
          revokeCalls++;
          _requireNativeRequest(request, '/api/v1/mobile/token/revoke/');
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'refresh': _refresh});
          expect(request.headers['Authorization'], isNull);
          return _reply({'status': 'revoked'});
        default:
          throw StateError('Unexpected native HTTP path');
      }
    });
    addTearDown(client.close);
    final fixture = _Fixture(client);
    expect(fixture.fence.ticket, isNull);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(passwordCalls, 0);
    expect(bearerReads, 0);

    final decision = await fixture.coordinator.verifyPassword(
      username: 'lab-user',
      password: 'lab-password',
    );
    expect(decision, NativePasswordDecision.authenticated);
    expect(passwordCalls, 1);
    expect(fixture.fence.ticket, isNotNull);
    expect(fixture.store.values.values.single, _refresh);
    expect(await fixture.coordinator.accessToken(), _access);

    final profile = await fixture.transport.getJson('/api/v1/mobile/me/');
    expect(profile, {'authenticated': true, 'user_id': 27});
    expect(bearerReads, 1);

    final closing = fixture.coordinator.logout();
    expect(fixture.fence.ticket, isNull); // synchronous fence closure
    await closing;
    expect(revokeCalls, 1);
    expect(fixture.store.values, isEmpty);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(bearerReads, 1);
  });

  test('G7-B HTTP MFA challenge never opens session before accepted TOTP',
      () async {
    var passwordCalls = 0;
    var mfaCalls = 0;
    var bearerReads = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/mobile/auth/password/':
          passwordCalls++;
          _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
          return _reply({'status': 'mfa_required', 'challenge': _challenge});
        case '/api/v1/mobile/auth/mfa/':
          mfaCalls++;
          _requireNativeRequest(request, '/api/v1/mobile/auth/mfa/');
          expect(jsonDecode(request.body), {
            'challenge': _challenge, 'code': '123456',
          });
          return _grant();
        case '/api/v1/mobile/me/':
          bearerReads++;
          return _reply({'authenticated': true, 'user_id': 27});
        default:
          throw StateError('Unexpected native HTTP path');
      }
    });
    addTearDown(client.close);
    final fixture = _Fixture(client);
    final decision = await fixture.coordinator.verifyPassword(
      username: 'lab-user', password: 'lab-password',
    );
    expect(decision, NativePasswordDecision.mfaRequired);
    expect(passwordCalls, 1);
    expect(mfaCalls, 0);
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values, isEmpty);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(bearerReads, 0);

    await fixture.coordinator.verifyTotp('123456');
    expect(mfaCalls, 1);
    expect(fixture.fence.ticket, isNotNull);
    expect(fixture.store.values.values.single, _refresh);
    expect(await fixture.coordinator.accessToken(), _access);
  });

  test('G7-B HTTP 401 rejects password without credentials or fence',
      () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
      return _reply({'error': 'native_auth_unavailable'}, status: 401);
    });
    addTearDown(client.close);
    final fixture = _Fixture(client);
    await expectLater(
      fixture.coordinator.verifyPassword(
        username: 'lab-user', password: 'bad-password',
      ),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    expect(calls, 1);
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values, isEmpty);
    expect(await fixture.coordinator.accessToken(), isNull);
  });

  test('G7-B HTTP revoke denial keeps fence closed until explicit retry',
      () async {
    var allowRevoke = false;
    var revokeCalls = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/mobile/auth/password/':
          return _grant();
        case '/api/v1/mobile/token/revoke/':
          revokeCalls++;
          _requireNativeRequest(request, '/api/v1/mobile/token/revoke/');
          expect(jsonDecode(request.body), {'refresh': _refresh});
          return allowRevoke
              ? _reply({'status': 'revoked'})
              : _reply({'error': 'native_auth_unavailable'}, status: 503);
        default:
          throw StateError('Unexpected native HTTP path');
      }
    });
    addTearDown(client.close);
    final fixture = _Fixture(client);
    expect(await fixture.coordinator.verifyPassword(
      username: 'lab-user', password: 'lab-password',
    ), NativePasswordDecision.authenticated);

    final closing = fixture.coordinator.logout();
    expect(fixture.fence.ticket, isNull);
    await expectLater(closing, throwsA(isA<NativeHttpAuthFailure>()));
    expect(revokeCalls, 1);
    expect(fixture.store.values.values.single, _refresh);
    expect(fixture.fence.ticket, isNull);
    await expectLater(
      fixture.coordinator.verifyPassword(
        username: 'lab-user', password: 'lab-password',
      ),
      throwsStateError,
    );

    allowRevoke = true;
    await fixture.coordinator.logout();
    expect(revokeCalls, 2);
    expect(fixture.store.values, isEmpty);
    expect(fixture.fence.ticket, isNull);
  });

  test('G7-B remote Bearer 401 revokes local request gate',
      () async {
    var reads = 0;
    var revokes = 0;
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/api/v1/mobile/auth/password/':
          return _grant();
        case '/api/v1/mobile/me/':
          reads++;
          expect(request.headers['Authorization'], 'Bearer $_access');
          return _reply({'error': 'native_auth_unavailable'}, status: 401);
        case '/api/v1/mobile/token/revoke/':
          revokes++;
          return _reply({'status': 'revoked'});
        default:
          throw StateError('Unexpected native HTTP path');
      }
    });
    addTearDown(client.close);
    final fixture = _Fixture(client);
    await fixture.coordinator.verifyPassword(
      username: 'lab-user', password: 'lab-password',
    );
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(reads, 1);
    expect(fixture.fence.ticket, isNull);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(reads, 1);
    await fixture.coordinator.logout();
    expect(revokes, 1);
    expect(fixture.store.values, isEmpty);
  });
}
