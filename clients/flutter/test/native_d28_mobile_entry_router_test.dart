import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_first_issuance_entry.dart';
import 'package:vencira/api/native_mobile_entry_router.dart';
import 'package:vencira/api/native_mobile_recovery_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';

class _Store implements NativeSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
}

class _FirstPort implements NativeAuthPort {
  @override
  Future<NativePasswordResponse> password({
    required String username, required String password,
  }) async => throw StateError('Network must not be called');
  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge, required String code,
  }) async => throw StateError('Network must not be called');
  @override
  Future<void> revoke({required String refresh}) async =>
      throw StateError('Network must not be called');
}

class _RecoveryPort implements NativeRecoveryAuthPort {
  @override
  Future<NativePasswordResponse> recoverPassword({
    required String username, required String password,
  }) async => throw StateError('Network must not be called');
  @override
  Future<NativeIssuedTokens> recoverMfa({
    required String challenge, required String code,
  }) async => throw StateError('Network must not be called');
  @override
  Future<void> revoke({required String refresh}) async =>
      throw StateError('Network must not be called');
}

class _Harness {
  _Harness(this.store) {
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    startup = NativeMobileStartupGate(
      fence: fence, vault: vault, journal: journal,
    );
    first = NativeFirstIssuanceEntry(
      startup: startup,
      coordinator: NativeSessionCoordinator(
        port: _FirstPort(), vault: vault, fence: fence,
        firstIssuanceJournal: journal,
      ),
      journal: journal,
    );
    recovery = NativeMobileRecoveryEntry(
      startup: startup,
      recovery: NativeRecoveryLoginGateway(
        port: _RecoveryPort(), journal: journal,
        vault: vault, fence: fence,
      ),
    );
    router = NativeMobileEntryRouter(
      startup: startup, firstIssuance: first, recovery: recovery,
    );
  }
  final _Store store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final NativeMobileStartupGate startup;
  late final NativeFirstIssuanceEntry first;
  late final NativeMobileRecoveryEntry recovery;
  late final NativeMobileEntryRouter router;
}

void main() {
  test('clean protected store chooses only checked first-issuance gateway',
      () async {
    final h = _Harness(_Store());
    expect(() => h.router.gateway, throwsStateError);
    expect(await h.router.inspect(), NativeStartupDisposition.cleanLogin);
    expect(h.router.gateway, same(h.first));
    expect(h.router.disposition, NativeStartupDisposition.cleanLogin);
    expect(h.fence.ticket, isNull);
    await expectLater(h.router.inspect(), throwsStateError);
  });

  test('orphan refresh opens recovery only and leaves marker durable', () async {
    final store = _Store()..values['vencira.mobile.dev.refresh.v1'] =
        'v1.r.0123456789abcdef0123456789abcdef.'
        'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
    final h = _Harness(store);
    expect(await h.router.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(h.router.gateway, same(h.recovery));
    expect(await h.journal.requiresReauthentication(), isTrue);
    expect(h.fence.ticket, isNull);
  });

  test('corrupt marker refuses any gateway or fallback to first issuance',
      () async {
    final store = _Store()
      ..values['vencira.mobile.dev.uncertain.v1'] = 'corrupt';
    final h = _Harness(store);
    await expectLater(h.router.inspect(), throwsStateError);
    expect(() => h.router.gateway, throwsStateError);
    expect(h.fence.ticket, isNull);
  });

  test('dependency mismatch fails before selecting any route', () async {
    final h = _Harness(_Store());
    final other = _Harness(_Store());
    final broken = NativeMobileEntryRouter(
      startup: h.startup, firstIssuance: other.first, recovery: h.recovery,
    );
    await expectLater(broken.inspect(), throwsStateError);
    expect(() => broken.gateway, throwsStateError);
    expect(h.fence.ticket, isNull);
  });
}
