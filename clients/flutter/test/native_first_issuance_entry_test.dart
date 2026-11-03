import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_first_issuance_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _refresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _Store implements NativeSecretStore {
  final records = <String, String>{};
  bool ignoreMarkerWrite = false;
  bool ignoreMarkerDelete = false;
  bool ignoreRefreshWrite = false;
  bool ignoreRefreshDelete = false;
  bool failReads = false;
  Completer<void>? pauseMarkerWrite;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw StateError('test storage read failed');
    return records[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (key.endsWith('.uncertain.v1')) {
      final delay = pauseMarkerWrite;
      if (delay != null) await delay.future;
      if (ignoreMarkerWrite) return;
    }
    if (key.endsWith('.refresh.v1') && ignoreRefreshWrite) return;
    records[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (key.endsWith('.uncertain.v1') && ignoreMarkerDelete) return;
    if (key.endsWith('.refresh.v1') && ignoreRefreshDelete) return;
    records.remove(key);
  }
}

class _AuthPort implements NativeAuthPort {
  _AuthPort({required this.journal, required this.fence});

  final NativeRefreshRecoveryJournal journal;
  final NativeSessionFence fence;
  final revoked = <String>[];
  int passwordCalls = 0;
  int mfaCalls = 0;
  int revokeCalls = 0;
  bool issueMfa = false;
  bool rejectPassword = false;
  bool rejectRevoke = false;
  bool losePasswordResponse = false;
  bool markerPresentOnPassword = false;
  bool markerPresentOnMfa = false;
  Completer<NativePasswordResponse>? delayedPassword;

  @override
  Future<NativePasswordResponse> password({
    required String username, required String password,
  }) async {
    passwordCalls++;
    markerPresentOnPassword =
        await journal.requiresReauthentication() && fence.ticket == null;
    if (!markerPresentOnPassword) throw StateError('HTTP BEFORE G10 CHECKPOINT');
    final delayed = delayedPassword;
    if (delayed != null) return delayed.future;
    if (rejectPassword || losePasswordResponse) {
      throw StateError('Synthetic failed or lost password response');
    }
    if (issueMfa) return const NativePasswordMfaRequired(_challenge);
    return const NativePasswordGranted(
      NativeIssuedTokens(access: _access, refresh: _refresh),
    );
  }

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge, required String code,
  }) async {
    mfaCalls++;
    markerPresentOnMfa =
        await journal.requiresReauthentication() && fence.ticket == null;
    if (!markerPresentOnMfa) throw StateError('MFA BEFORE G10 CHECKPOINT');
    return const NativeIssuedTokens(access: _access, refresh: _refresh);
  }

  @override
  Future<void> revoke({required String refresh}) async {
    revokeCalls++;
    if (rejectRevoke) throw StateError('Synthetic remote revocation lost');
    revoked.add(refresh);
  }
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  late _Store store;
  late NativeSessionFence fence;
  late NativeRefreshCredentialVault vault;
  late NativeRefreshRecoveryJournal journal;
  late NativeMobileStartupGate startup;
  late _AuthPort port;
  late NativeSessionCoordinator coordinator;
  late NativeFirstIssuanceEntry entry;

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
    port = _AuthPort(journal: journal, fence: fence);
    coordinator = NativeSessionCoordinator(
      port: port, vault: vault, fence: fence,
      firstIssuanceJournal: journal,
    );
    entry = NativeFirstIssuanceEntry(
      startup: startup, coordinator: coordinator, journal: journal,
    );
  });

  test('password rejected before G9 cold-start inspection', () {
    expect(
      () => entry.verifyPassword(username: 'u', password: 'p'),
      throwsStateError,
    );
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
  });

  test('clean first issue arms marker before HTTP and commits before fence',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    expect(await entry.verifyPassword(username: 'u', password: 'p'),
        NativePasswordDecision.authenticated);
    expect(port.passwordCalls, 1);
    expect(port.markerPresentOnPassword, isTrue);
    expect(await vault.read(), _refresh);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await entry.accessToken(), _access);
    expect(fence.ticket, isNotNull);
    await entry.logout();
    expect(port.revoked, [_refresh]);
    expect(await vault.read(), isNull);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(fence.ticket, isNull);
    expect(await entry.accessToken(), isNull);
  });

  test('G9 orphan refresh refuses a first issue without HTTP', () async {
    await vault.replace(_refresh);
    expect(await entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(
      () => entry.verifyPassword(username: 'u', password: 'p'),
      throwsStateError,
    );
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
  });

  test('password and MFA both observe the durable marker', () async {
    port.issueMfa = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    expect(await entry.verifyPassword(username: 'u', password: 'p'),
        NativePasswordDecision.mfaRequired);
    expect(port.markerPresentOnPassword, isTrue);
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    await entry.verifyTotp('123456');
    expect(port.markerPresentOnMfa, isTrue);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await vault.read(), _refresh);
    expect(await entry.accessToken(), _access);
  });

  test('silent checkpoint write fails before any password request', () async {
    store.ignoreMarkerWrite = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'p'), throwsStateError,
    );
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
    expect(await entry.accessToken(), isNull);
  });

  test('failed password leaves durable marker for reboot recovery', () async {
    port.rejectPassword = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'bad'), throwsStateError,
    );
    expect(port.markerPresentOnPassword, isTrue);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), isNull);
    final cold = NativeMobileStartupGate(
      fence: NativeSessionFence(),
      vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
      journal: NativeRefreshRecoveryJournal(
        endpoint: endpoint,
        store: store,
        fence: NativeSessionFence(),
      ),
    );
    // Deliberate mismatch test; no accidental clean fallback.
    await expectLater(cold.inspect(), throwsStateError);
    final rebootFence = NativeSessionFence();
    final reboot = NativeMobileStartupGate(
      fence: rebootFence,
      vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
      journal: NativeRefreshRecoveryJournal(
        endpoint: endpoint, store: store, fence: rebootFence,
      ),
    );
    expect(await reboot.inspect(),
        NativeStartupDisposition.fullReauthentication);
  });

  test('uncertain server response cannot be retried without full recovery',
      () async {
    port.losePasswordResponse = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'p'), throwsStateError,
    );
    expect(await journal.requiresReauthentication(), isTrue);
    expect(port.passwordCalls, 1);
    expect(
      () => entry.verifyPassword(username: 'u', password: 'p'),
      throwsStateError,
    );
    expect(port.passwordCalls, 1);
    expect(fence.ticket, isNull);
  });

  test('silent refresh write failure keeps marker and revokes issued refresh',
      () async {
    store.ignoreRefreshWrite = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'p'), throwsStateError,
    );
    expect(port.revoked, [_refresh]);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), isNull);
    expect(fence.ticket, isNull);
  });

  test('ignored marker deletion refuses activation and attempts remote revoke',
      () async {
    store.ignoreMarkerDelete = true;
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await expectLater(
      entry.verifyPassword(username: 'u', password: 'p'), throwsStateError,
    );
    expect(port.revoked, [_refresh]);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(fence.ticket, isNull);
  });

  test('failed remote logout remains durable, fenced and retryable',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await entry.verifyPassword(username: 'u', password: 'p');
    port.rejectRevoke = true;
    final future = entry.logout();
    expect(fence.ticket, isNull);
    await expectLater(future, throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), _refresh);
    expect(await entry.accessToken(), isNull);
    port.rejectRevoke = false;
    await entry.logout();
    expect(await vault.read(), isNull);
    expect(await journal.requiresReauthentication(), isFalse);
    expect(port.revoked, [_refresh]);
  });

  test('failed protected deletion retries without replaying successful revoke',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await entry.verifyPassword(username: 'u', password: 'p');
    store.ignoreRefreshDelete = true;
    await expectLater(entry.logout(), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), _refresh);
    expect(port.revokeCalls, 1);
    expect(fence.ticket, isNull);
    store.ignoreRefreshDelete = false;
    await entry.logout();
    expect(port.revokeCalls, 1);
    expect(await vault.read(), isNull);
    expect(await journal.requiresReauthentication(), isFalse);
  });

  test('journal clear failure after logout remains fenced until retry',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    await entry.verifyPassword(username: 'u', password: 'p');
    store.ignoreMarkerDelete = true;
    await expectLater(entry.logout(), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), isNull);
    expect(fence.ticket, isNull);
    store.ignoreMarkerDelete = false;
    await entry.logout();
    expect(await journal.requiresReauthentication(), isFalse);
    expect(fence.ticket, isNull);
  });

  test('cancelled issuance while marker write waits sends no HTTP',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    store.pauseMarkerWrite = Completer<void>();
    final pending = entry.verifyPassword(username: 'u', password: 'p');
    await Future<void>.delayed(Duration.zero);
    final cancelled = entry.abandonChallenge();
    store.pauseMarkerWrite!.complete();
    await cancelled;
    await expectLater(pending, throwsStateError);
    expect(port.passwordCalls, 0);
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
  });

  test('concurrent double-submit is restricted to one issuance attempt',
      () async {
    expect(await entry.inspect(), NativeStartupDisposition.cleanLogin);
    store.pauseMarkerWrite = Completer<void>();
    final first = entry.verifyPassword(username: 'u', password: 'p');
    await Future<void>.delayed(Duration.zero);
    expect(
      () => entry.verifyPassword(username: 'u', password: 'p'),
      throwsStateError,
    );
    store.pauseMarkerWrite!.complete();
    await first;
    expect(port.passwordCalls, 1);
    expect(await vault.read(), _refresh);
  });

  test('regular coordinator alone cannot bypass the optional G10 commit',
      () async {
    // An opt-in G10 coordinator may be reached directly by test code; it
    // still requires an already durable marker and an empty vault.
    await expectLater(
      coordinator.verifyPassword(username: 'u', password: 'p'),
      throwsStateError,
    );
    expect(port.passwordCalls, 1);
    expect(port.markerPresentOnPassword, isFalse);
    expect(fence.ticket, isNull);
    expect(await vault.read(), isNull);
  });
}
