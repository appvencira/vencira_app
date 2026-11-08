// I8-O: failure-injection checks over a REAL Android secure-storage plugin.
// Only reachable from the dedicated I8-N/I8-O debug lab entrypoint.
// Never sends HTTP, issues tokens, or uses operational credentials.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/native_api_endpoint.dart';
import 'api/native_mobile_startup_gate.dart';
import 'api/native_refresh_credential_vault.dart';
import 'api/native_refresh_recovery_journal.dart';
import 'api/native_session_fence.dart';

const _syntheticOld = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _syntheticNew = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const _refreshKey = 'vencira.mobile.dev.refresh.v1';
const _journalKey = 'vencira.mobile.dev.uncertain.v1';

/// Single-purpose, controllable fault boundary. The underlying persistence
/// remains Android Keystore-backed; fault decisions never touch real data.
class _FaultStore implements NativeSecretStore {
  _FaultStore(this.delegate);

  final FlutterNativeSecretStore delegate;
  bool failMarkerWrite = false;
  bool failRefreshWrite = false;
  bool ignoreMarkerDelete = false;

  @override
  Future<String?> read(String key) => delegate.read(key);

  @override
  Future<void> write(String key, String value) {
    if ((failMarkerWrite && key == _journalKey) ||
        (failRefreshWrite && key == _refreshKey)) {
      return Future<void>.error(StateError('I8-O simulated write failure'));
    }
    return delegate.write(key, value);
  }

  @override
  Future<void> delete(String key) {
    if (ignoreMarkerDelete && key == _journalKey) {
      return Future<void>.value();
    }
    return delegate.delete(key);
  }
}

class _Scenario {
  _Scenario(this.store) {
    fence = NativeSessionFence();
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
        endpoint: endpoint, store: store, fence: fence);
    startup = NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal);
  }

  final _FaultStore store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final NativeMobileStartupGate startup;
}

Future<bool> _throws(Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    return true;
  }
  return false;
}

/// Exactly three fail-closed scenarios, verified with the Android plugin.
/// Always attempts to clear the TWO lab-owned keys, including on failures.
Future<String> runI8OAndroidStorageFaults() async {
  final real = FlutterNativeSecretStore(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'vencira_i8o_failure_lab_v1',
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
    ),
  );
  final store = _FaultStore(real);
  final scenario = _Scenario(store);
  final results = <String>[];

  try {
    await real.delete(_journalKey);
    await real.delete(_refreshKey);

    // 1. If the durable checkpoint cannot be written, no network request
    // would be permitted. No ticket can be activated by startup.
    store.failMarkerWrite = true;
    if (!await _throws(scenario.journal.arm) ||
        scenario.fence.ticket != null ||
        await scenario.journal.requiresReauthentication()) {
      throw StateError('Checkpoint write failure was not fenced');
    }
    store.failMarkerWrite = false;
    results.add('I8O_ANDROID_MARKER_WRITE_DENIED=PASS');

    // 2. Preserve the previous refresh and a durable marker if replacing
    // a newly issued token fails. Never promote an access ticket.
    await scenario.vault.replace(_syntheticOld);
    await scenario.journal.arm();
    store.failRefreshWrite = true;
    if (!await _throws(() => scenario.journal.confirmFullReauthentication(
          vault: scenario.vault,
          verifyAndReplace: () => scenario.vault.replace(_syntheticNew),
        )) ||
        scenario.fence.ticket != null ||
        await scenario.vault.read() != _syntheticOld ||
        !await scenario.journal.requiresReauthentication()) {
      throw StateError('Refresh write failure did not preserve checkpoint');
    }
    store.failRefreshWrite = false;
    results.add('I8O_ANDROID_REFRESH_WRITE_DENIED=PASS');

    // 3. Simulate an acknowledged storage delete that does not persist.
    // The journal's read-back must catch it; the old credential stays
    // blocked, including when a fresh startup object examines the store.
    store.ignoreMarkerDelete = true;
    if (!await _throws(() => scenario.journal.confirmFullReauthentication(
          vault: scenario.vault,
          verifyAndReplace: () => scenario.vault.replace(_syntheticNew),
        )) ||
        scenario.fence.ticket != null ||
        !await scenario.journal.requiresReauthentication()) {
      throw StateError('Marker delete failure escaped checkpoint');
    }
    store.ignoreMarkerDelete = false;
    final afterRestart = _Scenario(store);
    if (await afterRestart.startup.inspect() !=
            NativeStartupDisposition.fullReauthentication ||
        afterRestart.fence.ticket != null) {
      throw StateError('Startup incorrectly accepted uncertain credential');
    }
    results.add('I8O_ANDROID_MARKER_DELETE_DENIED=PASS');
    results.add('I8O_ANDROID_FAILURE_FENCE=PASS');
  } finally {
    // Fault flags must never obstruct removal of this separate lab namespace.
    store.failMarkerWrite = false;
    store.failRefreshWrite = false;
    store.ignoreMarkerDelete = false;
    await real.delete(_refreshKey);
    await real.delete(_journalKey);
    if (await real.read(_refreshKey) != null ||
        await real.read(_journalKey) != null) {
      throw StateError('I8-O lab storage cleanup failed');
    }
  }
  results.add('I8O_ANDROID_FAILURE_LAB_CLEANUP=PASS');
  return results.join('\n');
}
