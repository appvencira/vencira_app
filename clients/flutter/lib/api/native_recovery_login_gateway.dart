import 'dart:async';
import 'dart:convert';

import '../ui/native_login_screen.dart';
import 'native_mobile_token_shape.dart';
import 'native_refresh_credential_vault.dart';
import 'native_refresh_recovery_journal.dart';
import 'native_session_coordinator.dart';
import 'native_session_fence.dart';

/// Only the distinct full-reauthentication endpoints are permitted here.
/// In particular this port has NO refresh/rotate method and MUST NOT
/// silently fall back to the previous one-use refresh credential.
abstract class NativeRecoveryAuthPort {
  Future<NativePasswordResponse> recoverPassword({
    required String username,
    required String password,
  });

  Future<NativeIssuedTokens> recoverMfa({
    required String challenge,
    required String code,
  });

  Future<void> revoke({required String refresh});
}

/// G6 prototype for the native login widget after a durable uncertain-token
/// marker. Does not handle ordinary login, install routes or authorize rollout.
///
/// The server MUST make recoverPassword/recoverMfa revoke all prior devices
/// after fresh password + MFA verification. All access remains closed until
/// secure storage has been replaced and the journal erased and verified.
/// This class is NOT constructed from main.dart.
class NativeRecoveryLoginGateway implements NativeLoginGateway {
  NativeRecoveryLoginGateway({
    required this.port,
    required this.journal,
    required this.vault,
    required this.fence,
  });

  final NativeRecoveryAuthPort port;
  final NativeRefreshRecoveryJournal journal;
  final NativeRefreshCredentialVault vault;
  final NativeSessionFence fence;

  int _epoch = 0;
  bool _busy = false;
  String? _challenge;
  String? _access;
  DateTime? _accessDeadline;
  Completer<void>? _finished;

  static final RegExp _challengePattern =
      RegExp(r'^(?:lc1|or1)\.[0-9a-f]{32}\.([A-Za-z0-9_-]{43})$');

  static bool _validChallenge(String value) {
    final match = _challengePattern.firstMatch(value);
    if (match == null) return false;
    final encoded = match.group(1)!;
    try {
      final decoded = base64Url.decode('$encoded=');
      return decoded.length == 32 &&
          base64UrlEncode(decoded).replaceAll('=', '') == encoded;
    } on FormatException {
      return false;
    }
  }

  void _start() {
    if (_busy || fence.ticket != null) {
      throw StateError('Native recovery transition unavailable');
    }
    _busy = true;
    _finished = Completer<void>();
  }

  void _end() {
    _busy = false;
    _finished?.complete();
    _finished = null;
  }

  /// A cold-start session stays locked; this never restores a prior access
  /// token, even if the secure vault still contains a refresh credential.
  Future<bool> requiresRecovery() async {
    // Invalidate any pending callback before consulting protected storage.
    // A delayed network result must never activate after cold-start reset.
    _epoch++;
    fence.revoke();
    _challenge = null;
    _access = null;
    _accessDeadline = null;
    final pending = _finished?.future;
    if (pending != null) await pending;
    return journal.requiresReauthentication();
  }

  Future<String?> accessToken() async {
    if (fence.ticket == null ||
        _access == null ||
        _accessDeadline == null ||
        !DateTime.now().isBefore(_accessDeadline!)) {
      return null;
    }
    return _access;
  }

  Future<void> _confirm(NativeIssuedTokens tokens, int epoch) async {
    if (!NativeMobileTokenShape.accepts(tokens.access, kind: 'a') ||
        !NativeMobileTokenShape.accepts(tokens.refresh, kind: 'r')) {
      throw StateError('Invalid recovered session credentials');
    }
    try {
      if (epoch != _epoch) throw StateError('Native recovery cancelled');
      await journal.confirmFullReauthentication(
        vault: vault,
        verifyAndReplace: () async {
          if (epoch != _epoch) {
            throw StateError('Native recovery cancelled');
          }
          await vault.replace(tokens.refresh);
          if (epoch != _epoch) {
            throw StateError('Native recovery cancelled');
          }
        },
      );
      if (epoch != _epoch) throw StateError('Native recovery cancelled');
      _access = tokens.access;
      _accessDeadline = DateTime.now().add(const Duration(minutes: 4));
      fence.activate();
    } catch (_) {
      fence.revoke();
      _access = null;
      _accessDeadline = null;
      // A cancellation can race with the marker's successful deletion.
      // Re-arm it before any later request can be issued.
      try {
        await journal.arm();
      } catch (_) {
        // Never claim safe recovery or allow a normal login when journal
        // storage is unavailable. Nothing is wired in the live application.
      }
      try {
        await port.revoke(refresh: tokens.refresh);
      } catch (_) {
        // Keep the durable recovery marker: the next fully authenticated
        // recovery revokes all orphaned sessions, not a replay of refresh.
      }
      rethrow;
    }
  }

  @override
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  }) async {
    if (_challenge != null) {
      throw StateError('Pending MFA challenge must be abandoned');
    }
    _start();
    final epoch = _epoch;
    try {
      if (!await journal.requiresReauthentication() || epoch != _epoch) {
        throw StateError('Native recovery checkpoint required');
      }
      final response = await port.recoverPassword(
        username: username, password: password,
      );
      if (epoch != _epoch) throw StateError('Native recovery cancelled');
      if (response is NativePasswordMfaRequired) {
        if (!_validChallenge(response.challenge)) {
          throw StateError('Invalid recovered MFA challenge');
        }
        _challenge = response.challenge;
        return NativePasswordDecision.mfaRequired;
      }
      // I8-L: a password response is NEVER sufficient for full recovery.
      // Even a future non-HTTP recovery port cannot bypass fresh MFA.
      // Tokens may enter _confirm only from recoverMfa.
      throw StateError('Recovery requires a separate MFA challenge');
    } finally {
      _end();
    }
  }

  @override
  Future<void> verifyTotp(String code) async {
    final challenge = _challenge;
    if (challenge == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw StateError('Native recovery MFA unavailable');
    }
    _start();
    final epoch = _epoch;
    try {
      if (!await journal.requiresReauthentication() || epoch != _epoch) {
        throw StateError('Native recovery checkpoint required');
      }
      final tokens = await port.recoverMfa(
        challenge: challenge, code: code,
      );
      await _confirm(tokens, epoch);
      _challenge = null;
    } finally {
      _end();
    }
  }

  @override
  Future<void> abandonChallenge() async {
    _epoch++;
    fence.revoke();
    _challenge = null;
    _access = null;
    _accessDeadline = null;
    final pending = _finished?.future;
    if (pending != null) await pending;
  }
}
