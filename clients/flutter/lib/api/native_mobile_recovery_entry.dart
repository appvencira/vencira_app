import '../ui/native_login_screen.dart';
import 'native_mobile_startup_gate.dart';
import 'native_recovery_login_gateway.dart';
import 'native_session_fence.dart';

/// G9-B: restricted startup -> recovery route, with NO regular-login
/// fallback and NO HTTP endpoint creation. This is not wired into main.dart.
///
/// The normal/clean-login route deliberately remains UNIMPLEMENTED until a
/// reviewed pre-network credential-issuance checkpoint and safe logout exist.
/// Users must not connect NativeSessionCoordinator directly as an escape hatch.
class NativeMobileRecoveryEntry implements NativeLoginGateway {
  NativeMobileRecoveryEntry({
    required this.startup,
    required this.recovery,
  });

  final NativeMobileStartupGate startup;
  final NativeRecoveryLoginGateway recovery;

  bool _opening = false;
  bool _inspected = false;
  bool _readyForRecovery = false;

  NativeSessionFence get fence => startup.fence;

  /// Inspects storage before allowing ANY network-facing gateway operation.
  /// A clean first-login state is returned but is never authenticated here.
  /// A durable or orphan checkpoint unlocks ONLY full recovery, not refresh.
  Future<NativeStartupDisposition> inspect() async {
    if (_opening || _inspected) {
      throw StateError('Native startup entry already inspected');
    }
    _opening = true;
    _readyForRecovery = false;
    try {
      if (!identical(startup.fence, recovery.fence) ||
          !identical(startup.journal, recovery.journal) ||
          !identical(startup.vault, recovery.vault)) {
        startup.fence.revoke();
        recovery.fence.revoke();
        throw StateError('Native recovery entry dependencies mismatch');
      }

      final route = await startup.inspect();
      if (route == NativeStartupDisposition.fullReauthentication) {
        // Re-check that the durable marker survived the second read. The
        // gateway revokes the fence synchronously and cancels stale callbacks.
        if (!await recovery.requiresRecovery()) {
          throw StateError('Recovery checkpoint vanished during startup');
        }
        _readyForRecovery = true;
      }
      _inspected = true;
      return route;
    } catch (_) {
      startup.fence.revoke();
      _readyForRecovery = false;
      rethrow;
    } finally {
      _opening = false;
    }
  }

  void _requireRecoveryReady() {
    if (!_readyForRecovery || !_inspected) {
      throw StateError('Native recovery entry not authorized');
    }
  }

  @override
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  }) {
    _requireRecoveryReady();
    return recovery.verifyPassword(username: username, password: password);
  }

  @override
  Future<void> verifyTotp(String code) {
    _requireRecoveryReady();
    return recovery.verifyTotp(code);
  }

  @override
  Future<void> abandonChallenge() {
    _requireRecoveryReady();
    return recovery.abandonChallenge();
  }

  Future<String?> accessToken() async {
    if (!_readyForRecovery || !_inspected) return null;
    return recovery.accessToken();
  }
}
