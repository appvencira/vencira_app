import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/api/native_mobile_token_shape.dart';
import 'package:vencira/ui/native_login_screen.dart';
import 'package:vencira/main.dart';
import 'package:vencira/ui/native_lab_login_shell.dart';

const _access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _SyntheticPort implements NativeAuthPort {
  bool requireMfa = false;
  bool failRevocation = false;
  Completer<NativePasswordResponse>? delayedPassword;
  int revoked = 0;
  int passwordCalls = 0;
  int mfaCalls = 0;

  @override
  Future<NativePasswordResponse> password({
    required String username,
    required String password,
  }) async {
    passwordCalls++;
    if (delayedPassword != null) return delayedPassword!.future;
    return requireMfa
        ? const NativePasswordMfaRequired(_challenge)
        : const NativePasswordGranted(
            NativeIssuedTokens(access: _access, refresh: _refresh),
          );
  }

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge,
    required String code,
  }) async {
    mfaCalls++;
    return const NativeIssuedTokens(access: _access, refresh: _refresh);
  }

  @override
  Future<void> revoke({required String refresh}) async {
    if (failRevocation) throw StateError('synthetic revoke failure');
    revoked++;
  }
}

class _SyntheticStore implements NativeSecretStore {
  final data = <String, String>{};

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> write(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    data.remove(key);
  }
}

void main() {
  late _SyntheticPort port;
  late _SyntheticStore store;
  late NativeSessionFence fence;
  late NativeSessionCoordinator coordinator;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    port = _SyntheticPort();
    store = _SyntheticStore();
    fence = NativeSessionFence();
    coordinator = NativeSessionCoordinator(
      port: port,
      fence: fence,
      vault: NativeRefreshCredentialVault(
        endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
        store: store,
      ),
    );
  });

  Future<void> waitFor(WidgetTester tester, Finder target) async {
    // A busy login/secure-logout screen may show an indefinitely animated
    // progress indicator. pumpAndSettle is therefore not a valid completion
    // condition: assert the actual contract state with a bounded pump loop.
    for (var n = 0; n < 60 && target.evaluate().isEmpty; n++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (target.evaluate().length != 1) {
      // A failed UI transition must expose the *state*, not sensitive input.
      // No access/refresh/password values are interpolated into this report.
      final loginError = find.byKey(const Key('native-login-error'));
      final loginErrorVisible = loginError.evaluate().isNotEmpty;
      final retry = find.byKey(const Key('g7-native-retry-logout'));
      fail(
        'G7 target absent: loginError=$loginErrorVisible '
        'retryLogout=${retry.evaluate().isNotEmpty} '
        'passwordCalls=${port.passwordCalls} mfaCalls=${port.mfaCalls} '
        'fenceActive=${fence.ticket != null} '
        'vaultPopulated=${store.data.isNotEmpty}',
      );
    }
  }

  Future<void> passwordLogin(
    WidgetTester tester, {
    bool mfaRequired = false,
  }) async {
    await tester.enterText(
      find.byKey(const Key('native-login-username')), 'operator',
    );
    await tester.enterText(
      find.byKey(const Key('native-login-password')), 'synthetic-password',
    );
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await waitFor(
      tester,
      mfaRequired
          ? find.text('Verificación en dos pasos')
          : find.byKey(const Key('g7-native-logout')),
    );
  }

  test('synthetic fixture satisfies native credential shape and coordinator', () async {
    expect(NativeMobileTokenShape.accepts(_access, kind: 'a'), isTrue);
    expect(NativeMobileTokenShape.accepts(_refresh, kind: 'r'), isTrue);
    final decision = await coordinator.verifyPassword(
      username: 'operator',
      password: 'synthetic-password',
    );
    expect(decision, NativePasswordDecision.authenticated);
    expect(fence.ticket, isNotNull);
    expect(store.data.values, contains(_refresh));
  });

  testWidgets('native shell starts locked; password success stays lab-only',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: coordinator),
    ));
    expect(fence.ticket, isNull);
    expect(find.byKey(const Key('g7-native-login')), findsOneWidget);
    expect(find.textContaining('Sesión nativa de laboratorio'), findsNothing);
    await passwordLogin(tester);
    expect(fence.ticket, isNotNull);
    expect(store.data.values, contains(_refresh));
    expect(find.byKey(const Key('g7-native-logout')), findsOneWidget);
    expect(find.textContaining('sin acceso a datos operativos'), findsOneWidget);
  });

  testWidgets('MFA challenge cannot open shell before verified code',
      (tester) async {
    port.requireMfa = true;
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: coordinator),
    ));
    await passwordLogin(tester, mfaRequired: true);
    expect(fence.ticket, isNull);
    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    expect(find.byKey(const Key('g7-native-logout')), findsNothing);
    await tester.enterText(
      find.byKey(const Key('native-login-totp')), '123456',
    );
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await waitFor(tester, find.byKey(const Key('g7-native-logout')));
    expect(port.mfaCalls, 1);
    expect(fence.ticket, isNotNull);
    expect(find.byKey(const Key('g7-native-logout')), findsOneWidget);
  });

  testWidgets('logout closes fence, revokes and clears vault',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: coordinator),
    ));
    await passwordLogin(tester);
    await tester.tap(find.byKey(const Key('g7-native-logout')));
    await waitFor(tester, find.byKey(const Key('g7-native-login')));
    expect(fence.ticket, isNull);
    expect(port.revoked, 1);
    expect(store.data, isEmpty);
    expect(find.byKey(const Key('g7-native-login')), findsOneWidget);
  });

  testWidgets('revocation failure never unlocks and allows cleanup retry',
      (tester) async {
    port.failRevocation = true;
    await tester.pumpWidget(MaterialApp(
      home: NativeLabLoginShell(coordinator: coordinator),
    ));
    await passwordLogin(tester);
    await tester.tap(find.byKey(const Key('g7-native-logout')));
    await waitFor(tester, find.byKey(const Key('g7-native-logout-error')));
    expect(fence.ticket, isNull);
    expect(store.data.values, contains(_refresh));
    expect(find.byKey(const Key('g7-native-logout-error')), findsOneWidget);
    expect(find.byKey(const Key('g7-native-login')), findsNothing);
    port.failRevocation = false;
    await tester.tap(find.byKey(const Key('g7-native-retry-logout')));
    await waitFor(tester, find.byKey(const Key('g7-native-login')));
    expect(port.revoked, 1);
    expect(store.data, isEmpty);
    expect(find.byKey(const Key('g7-native-login')), findsOneWidget);
  });

  testWidgets('app entrypoint only accepts explicitly injected lab coordinator',
      (tester) async {
    // Avoid Android OS alarm method channel in an entirely synthetic test.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      await tester.pumpWidget(VenciraApp(nativeLoginLab: coordinator));
      await waitFor(tester, find.byKey(const Key('g7-native-login')));
      expect(port.passwordCalls, 0);
      expect(fence.ticket, isNull);
    } finally {
      // Invariants run before addTearDown callbacks in flutter_test.
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
