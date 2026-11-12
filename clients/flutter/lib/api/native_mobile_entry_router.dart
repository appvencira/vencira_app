import '../ui/native_login_screen.dart';
import 'native_first_issuance_entry.dart';
import 'native_mobile_recovery_entry.dart';
import 'native_mobile_startup_gate.dart';
import 'native_session_fence.dart';

/// D28: single-use decision between first issuance and account-wide recovery.
///
/// This is candidate-only composition, NOT wired to main.dart. It cannot
/// authenticate or construct HTTP clients; injected entries must use the
/// same protected storage, journal and session fence. Never interpret
/// fullReauthentication as permission to perform an ordinary password login.
class NativeMobileEntryRouter {
  NativeMobileEntryRouter({
    required this.startup,
    required this.firstIssuance,
    required this.recovery,
  });

  final NativeMobileStartupGate startup;
  final NativeFirstIssuanceEntry firstIssuance;
  final NativeMobileRecoveryEntry recovery;

  NativeSessionFence get fence => startup.fence;
  bool _started = false;
  NativeLoginGateway? _selected;
  NativeStartupDisposition? _route;

  NativeStartupDisposition? get disposition => _route;

  NativeLoginGateway get gateway {
    final selected = _selected;
    if (selected == null) {
      throw StateError('Native mobile entry not authorized');
    }
    return selected;
  }

  Future<NativeStartupDisposition> inspect() async {
    if (_started) {
      throw StateError('Native mobile route already inspected');
    }
    _started = true;
    fence.revoke();
    if (!identical(startup, firstIssuance.startup) ||
        !identical(startup, recovery.startup) ||
        !identical(startup.fence, firstIssuance.coordinator.fence) ||
        !identical(startup.fence, recovery.fence) ||
        !identical(startup.vault, firstIssuance.coordinator.vault) ||
        !identical(startup.vault, recovery.recovery.vault) ||
        !identical(startup.journal, firstIssuance.journal) ||
        !identical(startup.journal, recovery.recovery.journal)) {
      throw StateError('Native mobile route dependency mismatch');
    }
    try {
      final disposition = await startup.inspect();
      switch (disposition) {
        case NativeStartupDisposition.cleanLogin:
          final verified = await firstIssuance.inspect();
          if (verified != disposition) {
            throw StateError('First issuance route changed during preflight');
          }
          _selected = firstIssuance;
        case NativeStartupDisposition.fullReauthentication:
          final verified = await recovery.inspect();
          if (verified != disposition) {
            throw StateError('Recovery route changed during preflight');
          }
          _selected = recovery;
        case NativeStartupDisposition.locked:
          throw StateError('Native secure storage unavailable');
      }
      _route = disposition;
      return disposition;
    } catch (_) {
      _selected = null;
      _route = null;
      fence.revoke();
      rethrow;
    }
  }
}
