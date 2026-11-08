// I8-N: Android Keystore persistence across independent test processes.
// Run seed, verify, cleanup as separate invocations on a dedicated test APK.
// Never makes HTTP calls, never uses credentials from DEV or production.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';

const _enabled = bool.fromEnvironment('VENCIRA_I8N_ANDROID_LAB');
const _phase = String.fromEnvironment('VENCIRA_I8N_PHASE');
const _refreshKey = 'vencira.mobile.dev.refresh.v1';
const _markerKey = 'vencira.mobile.dev.uncertain.v1';
const _syntheticRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

class _Lab {
  _Lab() {
    // The storage namespace is isolated from the actual VENCIRA application
    // even if someone accidentally runs the test under a normal package.
    store = FlutterNativeSecretStore(
      storage: const FlutterSecureStorage(
        aOptions: AndroidOptions(
          storageNamespace: 'vencira_i8n_restart_lab_v1',
          resetOnError: false,
          migrateOnAlgorithmChange: false,
        ),
      ),
    );
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(
      endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
      store: store,
    );
    journal = NativeRefreshRecoveryJournal(
      endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
      store: store,
      fence: fence,
    );
  }

  late final FlutterNativeSecretStore store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
}

Future<void> _seed() async {
  final lab = _Lab();
  // The dedicated lab namespace contains no real credentials. Reset only
  // the two fixed keys this test itself owns, never delete an app namespace.
  await lab.store.delete(_markerKey);
  await lab.vault.clear();
  await lab.vault.replace(_syntheticRefresh);
  await lab.journal.arm();
  expect(lab.fence.ticket, isNull);
  expect(await lab.vault.read(), _syntheticRefresh);
  expect(await lab.journal.requiresReauthentication(), isTrue);
  print('I8N_ANDROID_KEYSTORE_SEED=PASS');
}

Future<void> _verify() async {
  // A completely new _Lab must reconstruct all controller instances.
  // For a genuine process-restart claim, run THIS phase in a separate
  // instrumentation invocation after the seed phase has exited.
  final lab = _Lab();
  expect(await lab.vault.read(), _syntheticRefresh);
  expect(await lab.journal.requiresReauthentication(), isTrue);
  final startup = NativeMobileStartupGate(
    fence: lab.fence, vault: lab.vault, journal: lab.journal,
  );
  expect(await startup.inspect(),
      NativeStartupDisposition.fullReauthentication);
  expect(lab.fence.ticket, isNull);
  print('I8N_ANDROID_RESTART_RECOVERY_FENCED=PASS');
}

Future<void> _cleanup() async {
  final lab = _Lab();
  await lab.vault.clear();
  await lab.store.delete(_markerKey);
  expect(await lab.vault.read(), isNull);
  expect(await lab.journal.requiresReauthentication(), isFalse);
  final startup = NativeMobileStartupGate(
    fence: lab.fence, vault: lab.vault, journal: lab.journal,
  );
  expect(await startup.inspect(), NativeStartupDisposition.cleanLogin);
  expect(lab.fence.ticket, isNull);
  print('I8N_ANDROID_KEYSTORE_CLEANUP=PASS');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final supported = _enabled && Platform.isAndroid &&
      const {'seed', 'verify', 'cleanup'}.contains(_phase);
  testWidgets('I8-N Android protected refresh and journal: $_phase',
      (tester) async {
    if (_phase == 'seed') {
      await _seed();
    } else if (_phase == 'verify') {
      await _verify();
    } else if (_phase == 'cleanup') {
      await _cleanup();
    } else {
      fail('Unrecognized Android lab phase');
    }
  }, skip: !supported);
}
