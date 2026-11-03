import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_lab_login_shell.dart';

/// G7-B: Flutter HTTP-to-session integration against deterministic responses
/// conforming to native_sessions_lab.test_http_contract. NO live network,
/// credentials, cookies, backend routing, or operational resource access.
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
  _Fixture(http.Client client)
      : endpoint = NativeApiEndpoint.parse('https://dev.vencira.es'),
        store = _MemoryProtectedStore(),
        fence = NativeSessionFence() {
    // Construct the vault within testWidgets' FakeAsync zone.
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

  final NativeApiEndpoint endpoint;
  final _MemoryProtectedStore store;
  final NativeSessionFence fence;
  late final NativeSessionCoordinator coordinator;
  late final NativeApiTransport transport;
}

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  // Waiting for a specific security state avoids pumpAndSettle problems with
  // indefinitely animated progress indicators.
  for (var i = 0; i < 80 && target.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(target, findsOneWidget);
}

Future<void> _enterPassword(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('native-login-username')), 'lab-user',
  );
  await tester.enterText(
    find.byKey(const Key('native-login-password')), 'lab-password',
  );
  await tester.tap(find.byKey(const Key('native-login-submit')));
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
  testWidgets('HTTP password, protected refresh, Bearer read and logout',
      (tester) async {
    var passwordCalls = 0;
    var bearerReads = 0;
    var revokeCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/mobile/auth/password/') {
        passwordCalls++;
        _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], isNull);
        expect(jsonDecode(request.body), {
          'username': 'lab-user', 'password': 'lab-password',
        });
        return _grant();
      }
      if (request.url.path == '/api/v1/mobile/me/') {
        bearerReads++;
        _requireNativeRequest(request, '/api/v1/mobile/me/');
        expect(request.method, 'GET');
        expect(request.headers['Authorization'], 'Bearer ' + _access);
        return _reply({'authenticated': true, 'user_id': 27});
      }
      if (request.url.path == '/api/v1/mobile/token/revoke/') {
        revokeCalls++;
        _requireNativeRequest(request, '/api/v1/mobile/token/revoke/');
        expect(request.method, 'POST');
        expect(jsonDecode(request.body), {'refresh': _refresh});
        return _reply({'status': 'revoked'});
      }
      fail('Unexpected native HTTP path');
    });

    final fixture = _Fixture(client);
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: fixture.coordinator),
    ));
    expect(fixture.fence.ticket, isNull);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(passwordCalls, 0);
    expect(bearerReads, 0);

    await _enterPassword(tester);
    await _waitFor(tester, find.byKey(const Key('g7-native-logout')));
    expect(passwordCalls, 1);
    expect(fixture.fence.ticket, isNotNull);
    expect(fixture.store.values.values.single, _refresh);

    final profile = await fixture.transport.getJson('/api/v1/mobile/me/');
    expect(profile, {'authenticated': true, 'user_id': 27});
    expect(bearerReads, 1);

    await tester.tap(find.byKey(const Key('g7-native-logout')));
    await _waitFor(tester, find.byKey(const Key('g7-native-login')));
    expect(revokeCalls, 1);
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values, isEmpty);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(bearerReads, 1);
    client.close();
  });

  testWidgets('HTTP MFA challenge holds fence closed until TOTP is accepted',
      (tester) async {
    var mfaCalls = 0;
    var bearerReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/mobile/auth/password/') {
        _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
        return _reply({'status': 'mfa_required', 'challenge': _challenge});
      }
      if (request.url.path == '/api/v1/mobile/auth/mfa/') {
        mfaCalls++;
        _requireNativeRequest(request, '/api/v1/mobile/auth/mfa/');
        expect(jsonDecode(request.body), {
          'challenge': _challenge, 'code': '123456',
        });
        return _grant();
      }
      if (request.url.path == '/api/v1/mobile/me/') {
        bearerReads++;
        return _reply({'authenticated': true, 'user_id': 27});
      }
      fail('Unexpected native HTTP path');
    });

    final fixture = _Fixture(client);
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: fixture.coordinator),
    ));
    await _enterPassword(tester);
    await _waitFor(tester, find.text('Verificación en dos pasos'));
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values, isEmpty);
    await expectLater(
      fixture.transport.getJson('/api/v1/mobile/me/'),
      throwsA(isA<NativeApiSessionUnavailable>()),
    );
    expect(bearerReads, 0);

    await tester.enterText(
      find.byKey(const Key('native-login-totp')), '123456',
    );
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await _waitFor(tester, find.byKey(const Key('g7-native-logout')));
    expect(mfaCalls, 1);
    expect(fixture.fence.ticket, isNotNull);
    expect(fixture.store.values.values.single, _refresh);
    client.close();
  });

  testWidgets('HTTP 401 on password cannot grant or store native session',
      (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      _requireNativeRequest(request, '/api/v1/mobile/auth/password/');
      return _reply({'error': 'native_auth_unavailable'}, status: 401);
    });
    final fixture = _Fixture(client);
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: fixture.coordinator),
    ));
    await _enterPassword(tester);
    await _waitFor(tester, find.byKey(const Key('native-login-error')));
    expect(calls, 1);
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values, isEmpty);
    expect(find.byKey(const Key('g7-native-logout')), findsNothing);
    client.close();
  });

  testWidgets('HTTP revoke denial closes gate and requires explicit retry',
      (tester) async {
    var allowRevoke = false;
    var revokeCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/mobile/auth/password/') return _grant();
      if (request.url.path == '/api/v1/mobile/token/revoke/') {
        revokeCalls++;
        return allowRevoke
            ? _reply({'status': 'revoked'})
            : _reply({'error': 'native_auth_unavailable'}, status: 503);
      }
      fail('Unexpected native HTTP path');
    });
    final fixture = _Fixture(client);
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: fixture.coordinator),
    ));
    await _enterPassword(tester);
    await _waitFor(tester, find.byKey(const Key('g7-native-logout')));
    await tester.tap(find.byKey(const Key('g7-native-logout')));
    await _waitFor(tester, find.byKey(const Key('g7-native-logout-error')));
    expect(fixture.fence.ticket, isNull);
    expect(fixture.store.values.values.single, _refresh);
    expect(find.byKey(const Key('g7-native-login')), findsNothing);
    expect(revokeCalls, 1);

    allowRevoke = true;
    await tester.tap(find.byKey(const Key('g7-native-retry-logout')));
    await _waitFor(tester, find.byKey(const Key('g7-native-login')));
    expect(revokeCalls, 2);
    expect(fixture.store.values, isEmpty);
    expect(fixture.fence.ticket, isNull);
    client.close();
  });
}
