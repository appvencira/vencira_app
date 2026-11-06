import '../ui/native_login_screen.dart';
import 'native_mobile_startup_gate.dart';
import 'native_refresh_recovery_journal.dart';
import 'native_session_coordinator.dart';

/// G10: narrowly scoped first issuance. Never installed in main.dart.
/// Only a G9-clean device can attempt password/MFA; a durable protected
/// checkpoint is written BEFORE the very first credential-issuing request.
/// No refresh/replay fallback, workspace access or issuer creation here.
class NativeFirstIssuanceEntry implements NativeLoginGateway {
  NativeFirstIssuanceEntry({
    required this.startup,
    required this.coordinator,
    required this.journal,
  });

  final NativeMobileStartupGate startup;
  final NativeSessionCoordinator coordinator;
  final NativeRefreshRecoveryJournal journal;

  bool _opening = false;
  bool _inspected = false;
  bool _clean = false;
  bool _attempted = false;
  bool _logoutRequested = false;
  bool _abandoned = false;

  Future<NativeStartupDisposition> inspect() async {
    if (_opening || _inspected) {
      throw StateError('First issuance startup already inspected');
    }
    _opening = true;
    try {
      if (!identical(startup.fence, coordinator.fence) ||
          !identical(startup.vault, coordinator.vault) ||
          !identical(startup.journal, journal) ||
          !identical(journal.fence, coordinator.fence) ||
          !identical(coordinator.firstIssuanceJournal, journal)) {
        startup.fence.revoke();
        coordinator.fence.revoke();
        throw StateError('First issuance dependency mismatch');
      }
      final disposition = await startup.inspect();
      _inspected = true;
      _clean = disposition == NativeStartupDisposition.cleanLogin;
      return disposition;
    } catch (_) {
      startup.fence.revoke();
      _clean = false;
      rethrow;
    } finally {
      _opening = false;
    }
  }

  void _requireAttempt() {
    if (!_inspected || !_clean || !_attempted ||
        _logoutRequested || _abandoned) {
      throw StateError('First issuance entry unavailable');
    }
  }

  @override
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  }) async {
    if (!_inspected || !_clean || _attempted || _logoutRequested) {
      throw StateError('First issuance preflight required');
    }
    // Single-use regardless of success/failure. A lost response, incorrect
    // password or cancelled MFA cannot silently retry without reauth.
    _attempted = true;

    // The old session fence is still closed. If another actor placed a
    // credential in the same vault after boot, refuse the normal issuance.
    if (await startup.vault.read() != null ||
        await journal.requiresReauthentication()) {
      throw StateError('First issuance storage changed after startup');
    }
    await journal.arm();
    if (!await journal.requiresReauthentication()) {
      throw StateError('First issuance journal not durable');
    }
    if (_abandoned || _logoutRequested) {
      throw StateError('First issuance cancelled before network');
    }
    // The earliest HTTP request is only after the checkpoint readback.
    return coordinator.verifyPassword(username: username, password: password);
  }

  @override
  Future<void> verifyTotp(String code) {
    _requireAttempt();
    return coordinator.verifyTotp(code);
  }

  @override
  Future<void> abandonChallenge() {
    _requireAttempt();
    _abandoned = true;
    return coordinator.abandonChallenge();
  }

  Future<String?> accessToken() async {
    if (!_inspected || !_clean || !_attempted ||
        _logoutRequested || _abandoned) {
      return null;
    }
    return coordinator.accessToken();
  }

  /// Synchronous fence close precedes remote revocation and secure deletion.
  /// A failed logout must not be reported as success or allow a new sign-in.
  Future<void> logout() {
    if (!_inspected || !_clean || !_attempted) {
      throw StateError('First issuance logout unavailable');
    }
    _logoutRequested = true;
    // A failed remote/storage cleanup may be retried with the same coordinator
    // while the fence stays closed. Never allow another password issuance.
    return coordinator.logout();
  }
}
