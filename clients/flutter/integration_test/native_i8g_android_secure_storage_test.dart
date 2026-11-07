/// I8-G physical Android secure-storage verification. Test ONLY.
///
/// No Django connection, real credentials or operational storage namespace.
/// Use an isolated Android debug test package and remove test data on exit.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';

const _synthetic = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _syntheticNext = 'v1.r.fedcba9876543210fedcba9876543210.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

NativeRefreshCredentialVault _vault() {
  // Explicitly test-only namespace; NEVER use the default production vault.
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'vencira_i8g_device_disposable_v1',
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
  );
  return NativeRefreshCredentialVault(
    endpoint: NativeApiEndpoint.parse('https://dev.vencira.es'),
    store: FlutterNativeSecretStore(storage: storage),
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('I8-G actual Android Keystore-backed refresh lifecycle',
      (tester) async {
    if (kIsWeb || !Platform.isAndroid ||
        defaultTargetPlatform != TargetPlatform.android ||
        const bool.fromEnvironment('VENCIRA_I8G_DEVICE_TEST') != true) {
      fail('I8G_PHYSICAL_ANDROID_DEBUG_ONLY');
    }
    final vault = _vault();
    try {
      // Prevent reuse of previous synthetic material from an interrupted run.
      await vault.clear();
      expect(await vault.read(), isNull);
      await vault.replace(_synthetic);
      expect(await vault.read(), _synthetic);
      // Recreating wrappers must retrieve from native persistent backing,
      // not from the in-memory Dart vault instance.
      expect(await _vault().read(), _synthetic);
      await vault.replace(_syntheticNext);
      expect(await _vault().read(), _syntheticNext);
      await vault.clear();
      expect(await _vault().read(), isNull);
      // This is a test marker; it asserts a platform round-trip, NOT
      // hardware-backed key attestation or survival of an app process kill.
      // Avoid printing the credential itself.
      // ignore: avoid_print
      print('NATIVE_I8G_ANDROID_SECURE_STORAGE_ROUNDTRIP=PASS');
    } finally {
      // Always attempt cleanup; a cleanup error MUST fail the test.
      await vault.clear();
      expect(await vault.read(), isNull);
    }
  });
}
