/// G8-PHONE: dedicated, offline, manual two-launch test of the real Android
/// flutter_secure_storage plugin. Not wired into main.dart or production auth.
/// The APK uses an isolated app ID and an additional G8-only store namespace.
/// Only synthetic public token-shape fixtures are ever written.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/native_api_endpoint.dart';
import '../api/native_refresh_credential_vault.dart';
import '../api/native_refresh_recovery_journal.dart';
import '../api/native_session_fence.dart';

class G8PhoneStorageCheck {
  static const _namespace = 'vencira_g8_phone_only_v1';
  static const _pidPreference = 'vencira.g8.phone.start_pid.v1';
  static const _refreshKey = 'vencira.mobile.dev.refresh.v1';
  static const _markerKey = 'vencira.mobile.dev.uncertain.v1';

  // Known test-only opaque token shapes, never real bearer/refresh secrets.
  static const _one = 'v1.r.0123456789abcdef0123456789abcdef.'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
  static const _two = 'v1.r.0123456789abcdef0123456789abcdef.'
      'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';

  static NativeSecretStore _newStore() => FlutterNativeSecretStore(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: _namespace,
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
    ),
  );

  static NativeApiEndpoint get _endpoint =>
      NativeApiEndpoint.parse('https://dev.vencira.es');

  static void _requireAndroid() {
    if (!Platform.isAndroid) {
      throw StateError('G8_PHONE_ANDROID_ONLY');
    }
  }

  static void _check(bool condition, String marker) {
    if (!condition) throw StateError(marker);
  }

  static Future<bool> hasPendingRestart() async {
    _requireAndroid();
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pidPreference);
  }

  /// Stage one: initialize only this app's isolated encrypted namespace, then
  /// persist a non-secret process ID in separate SharedPreferences. It is
  /// strictly a test-control value; no credentials use SharedPreferences.
  static Future<List<String>> prepare() async {
    _requireAndroid();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_pidPreference)) {
      throw StateError('G8_PENDING_RUN_MUST_FINISH_OR_CLEAN');
    }
    final store = _newStore();
    await store.delete(_refreshKey);
    await store.delete(_markerKey);
    _check(
      await store.read(_refreshKey) == null &&
          await store.read(_markerKey) == null,
      'G8_INITIAL_LAB_STORAGE_NOT_EMPTY',
    );
    final fence = NativeSessionFence();
    final vault = NativeRefreshCredentialVault(
      endpoint: _endpoint, store: store,
    );
    final journal = NativeRefreshRecoveryJournal(
      endpoint: _endpoint, store: store, fence: fence,
    );
    await vault.replace(_one);
    await journal.arm();
    _check(
      await vault.read() == _one &&
          await journal.requiresReauthentication() &&
          fence.ticket == null,
      'G8_PREPARE_PROTECTED_MARKER_MISSING',
    );
    final saved = await prefs.setInt(_pidPreference, pid);
    _check(saved, 'G8_PREPARE_PID_NOT_STORED');
    return const [
      'G8_PHONE_INITIAL_VAULT_VERIFIED=OK',
      'G8_PHONE_RECOVERY_MARKER_ARMED=OK',
      'G8_PHONE_RESTART_REQUIRED=1',
    ];
  }

  /// Stage two: demand a NEW Android process, not only a new Flutter widget.
  /// Force-stop from Android Settings > Apps or ADB before opening the app.
  static Future<List<String>> verifyAfterRestart() async {
    _requireAndroid();
    final prefs = await SharedPreferences.getInstance();
    final previousPid = prefs.getInt(_pidPreference);
    if (previousPid == null) {
      throw StateError('G8_PHONE_NO_PREPARED_TEST');
    }
    if (previousPid == pid) {
      throw StateError('G8_PHONE_FORCE_STOP_REQUIRED');
    }
    final store = _newStore();
    final fence = NativeSessionFence();
    final vault = NativeRefreshCredentialVault(
      endpoint: _endpoint, store: store,
    );
    final journal = NativeRefreshRecoveryJournal(
      endpoint: _endpoint, store: store, fence: fence,
    );
    _check(
      await vault.read() == _one &&
          await journal.requiresReauthentication() &&
          fence.ticket == null,
      'G8_PHONE_RESTART_DID_NOT_PRESERVE_ENCRYPTED_STATE',
    );
    // "prod" and "dev" have distinct logical key names even inside the
    // G8-only namespace and APK application ID.
    final prodVault = NativeRefreshCredentialVault(
      endpoint: NativeApiEndpoint.parse('https://vencira.es'),
      store: store,
    );
    _check(await prodVault.read() == null, 'G8_PHONE_ENVIRONMENT_KEY_COLLISION');

    await journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () => vault.replace(_two),
    );
    _check(
      await vault.read() == _two &&
          !await journal.requiresReauthentication() &&
          fence.ticket == null,
      'G8_PHONE_REAUTH_STORAGE_COMMIT_FAIL',
    );

    // An unexpected marker must cause a hard error, never unlock access.
    await store.write(_markerKey, 'invalid-g8-phone-marker');
    var corruptedDenied = false;
    try {
      await journal.requiresReauthentication();
    } on StateError {
      corruptedDenied = true;
    }
    _check(
      corruptedDenied && fence.ticket == null,
      'G8_PHONE_CORRUPT_MARKER_NOT_DENIED',
    );

    await cleanup();
    return const [
      'G8_PHONE_NEW_PROCESS_CONFIRMED=OK',
      'G8_PHONE_ENCRYPTED_REFRESH_SURVIVED=OK',
      'G8_PHONE_MARKER_SURVIVED=OK',
      'G8_PHONE_REAUTH_COMMIT=OK',
      'G8_PHONE_CORRUPT_MARKER_DENIED=OK',
      'G8_PHONE_STORAGE_CLEARED=OK',
      'G8_PHONE_PHYSICAL_STORAGE_RESULT=0',
    ];
  }

  /// Cleanup never enumerates or deletes the production app's keys: its
  /// separate Android application ID and storage namespace are untouchable.
  static Future<void> cleanup() async {
    _requireAndroid();
    final store = _newStore();
    await store.delete(_refreshKey);
    await store.delete(_markerKey);
    _check(
      await store.read(_refreshKey) == null &&
          await store.read(_markerKey) == null,
      'G8_PHONE_CLEANUP_FAILED',
    );
    final prefs = await SharedPreferences.getInstance();
    final gone = await prefs.remove(_pidPreference);
    _check(gone, 'G8_PHONE_PHASE_CLEANUP_FAILED');
  }
}
