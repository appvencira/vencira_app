import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const oldRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const freshRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const freshAccess = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class LabRecoverySecretStore implements NativeSecretStore {
  final values = <String, String>{};
  bool ignoreWrite = false;
  bool ignoreDelete = false;
  Completer<void>? writeBarrier;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    final barrier = writeBarrier;
    if (barrier != null) await barrier.future;
    if (!ignoreWrite) values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (!ignoreDelete) values.remove(key);
  }
}

class LabRecoveryAuthPort implements NativeRecoveryAuthPort {
  int passwordCalls = 0;
  int mfaCalls = 0;
  String? lastCode;
  Completer<NativePasswordResponse>? passwordDelay;
  Completer<NativeIssuedTokens>? mfaDelay;
  NativePasswordResponse passwordResponse =
      const NativePasswordMfaRequired(challenge);
  NativeIssuedTokens mfaResponse = const NativeIssuedTokens(
    access: freshAccess, refresh: freshRefresh,
  );
  final revoked = <String>[];
  bool rejectMfa = false;

  @override
  Future<NativePasswordResponse> recoverPassword({
    required String username, required String password,
  }) async {
    passwordCalls++;
    return passwordDelay?.future ?? passwordResponse;
  }

  @override
  Future<NativeIssuedTokens> recoverMfa({
    required String challenge, required String code,
  }) async {
    mfaCalls++;
    lastCode = code;
    if (rejectMfa) throw StateError('Synthetic MFA rejection');
    return mfaDelay?.future ?? mfaResponse;
  }

  @override
  Future<void> revoke({required String refresh}) async {
    revoked.add(refresh);
  }
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  late LabRecoverySecretStore store;
  late NativeSessionFence fence;
  late NativeRefreshCredentialVault vault;
  late NativeRefreshRecoveryJournal journal;
  late LabRecoveryAuthPort port;
  late NativeRecoveryLoginGateway gateway;

  setUp(() {
    store = LabRecoverySecretStore();
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    port = LabRecoveryAuthPort();
    gateway = NativeRecoveryLoginGateway(
      port: port, journal: journal, vault: vault, fence: fence,
    );
  });

  Future<void> initUncertain() async {
    await vault.replace(oldRefresh);
    await journal.arm();
  }

  test('no durable checkpoint means recovery never contacts backend',
      () async {
    await expectLater(
      gateway.verifyPassword(username: 'agent', password: 'synthetic'),
      throwsStateError,
    );
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
    expect(await gateway.accessToken(), isNull);
  });

  test('fresh password recovery persists new refresh before access',
      () async {
    await initUncertain();
    expect(await gateway.requiresRecovery(), isTrue);
    final decision = await gateway.verifyPassword(
      username: 'agent', password: 'synthetic',
    );
    expect(decision, NativePasswordDecision.mfaRequired);
    expect(fence.ticket, isNull);
    await gateway.verifyTotp('123456');
    expect(await vault.read(), freshRefresh);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(fence.ticket, isNotNull);
    expect(await gateway.accessToken(), freshAccess);
    expect(port.passwordCalls, 1);
  });

  test('even a trusted mock port cannot grant recovery after password only',
      () async {
    await initUncertain();
    port.passwordResponse = const NativePasswordGranted(
      NativeIssuedTokens(access: freshAccess, refresh: freshRefresh),
    );
    await expectLater(
      gateway.verifyPassword(username: 'agent', password: 'synthetic'),
      throwsStateError,
    );
    expect(fence.ticket, isNull);
    expect(await gateway.accessToken(), isNull);
    expect(await vault.read(), oldRefresh);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.mfaCalls, 0);
  });

  test('MFA challenge never unlocks until separate recovery TOTP succeeds',
      () async {
    await initUncertain();
    port.passwordResponse = const NativePasswordMfaRequired(challenge);
    final decision = await gateway.verifyPassword(
      username: 'agent', password: 'synthetic',
    );
    expect(decision, NativePasswordDecision.mfaRequired);
    expect(fence.ticket, isNull);
    expect(await vault.read(), oldRefresh);
    expect(await gateway.accessToken(), isNull);
    await gateway.verifyTotp('123456');
    expect(port.mfaCalls, 1);
    expect(port.lastCode, '123456');
    expect(await vault.read(), freshRefresh);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await gateway.accessToken(), freshAccess);
  });

  test('invalid MFA challenge cannot unlock or be completed', () async {
    await initUncertain();
    port.passwordResponse = const NativePasswordMfaRequired('invalid');
    await expectLater(
      gateway.verifyPassword(username: 'agent', password: 'synthetic'),
      throwsStateError,
    );
    await expectLater(gateway.verifyTotp('123456'), throwsStateError);
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.mfaCalls, 0);
  });

  test('failed MFA leaves previous token inaccessible', () async {
    await initUncertain();
    port.passwordResponse = const NativePasswordMfaRequired(challenge);
    await gateway.verifyPassword(username: 'agent', password: 'synthetic');
    port.rejectMfa = true;
    await expectLater(gateway.verifyTotp('123456'), throwsStateError);
    expect(fence.ticket, isNull);
    expect(await gateway.accessToken(), isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), oldRefresh);
  });

  test('storage write ignored after grant rejects session and attempts revoke',
      () async {
    await initUncertain();
    store.ignoreWrite = true;
    expect(await gateway.verifyPassword(
      username: 'agent', password: 'synthetic',
    ), NativePasswordDecision.mfaRequired);
    await expectLater(gateway.verifyTotp('123456'), throwsStateError);
    expect(fence.ticket, isNull);
    expect(await gateway.accessToken(), isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.revoked, contains(freshRefresh));
  });

  test('delayed recovery response after abandoned challenge cannot unlock',
      () async {
    await initUncertain();
    port.passwordDelay = Completer<NativePasswordResponse>();
    final pending = gateway.verifyPassword(
      username: 'agent', password: 'synthetic',
    );
    await Future<void>.delayed(Duration.zero);
    final cancelled = gateway.abandonChallenge();
    port.passwordDelay!.complete(const NativePasswordGranted(
      NativeIssuedTokens(access: freshAccess, refresh: freshRefresh),
    ));
    await expectLater(pending, throwsStateError);
    await cancelled;
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await gateway.accessToken(), isNull);
  });

  test('abandoning in-flight MFA keeps checkpoint and gate closed',
      () async {
    await initUncertain();
    port.passwordResponse = const NativePasswordMfaRequired(challenge);
    await gateway.verifyPassword(username: 'agent', password: 'synthetic');
    port.mfaDelay = Completer<NativeIssuedTokens>();
    final pending = gateway.verifyTotp('123456');
    await Future<void>.delayed(Duration.zero);
    final cancelled = gateway.abandonChallenge();
    port.mfaDelay!.complete(const NativeIssuedTokens(
      access: freshAccess, refresh: freshRefresh,
    ));
    await expectLater(pending, throwsStateError);
    await cancelled;
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
  });

  test('cold-start recovery never uses persisted old bearer', () async {
    await initUncertain();
    fence.activate();
    expect(fence.ticket, isNotNull);
    expect(await gateway.requiresRecovery(), isTrue);
    expect(fence.ticket, isNull);
    expect(await gateway.accessToken(), isNull);
    expect(port.passwordCalls, 0);
  });
}
