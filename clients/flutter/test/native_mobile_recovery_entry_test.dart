import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_mobile_recovery_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const oldRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const newRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const newAccess = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _Store implements NativeSecretStore {
  final values = <String, String>{};
  bool failRead = false;
  Completer<void>? pauseRead;

  @override
  Future<String?> read(String key) async {
    final barrier = pauseRead;
    if (barrier != null) await barrier.future;
    if (failRead) throw StateError('synthetic read denied');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

class _RecoveryPort implements NativeRecoveryAuthPort {
  int passwordCalls = 0;
  int mfaCalls = 0;
  bool requireMfa = false;
  bool failPassword = false;

  @override
  Future<NativePasswordResponse> recoverPassword({
    required String username,
    required String password,
  }) async {
    passwordCalls++;
    if (failPassword) throw StateError('synthetic password failure');
    if (requireMfa) return const NativePasswordMfaRequired(challenge);
    return const NativePasswordGranted(
      NativeIssuedTokens(access: newAccess, refresh: newRefresh),
    );
  }

  @override
  Future<NativeIssuedTokens> recoverMfa({
    required String challenge,
    required String code,
  }) async {
    mfaCalls++;
    return const NativeIssuedTokens(access: newAccess, refresh: newRefresh);
  }

  @override
  Future<void> revoke({required String refresh}) async {}
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  late _Store store;
  late NativeSessionFence fence;
  late NativeRefreshCredentialVault vault;
  late NativeRefreshRecoveryJournal journal;
  late NativeMobileStartupGate startup;
  late _RecoveryPort port;
  late NativeRecoveryLoginGateway recovery;
  late NativeMobileRecoveryEntry entry;

  setUp(() {
    store = _Store();
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    startup = NativeMobileStartupGate(
      fence: fence, vault: vault, journal: journal,
    );
    port = _RecoveryPort();
    recovery = NativeRecoveryLoginGateway(
      port: port, journal: journal, vault: vault, fence: fence,
    );
    entry = NativeMobileRecoveryEntry(startup: startup, recovery: recovery);
  });

  test('no boot: all credential submissions denied before reaching port', () {
    expect(() => entry.verifyPassword(username: 'u', password: 'p'),
        throwsStateError);
    expect(() => entry.verifyTotp('123456'), throwsStateError);
    expect(() => entry.abandonChallenge(), throwsStateError);
    expect(port.passwordCalls, 0);
    expect(port.mfaCalls, 0);
    expect(fence.ticket, isNull);
  });

  test('clean startup cannot bypass unreviewed first-issuance checkpoint',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    expect(() => entry.verifyPassword(username: 'u', password: 'p'),
        throwsStateError);
    expect(await entry.accessToken(), isNull);
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
  });

  test('orphan refresh routes exclusively through full recovery', () async {
    await vault.replace(oldRefresh);
    final route = await entry.inspect();
    expect(route, NativeStartupDisposition.fullReauthentication);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(fence.ticket, isNull);
    expect(await entry.verifyPassword(username: 'u', password: 'p'),
        NativePasswordDecision.authenticated);
    expect(port.passwordCalls, 1);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await vault.read(), newRefresh);
    expect(await entry.accessToken(), newAccess);
    expect(fence.ticket, isNotNull);
  });

  test('existing marker requires recovery MFA; password alone keeps fence down',
      () async {
    await journal.arm();
    port.requireMfa = true;
    expect(await entry.inspect(), NativeStartupDisposition.fullReauthentication);
    expect(await entry.verifyPassword(username: 'u', password: 'p'),
        NativePasswordDecision.mfaRequired);
    expect(await entry.accessToken(), isNull);
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    await entry.verifyTotp('123456');
    expect(port.mfaCalls, 1);
    expect(await vault.read(), newRefresh);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await entry.accessToken(), newAccess);
    expect(fence.ticket, isNotNull);
  });

  test('failed password leaves checkpoint and denies access', () async {
    await vault.replace(oldRefresh);
    port.failPassword = true;
    expect(await entry.inspect(), NativeStartupDisposition.fullReauthentication);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'bad'),
      throwsStateError,
    );
    expect(port.passwordCalls, 1);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), oldRefresh);
    expect(fence.ticket, isNull);
  });

  test('corrupted marker blocks before any login request', () async {
    store.values['vencira.mobile.dev.uncertain.v1'] = 'corrupted';
    await expectLater(entry.inspect(), throwsStateError);
    expect(() => entry.verifyPassword(username: 'u', password: 'p'),
        throwsStateError);
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
  });

  test('pending secure read never enables speculative login', () async {
    store.pauseRead = Completer<void>();
    final inspecting = entry.inspect();
    expect(() => entry.verifyPassword(username: 'u', password: 'p'),
        throwsStateError);
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
    store.pauseRead!.complete();
    expect(await inspecting, NativeStartupDisposition.cleanLogin);
    expect(port.passwordCalls, 0);
  });

  test('recovery entry refuses vault/fence mismatch before using port',
      () async {
    final foreignFence = NativeSessionFence()..activate();
    final foreignRecovery = NativeRecoveryLoginGateway(
      port: port,
      journal: NativeRefreshRecoveryJournal(
        endpoint: endpoint, store: store, fence: foreignFence,
      ),
      vault: vault,
      fence: foreignFence,
    );
    final wrongEntry = NativeMobileRecoveryEntry(
      startup: startup, recovery: foreignRecovery,
    );
    fence.activate();
    await expectLater(wrongEntry.inspect(), throwsStateError);
    expect(fence.ticket, isNull);
    expect(foreignFence.ticket, isNull);
    expect(port.passwordCalls, 0);
  });

  test('startup route may not be re-inspected after successful selection',
      () async {
    await vault.replace(oldRefresh);
    expect(await entry.inspect(), NativeStartupDisposition.fullReauthentication);
    await expectLater(entry.inspect(), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.passwordCalls, 0);
  });
}
