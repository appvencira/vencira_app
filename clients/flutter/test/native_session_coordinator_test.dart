import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class LabMobilePort implements NativeAuthPort {
  NativePasswordResponse nextPassword = const NativePasswordGranted(
    NativeIssuedTokens(access: access, refresh: refresh),
  );
  NativeIssuedTokens nextMfa =
      const NativeIssuedTokens(access: access, refresh: refresh);
  Completer<NativePasswordResponse>? delayedPassword;
  Completer<NativeIssuedTokens>? delayedMfa;
  bool failRevoke = false;
  final revoked = <String>[];
  String? receivedUsername;
  String? receivedCode;

  @override
  Future<NativePasswordResponse> password({
    required String username,
    required String password,
  }) async {
    receivedUsername = username;
    final delay = delayedPassword;
    return delay == null ? nextPassword : delay.future;
  }

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge,
    required String code,
  }) async {
    receivedCode = code;
    final delay = delayedMfa;
    return delay == null ? nextMfa : delay.future;
  }

  @override
  Future<void> revoke({required String refresh}) async {
    if (failRevoke) throw StateError('synthetic network failure');
    revoked.add(refresh);
  }
}

class LabSecretStore implements NativeSecretStore {
  final items = <String, String>{};
  bool ignoreWrite = false;
  Completer<void>? writeGate;

  @override
  Future<String?> read(String key) async => items[key];

  @override
  Future<void> write(String key, String value) async {
    if (writeGate != null) await writeGate!.future;
    if (!ignoreWrite) items[key] = value;
  }

  @override
  Future<void> delete(String key) async => items.remove(key);
}

void main() {
  late LabMobilePort port;
  late LabSecretStore store;
  late NativeSessionFence fence;
  late NativeSessionCoordinator coordinator;

  setUp(() {
    port = LabMobilePort();
    store = LabSecretStore();
    fence = NativeSessionFence();
    coordinator = NativeSessionCoordinator(
      port: port,
      vault: NativeRefreshCredentialVault(
        endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
        store: store,
      ),
      fence: fence,
    );
  });

  test('password success stores protected refresh before unlocking requests',
      () async {
    store.writeGate = Completer<void>();
    final loggingIn = coordinator.verifyPassword(
      username: 'synthetic-account',
      password: 'synthetic-password',
    );
    await Future<void>.delayed(Duration.zero);
    expect(fence.ticket, isNull);
    expect(await coordinator.accessToken(), isNull);
    store.writeGate!.complete();
    expect(await loggingIn, NativePasswordDecision.authenticated);
    expect(fence.ticket, isNotNull);
    expect(await coordinator.accessToken(), access);
    expect(store.items.values.single, refresh);
    expect(store.items.values.single, isNot(access));
  });

  test('MFA challenge never unlocks before verified TOTP', () async {
    port.nextPassword = const NativePasswordMfaRequired(challenge);
    expect(
      await coordinator.verifyPassword(username: 'u', password: 'p'),
      NativePasswordDecision.mfaRequired,
    );
    expect(fence.ticket, isNull);
    expect(store.items, isEmpty);
    await coordinator.verifyTotp('123456');
    expect(port.receivedCode, '123456');
    expect(fence.ticket, isNotNull);
    expect(await coordinator.accessToken(), access);
  });

  test('bad MFA response cannot write access or refresh', () async {
    port.nextPassword = const NativePasswordMfaRequired(challenge);
    await coordinator.verifyPassword(username: 'u', password: 'p');
    port.nextMfa = const NativeIssuedTokens(
      access: refresh, refresh: access,
    );
    await expectLater(
      coordinator.verifyTotp('123456'),
      throwsA(isA<StateError>()),
    );
    expect(fence.ticket, isNull);
    expect(await coordinator.accessToken(), isNull);
    expect(store.items, isEmpty);
  });

  test('invalid challenge shape rejected without activation', () async {
    port.nextPassword = const NativePasswordMfaRequired('not-a-challenge');
    await expectLater(
      coordinator.verifyPassword(username: 'u', password: 'p'),
      throwsA(isA<StateError>()),
    );
    expect(fence.ticket, isNull);
    expect(store.items, isEmpty);
  });

  test('failed protected storage write blocks session and attempts revocation',
      () async {
    store.ignoreWrite = true;
    await expectLater(
      coordinator.verifyPassword(username: 'u', password: 'p'),
      throwsA(isA<StateError>()),
    );
    expect(fence.ticket, isNull);
    expect(await coordinator.accessToken(), isNull);
    expect(port.revoked, [refresh]);
  });

  test('abandoning a pending response never activates stale credentials',
      () async {
    port.delayedPassword = Completer<NativePasswordResponse>();
    final login = coordinator.verifyPassword(username: 'u', password: 'p');
    final abandoned = coordinator.abandonChallenge();
    port.delayedPassword!.complete(const NativePasswordGranted(
      NativeIssuedTokens(access: access, refresh: refresh),
    ));
    await expectLater(login, throwsA(isA<StateError>()));
    await abandoned;
    expect(fence.ticket, isNull);
    expect(store.items, isEmpty);
    expect(port.revoked, [refresh]);
  });

  test('abandoning a pending MFA challenge blocks delayed MFA result',
      () async {
    port.nextPassword = const NativePasswordMfaRequired(challenge);
    await coordinator.verifyPassword(username: 'u', password: 'p');
    port.delayedMfa = Completer<NativeIssuedTokens>();
    final finishing = coordinator.verifyTotp('123456');
    final abandoned = coordinator.abandonChallenge();
    port.delayedMfa!.complete(
      const NativeIssuedTokens(access: access, refresh: refresh),
    );
    await expectLater(finishing, throwsA(isA<StateError>()));
    await abandoned;
    expect(fence.ticket, isNull);
    expect(await coordinator.accessToken(), isNull);
    expect(port.revoked, [refresh]);
  });

  test('successful logout revokes server and erases protected refresh',
      () async {
    await coordinator.verifyPassword(username: 'u', password: 'p');
    expect(fence.ticket, isNotNull);
    await coordinator.logout();
    expect(fence.ticket, isNull);
    expect(await coordinator.accessToken(), isNull);
    expect(port.revoked, [refresh]);
    expect(store.items, isEmpty);
  });

  test('server revocation failure keeps gate closed and blocks new login',
      () async {
    await coordinator.verifyPassword(username: 'u', password: 'p');
    port.failRevoke = true;
    await expectLater(coordinator.logout(), throwsA(isA<StateError>()));
    expect(fence.ticket, isNull);
    expect(store.items.values.single, refresh);
    await expectLater(
      coordinator.verifyPassword(username: 'u', password: 'p'),
      throwsA(isA<StateError>()),
    );
    port.failRevoke = false;
    await coordinator.logout();
    expect(store.items, isEmpty);
    expect(fence.ticket, isNull);
    expect(port.revoked, [refresh]);
  });

  test('logout racing with secret write cannot activate old session',
      () async {
    store.writeGate = Completer<void>();
    final login = coordinator.verifyPassword(username: 'u', password: 'p');
    await Future<void>.delayed(Duration.zero);
    final logout = coordinator.logout();
    expect(fence.ticket, isNull);
    store.writeGate!.complete();
    await expectLater(login, throwsA(isA<StateError>()));
    await logout;
    expect(fence.ticket, isNull);
    expect(store.items, isEmpty);
    expect(port.revoked, [refresh]);
  });
}
