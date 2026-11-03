// G8 candidate: Android-only device-level protected-store integration test.
// NEVER installed as a production app entry point and NEVER contacts a server.
// The test runs only in a dedicated disposable Android emulator with an
// empty es.vencira.vencira package, enforced by scripts/g8_android_store_lab.sh.
//
// All data below are fixed synthetic token-shape fixtures, not credentials.
// Critically, this test injects an isolated flutter_secure_storage namespace,
// distinct from the native application's reserved refresh namespace.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';

const _labNamespace = 'vencira_g8_emulator_credential_lab_v1';
const _devRefreshKey = 'vencira.mobile.dev.refresh.v1';
const _devJournalKey = 'vencira.mobile.dev.uncertain.v1';

const _syntheticRefreshOne =
    'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _syntheticRefreshTwo =
    'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';

FlutterNativeSecretStore _newLabStore() {
  return FlutterNativeSecretStore(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: _labNamespace,
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
    ),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'G8 isolated Android plugin secure store: write / reopen / recovery / erase',
    (tester) async {
      if (!Platform.isAndroid) {
        throw StateError('G8_ANDROID_ONLY_REQUIRED');
      }

      final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
      final store = _newLabStore();
      final vault = NativeRefreshCredentialVault(
        endpoint: endpoint, store: store,
      );
      final fence = NativeSessionFence();
      final journal = NativeRefreshRecoveryJournal(
        endpoint: endpoint, store: store, fence: fence,
      );

      // This prefix lives exclusively in _labNamespace. Clean abandoned
      // synthetic values from a previously interrupted G8 run; do not
      // enumerate, read or delete ANY operational application namespace.
      await store.delete(_devRefreshKey);
      await store.delete(_devJournalKey);
      try {
        expect(await vault.read(), isNull);
        expect(await journal.requiresReauthentication(), isFalse);
        await vault.replace(_syntheticRefreshOne);
        expect(await vault.read(), _syntheticRefreshOne);
        expect(fence.ticket, isNull);

        await journal.arm();
        expect(await journal.requiresReauthentication(), isTrue);
        expect(fence.ticket, isNull);

        // Reconstruct plugin and Dart objects. The same protected Android
        // namespace must survive object disposal; unlike a fake map store,
        // this goes through the actual platform plugin and Android Keystore.
        final reopenedStore = _newLabStore();
        final reopenedVault = NativeRefreshCredentialVault(
          endpoint: endpoint, store: reopenedStore,
        );
        final reopenedFence = NativeSessionFence();
        final reopenedJournal = NativeRefreshRecoveryJournal(
          endpoint: endpoint,
          store: reopenedStore,
          fence: reopenedFence,
        );
        expect(await reopenedVault.read(), _syntheticRefreshOne);
        expect(await reopenedJournal.requiresReauthentication(), isTrue);
        expect(reopenedFence.ticket, isNull);

        // Dev/prod key names are disjoint even inside the synthetic namespace.
        final prodVault = NativeRefreshCredentialVault(
          endpoint: NativeApiEndpoint.parse('https://vencira.es'),
          store: reopenedStore,
        );
        expect(await prodVault.read(), isNull);

        // A verified replacement must not activate the request fence.
        await reopenedJournal.confirmFullReauthentication(
          vault: reopenedVault,
          verifyAndReplace: () => reopenedVault.replace(
            _syntheticRefreshTwo,
          ),
        );
        expect(await reopenedVault.read(), _syntheticRefreshTwo);
        expect(await reopenedJournal.requiresReauthentication(), isFalse);
        expect(reopenedFence.ticket, isNull);

        // Corrupt the lab marker and verify that a cold-start read rejects
        // the value, rather than unlocking or erasing it implicitly.
        await reopenedStore.write(_devJournalKey, 'invalid-marker-g8-lab');
        await expectLater(
          reopenedJournal.requiresReauthentication(),
          throwsStateError,
        );
        expect(reopenedFence.ticket, isNull);
      } finally {
        // Cleanup errors FAIL the test: never claim a successful device gate
        // while the synthetic protected credentials remain on the emulator.
        await store.delete(_devRefreshKey);
        await store.delete(_devJournalKey);
        expect(await store.read(_devRefreshKey), isNull);
        expect(await store.read(_devJournalKey), isNull);
      }
      // No secrets or storage values may be printed.
      // ignore: avoid_print
      print('G8_ANDROID_PROTECTED_STORE_RESULT=0');
    },
  );
}
