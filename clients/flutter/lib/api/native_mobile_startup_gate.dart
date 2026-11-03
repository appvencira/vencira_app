import 'native_refresh_credential_vault.dart';
import 'native_refresh_recovery_journal.dart';
import 'native_session_fence.dart';

/// G9: a cold-start policy decision, NOT an authentication or HTTP adapter.
/// Neither [NativeStartupDisposition] can activate a session. In particular,
/// the clean-login path must not bypass the separate pre-network issuance
/// checkpoint required by G6; operational integration remains DISABLED.
enum NativeStartupDisposition { locked, cleanLogin, fullReauthentication }

/// Each instance is single-use: once inspected, a decision cannot be
/// downgraded to a clean login by repeating the inspection.
/// A new app process must construct a new instance and inspect storage again.
class NativeMobileStartupGate {
  NativeMobileStartupGate({
    required this.fence,
    required this.vault,
    required this.journal,
  });

  final NativeSessionFence fence;
  final NativeRefreshCredentialVault vault;
  final NativeRefreshRecoveryJournal journal;

  NativeStartupDisposition _disposition = NativeStartupDisposition.locked;
  Future<NativeStartupDisposition>? _inFlight;
  bool _inspected = false;

  NativeStartupDisposition get disposition => _disposition;

  /// Call before constructing any UI that can submit credentials. The fence
  /// is revoked SYNCHRONOUSLY, before any protected-storage async read.
  ///
  /// - Empty vault, no recovery marker -> clean login MAY be offered after
  ///   a separately reviewed issuance-checkpoint protocol is installed.
  /// - Existing marker -> full password/MFA recovery, NEVER refresh replay.
  /// - Orphan refresh without marker -> durably ARM recovery marker, then
  ///   request full reauthentication (account-wide backend revocation).
  /// - Any storage corruption, failed read/write, or wrong fence -> locked.
  ///
  /// No token value is returned or logged and NO network request is made.
  Future<NativeStartupDisposition> inspect() {
    if (!identical(journal.fence, fence)) {
      fence.revoke();
      _disposition = NativeStartupDisposition.locked;
      throw StateError('Native startup fence mismatch');
    }
    if (_inspected) return Future.value(_disposition);
    if (_inFlight != null) return _inFlight!;

    // The revocation must happen before the first await and before any
    // observer may retrieve a session ticket from the previous generation.
    fence.revoke();
    _disposition = NativeStartupDisposition.locked;

    final work = _inspectProtectedStorage();
    _inFlight = work;
    return work;
  }

  Future<NativeStartupDisposition> _inspectProtectedStorage() async {
    try {
      final markerExists = await journal.requiresReauthentication();
      final refresh = await vault.read();
      if (markerExists || refresh != null) {
        if (!markerExists) {
          // A previous mobile session with no checkpoint must never be
          // treated as an empty, safe first login. Preserve the old refresh
          // only for server-side account-wide recovery, never replay it.
          await journal.arm();
          if (!await journal.requiresReauthentication()) {
            throw StateError('Native startup marker verification failed');
          }
        }
        _disposition = NativeStartupDisposition.fullReauthentication;
      } else {
        _disposition = NativeStartupDisposition.cleanLogin;
      }
      _inspected = true;
      return _disposition;
    } catch (_) {
      fence.revoke();
      _disposition = NativeStartupDisposition.locked;
      rethrow;
    } finally {
      _inFlight = null;
    }
  }
}
