// G12 isolated Android-only test flow. No real account, network or backend.
// This exercises the actual flutter_secure_storage Android plugin, G9 boot,
// G10 first issuance/logout and G6 MFA recovery across a REAL process restart.
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/native_api_endpoint.dart';
import '../api/native_first_issuance_entry.dart';
import '../api/native_mobile_recovery_entry.dart';
import '../api/native_mobile_startup_gate.dart';
import '../api/native_recovery_login_gateway.dart';
import '../api/native_refresh_credential_vault.dart';
import '../api/native_refresh_recovery_journal.dart';
import '../api/native_session_coordinator.dart';
import '../api/native_session_fence.dart';
import '../ui/native_login_screen.dart';

const _markerKey = 'vencira.mobile.dev.uncertain.v1';
const _refreshKey = 'vencira.mobile.dev.refresh.v1';
const _pidKey = 'vencira.g12.synthetic.restart_pid.v1';
const _username = 'g12-public-test-only';
const _password = 'g12-public-synthetic-only';
const _totp = '123456';
const _challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _accessA = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _refreshA = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _accessB = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const _refreshB = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';

class _SyntheticPort implements NativeAuthPort, NativeRecoveryAuthPort {
  _SyntheticPort({required this.journal, required this.fence});

  final NativeRefreshRecoveryJournal journal;
  final NativeSessionFence fence;
  bool issueMfa = false;
  bool loseIssueResponse = false;
  bool failNextRevoke = false;
  int passwordCalls = 0;
  int mfaCalls = 0;
  int recoveryCalls = 0;
  int revokeCalls = 0;
  bool simulatedRemoteIssueBeforeLoss = false;

  Future<void> _assertCheckpoint() async {
    if (fence.ticket != null || !await journal.requiresReauthentication()) {
      throw StateError('G12_SYNTHETIC_PORT_MISSING_DURABLE_CHECKPOINT');
    }
  }

  void _assertFakeIdentity(String username, String password) {
    if (username != _username || password != _password) {
      throw StateError('G12_SYNTHETIC_IDENTITY_ONLY');
    }
  }

  @override
  Future<NativePasswordResponse> password({
    required String username,
    required String password,
  }) async {
    _assertFakeIdentity(username, password);
    await _assertCheckpoint();
    passwordCalls++;
    if (loseIssueResponse) {
      simulatedRemoteIssueBeforeLoss = true;
      throw StateError('G12_SYNTHETIC_ISSUED_RESPONSE_LOST');
    }
    if (issueMfa) return const NativePasswordMfaRequired(_challenge);
    return const NativePasswordGranted(
      NativeIssuedTokens(access: _accessA, refresh: _refreshA),
    );
  }

  @override
  Future<NativeIssuedTokens> mfa({
    required String challenge,
    required String code,
  }) async {
    await _assertCheckpoint();
    if (challenge != _challenge || code != _totp) {
      throw StateError('G12_SYNTHETIC_MFA_REJECTED');
    }
    mfaCalls++;
    return const NativeIssuedTokens(access: _accessA, refresh: _refreshA);
  }

  @override
  Future<NativePasswordResponse> recoverPassword({
    required String username,
    required String password,
  }) async {
    _assertFakeIdentity(username, password);
    await _assertCheckpoint();
    recoveryCalls++;
    return const NativePasswordMfaRequired(_challenge);
  }

  @override
  Future<NativeIssuedTokens> recoverMfa({
    required String challenge,
    required String code,
  }) async {
    await _assertCheckpoint();
    if (challenge != _challenge || code != _totp) {
      throw StateError('G12_SYNTHETIC_RECOVERY_MFA_REJECTED');
    }
    mfaCalls++;
    return const NativeIssuedTokens(access: _accessB, refresh: _refreshB);
  }

  @override
  Future<void> revoke({required String refresh}) async {
    await _assertCheckpoint();
    if (refresh != _refreshA && refresh != _refreshB) {
      throw StateError('G12_SYNTHETIC_REVOKE_UNKNOWN_TOKEN');
    }
    revokeCalls++;
    if (failNextRevoke) {
      failNextRevoke = false;
      throw StateError('G12_SYNTHETIC_REMOTE_REVOCATION_FAILED');
    }
  }
}

class _IssuanceCase {
  _IssuanceCase(NativeSecretStore store) {
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: G12PhoneAuthCheck._endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: G12PhoneAuthCheck._endpoint, store: store, fence: fence,
    );
    port = _SyntheticPort(journal: journal, fence: fence);
    coordinator = NativeSessionCoordinator(
      port: port, vault: vault, fence: fence, firstIssuanceJournal: journal,
    );
    entry = NativeFirstIssuanceEntry(
      startup: NativeMobileStartupGate(fence: fence, vault: vault, journal: journal),
      coordinator: coordinator, journal: journal,
    );
  }

  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final _SyntheticPort port;
  late final NativeSessionCoordinator coordinator;
  late final NativeFirstIssuanceEntry entry;
}

class G12PhoneAuthCheck {
  static const _namespace = 'vencira_g12_phone_only_v1';

  static NativeApiEndpoint get _endpoint =>
      NativeApiEndpoint.parse('https://dev.vencira.es');

  static NativeSecretStore _newStore() => FlutterNativeSecretStore(
    storage: const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: _namespace,
        resetOnError: false,
        migrateOnAlgorithmChange: false,
      ),
    ),
  );

  static void _androidOnly() {
    if (!Platform.isAndroid) throw StateError('G12_ANDROID_DEVICE_ONLY');
  }

  static void _check(bool condition, String code) {
    if (!condition) throw StateError(code);
  }

  static Future<bool> hasPendingRestart() async {
    _androidOnly();
    return (await SharedPreferences.getInstance()).containsKey(_pidKey);
  }

  /// Phase 1 does NOT use an HTTP client. _SyntheticPort is a
  /// non-network fake, with fixed PUBLIC tokens and OTP test vectors.
  /// It leaves only an uncertain-issuance marker plus a nonsecret PID.
  static Future<List<String>> prepare() async {
    _androidOnly();
    final prefs = await SharedPreferences.getInstance();
    _check(!prefs.containsKey(_pidKey), 'G12_PENDING_RESTART_MUST_FINISH');
    final store = _newStore();
    _check(await store.read(_refreshKey) == null &&
        await store.read(_markerKey) == null,
        'G12_DIRTY_TEST_VAULT_CLEAN_MANUALLY');

    final plain = _IssuanceCase(store);
    _check(await plain.entry.inspect() == NativeStartupDisposition.cleanLogin,
        'G12_FIRST_ISSUE_NOT_CLEAN');
    _check(await plain.entry.verifyPassword(username: _username, password: _password)
        == NativePasswordDecision.authenticated &&
        plain.port.passwordCalls == 1 &&
        await plain.vault.read() == _refreshA &&
        !await plain.journal.requiresReauthentication() &&
        plain.fence.ticket != null &&
        await plain.entry.accessToken() == _accessA,
        'G12_FIRST_ISSUE_PROTECTED_COMMIT_FAILED');
    final firstClose = plain.entry.logout();
    _check(plain.fence.ticket == null, 'G12_LOGOUT_NOT_SYNCHRONOUS');
    await firstClose;
    _check(plain.port.revokeCalls == 1 &&
        await plain.vault.read() == null &&
        !await plain.journal.requiresReauthentication(),
        'G12_SUCCESSFUL_LOGOUT_UNVERIFIED');

    final mfa = _IssuanceCase(store);
    mfa.port.issueMfa = true;
    _check(await mfa.entry.inspect() == NativeStartupDisposition.cleanLogin,
        'G12_MFA_INITIAL_GATE_FAILED');
    _check(await mfa.entry.verifyPassword(username: _username, password: _password)
        == NativePasswordDecision.mfaRequired &&
        mfa.fence.ticket == null &&
        await mfa.journal.requiresReauthentication(),
        'G12_MFA_BEFORE_TOTP_UNSAFE');
    await mfa.entry.verifyTotp(_totp);
    _check(mfa.port.mfaCalls == 1 &&
        mfa.fence.ticket != null &&
        await mfa.vault.read() == _refreshA &&
        !await mfa.journal.requiresReauthentication(),
        'G12_MFA_PROTECTED_COMMIT_FAILED');
    await mfa.entry.logout();
    _check(await mfa.vault.read() == null &&
        !await mfa.journal.requiresReauthentication(),
        'G12_MFA_LOGOUT_FAILED');

    final fault = _IssuanceCase(store);
    _check(await fault.entry.inspect() == NativeStartupDisposition.cleanLogin,
        'G12_FAULT_INITIAL_GATE_FAILED');
    await fault.entry.verifyPassword(username: _username, password: _password);
    fault.port.failNextRevoke = true;
    var failedClosed = false;
    try {
      await fault.entry.logout();
    } on StateError {
      failedClosed = true;
    }
    _check(failedClosed && fault.fence.ticket == null &&
        await fault.entry.accessToken() == null &&
        await fault.journal.requiresReauthentication() &&
        await fault.vault.read() == _refreshA &&
        fault.port.revokeCalls == 1,
        'G12_FAULT_LOGOUT_NOT_DURABLE');
    await fault.entry.logout();
    _check(fault.port.revokeCalls == 2 &&
        await fault.vault.read() == null &&
        !await fault.journal.requiresReauthentication(),
        'G12_FAULT_LOGOUT_RETRY_FAILED');

    final lost = _IssuanceCase(store);
    _check(await lost.entry.inspect() == NativeStartupDisposition.cleanLogin,
        'G12_UNCERTAIN_ISSUE_NOT_CLEAN');
    lost.port.loseIssueResponse = true;
    var uncertainDenied = false;
    try {
      await lost.entry.verifyPassword(username: _username, password: _password);
    } on StateError {
      uncertainDenied = true;
    }
    _check(uncertainDenied && lost.port.simulatedRemoteIssueBeforeLoss &&
        lost.port.passwordCalls == 1 &&
        lost.fence.ticket == null &&
        await lost.vault.read() == null &&
        await lost.journal.requiresReauthentication(),
        'G12_UNCERTAIN_ISSUE_NOT_FENCED');

    _check(await prefs.setInt(_pidKey, pid), 'G12_RESTART_PID_NOT_SAVED');
    return const [
      'G12_ANDROID_FIRST_ISSUE_PROTECTED=OK',
      'G12_ANDROID_NORMAL_LOGOUT=OK',
      'G12_ANDROID_MFA_BEFORE_ACCESS=OK',
      'G12_ANDROID_FAILED_LOGOUT_RETRY=OK',
      'G12_ANDROID_LOST_ISSUE_MARKER=OK',
      'G12_ANDROID_FORCE_STOP_REQUIRED=1',
    ];
  }

  /// Phase 2 uses the SAME physical secure namespace but an entirely new
  /// fence/journal/gateway. PID must differ after Android's force-stop.
  static Future<List<String>> verifyAfterRestart() async {
    _androidOnly();
    final prefs = await SharedPreferences.getInstance();
    final before = prefs.getInt(_pidKey);
    _check(before != null, 'G12_NO_PREPARED_RESTART');
    _check(before != pid, 'G12_REAL_PROCESS_RESTART_REQUIRED');

    final store = _newStore();
    final fence = NativeSessionFence();
    final vault = NativeRefreshCredentialVault(endpoint: _endpoint, store: store);
    final journal = NativeRefreshRecoveryJournal(
      endpoint: _endpoint, store: store, fence: fence,
    );
    _check(fence.ticket == null &&
        await journal.requiresReauthentication() &&
        await vault.read() == null,
        'G12_MARKER_NOT_PERSISTED_ACROSS_RESTART');

    final prod = NativeRefreshCredentialVault(
      endpoint: NativeApiEndpoint.parse('https://vencira.es'), store: store,
    );
    _check(await prod.read() == null, 'G12_DEV_PROD_KEY_COLLISION');

    final port = _SyntheticPort(journal: journal, fence: fence);
    final recovery = NativeMobileRecoveryEntry(
      startup: NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal,
      ),
      recovery: NativeRecoveryLoginGateway(
        port: port, journal: journal, vault: vault, fence: fence,
      ),
    );
    _check(await recovery.inspect() == NativeStartupDisposition.fullReauthentication &&
        fence.ticket == null,
        'G12_RESTART_BOOT_NOT_RECOVERY');
    _check(await recovery.verifyPassword(username: _username, password: _password)
        == NativePasswordDecision.mfaRequired &&
        fence.ticket == null &&
        await journal.requiresReauthentication(),
        'G12_RECOVERY_PASSWORD_UNSAFE');
    await recovery.verifyTotp(_totp);
    _check(port.recoveryCalls == 1 && port.mfaCalls == 1 &&
        fence.ticket != null &&
        await vault.read() == _refreshB &&
        !await journal.requiresReauthentication() &&
        await recovery.accessToken() == _accessB,
        'G12_PHYSICAL_RECOVERY_NOT_COMMITTED');

    // Recovery gateway currently has no public safe-logout method.
    // Explicitly verify the SAME G10 journal logout primitives here;
    // do not claim an integrated recovery UI logout was validated.
    await journal.arm(); // synchronously closes fence before any fake revoke
    await port.revoke(refresh: _refreshB);
    await vault.clear();
    await journal.confirmLogoutCompleted(vault: vault);
    _check(fence.ticket == null &&
        await vault.read() == null &&
        !await journal.requiresReauthentication(),
        'G12_RECOVERY_CLEANUP_NOT_VERIFIED');

    // A corrupted marker must always be rejected, never silently cleared.
    await store.write(_markerKey, 'g12-corrupted-synthetic-marker');
    var corruptDenied = false;
    try {
      await journal.requiresReauthentication();
    } on StateError {
      corruptDenied = true;
    }
    _check(corruptDenied && fence.ticket == null,
        'G12_CORRUPT_MARKER_ACCEPTED');

    await cleanup();
    return const [
      'G12_ANDROID_NEW_PROCESS_CONFIRMED=OK',
      'G12_ANDROID_PENDING_MARKER_SURVIVED=OK',
      'G12_ANDROID_G9_RECOVERY_ONLY=OK',
      'G12_ANDROID_MFA_RECOVERY_COMMITTED=OK',
      'G12_ANDROID_CORRUPT_MARKER_DENIED=OK',
      'G12_ANDROID_STORAGE_CLEARED=OK',
      'G12_ANDROID_PHYSICAL_AUTH_RESULT=0',
    ];
  }

  /// Deletes ONLY G12 debug app's own protected namespace keys, never an
  /// operational app store or user account. Manual action on failure.
  static Future<void> cleanup() async {
    _androidOnly();
    final store = _newStore();
    await store.delete(_refreshKey);
    await store.delete(_markerKey);
    _check(await store.read(_refreshKey) == null &&
        await store.read(_markerKey) == null,
        'G12_MANUAL_CLEANUP_UNVERIFIED');
    final prefs = await SharedPreferences.getInstance();
    _check(await prefs.remove(_pidKey), 'G12_PHASE_PID_CLEANUP_FAILED');
  }
}
