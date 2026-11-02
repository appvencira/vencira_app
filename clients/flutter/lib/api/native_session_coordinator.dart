import 'dart:async';
import 'dart:convert';

import '../ui/native_login_screen.dart';
import 'native_mobile_token_shape.dart';
import 'native_refresh_credential_vault.dart';
import 'native_session_fence.dart';

/// All responses are provided by a FUTURE audited mobile-auth backend.
sealed class NativePasswordResponse {
  const NativePasswordResponse();
}

class NativePasswordMfaRequired extends NativePasswordResponse {
  const NativePasswordMfaRequired(this.challenge);
  final String challenge;
}

class NativePasswordGranted extends NativePasswordResponse {
  const NativePasswordGranted(this.tokens);
  final NativeIssuedTokens tokens;
}

class NativeIssuedTokens {
  const NativeIssuedTokens({required this.access, required this.refresh});
  final String access;
  final String refresh;
}

/// Abstract port: implementations MUST use the reviewed native HTTP contract,
/// never the existing Django web session or browser-based authentication.
abstract class NativeAuthPort {
  Future<NativePasswordResponse> password({
    required String username,
    required String password,
  });

  Future<NativeIssuedTokens> mfa({
    required String challenge,
    required String code,
  });

  Future<void> revoke({required String refresh});
}

/// Not installed in main.dart. No real HTTP adapter exists yet.
///
/// This enforces the *local* side of a future native session: refresh credentials
/// are written and read back from platform-protected storage before activation.
/// A previous asynchronous response cannot reopen a revoked session. It does not
/// authenticate users or grant permissions; that must happen on the server.
class NativeSessionCoordinator implements NativeLoginGateway {
  NativeSessionCoordinator({
    required this.port,
    required this.vault,
    required this.fence,
  });

  final NativeAuthPort port;
  final NativeRefreshCredentialVault vault;
  final NativeSessionFence fence;

  int _epoch = 0;
  String? _challenge;
  String? _access;
  DateTime? _accessDeadline;
  bool _busy = false;
  bool _logoutRequired = false;
  Future<void>? _logoutInProgress;
  Completer<void>? _finished;

  static final RegExp _challengeShape = RegExp(
    r'^lc1\.([0-9a-f]{32})\.([A-Za-z0-9_-]{43})$',
  );

  static bool _validChallenge(String challenge) {
    final match = _challengeShape.firstMatch(challenge);
    if (match == null) return false;
    final encoded = match.group(2)!;
    try {
      final bytes = base64Url.decode('$encoded=');
      return bytes.length == 32 &&
          base64UrlEncode(bytes).replaceAll('=', '') == encoded;
    } on FormatException {
      return false;
    }
  }

  void _start() {
    if (_busy || _logoutRequired || fence.ticket != null) {
      throw StateError('Native session transition unavailable');
    }
    _busy = true;
    _finished = Completer<void>();
  }

  void _end() {
    _busy = false;
    _finished?.complete();
    _finished = null;
  }

  Future<void> _revokeIssued(NativeIssuedTokens tokens) async {
    // Any network failure here must NEVER activate the local fence.
    try {
      if (NativeMobileTokenShape.accepts(tokens.refresh, kind: 'r')) {
        await port.revoke(refresh: tokens.refresh);
      }
    } catch (_) {
      // No local session is active, and the issued token is not retained.
      // The operational service needs expiry and an auditable cleanup policy.
    }
  }

  Future<void> _activate(NativeIssuedTokens tokens, int epoch) async {
    if (!NativeMobileTokenShape.accepts(tokens.access, kind: 'a') ||
        !NativeMobileTokenShape.accepts(tokens.refresh, kind: 'r')) {
      await _revokeIssued(tokens);
      throw StateError('Invalid native session credentials');
    }
    if (epoch != _epoch) {
      await _revokeIssued(tokens);
      throw StateError('Native login cancelled');
    }
    try {
      await vault.replace(tokens.refresh);
      if (epoch != _epoch) {
        throw StateError('Native login cancelled');
      }
      _access = tokens.access;
      // The server's 5-minute token remains authoritative. Use a shorter
      // local window to avoid sending obviously expired bearer credentials.
      _accessDeadline = DateTime.now().add(const Duration(minutes: 4));
      fence.activate();
    } catch (_) {
      _access = null;
      _accessDeadline = null;
      fence.revoke();
      try {
        await vault.clear();
      } catch (_) {
        // Storage failure must not become an apparent authentication success.
      }
      await _revokeIssued(tokens);
      rethrow;
    }
  }

  /// This is NOT a backend refresh operation. An expired access token returns
  /// null until a separate, audited refresh adapter exists.
  Future<String?> accessToken() async {
    if (fence.ticket == null || _access == null ||
        _accessDeadline == null ||
        !DateTime.now().isBefore(_accessDeadline!)) {
      return null;
    }
    return _access;
  }

  @override
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  }) async {
    if (_challenge != null) {
      throw StateError('Pending MFA must be abandoned first');
    }
    _start();
    final epoch = _epoch;
    try {
      final result = await port.password(
        username: username, password: password,
      );
      if (result is NativePasswordMfaRequired) {
        if (epoch != _epoch || !_validChallenge(result.challenge)) {
          throw StateError('Invalid or cancelled MFA challenge');
        }
        _challenge = result.challenge;
        return NativePasswordDecision.mfaRequired;
      }
      if (result is NativePasswordGranted) {
        await _activate(result.tokens, epoch);
        if (epoch != _epoch || fence.ticket == null) {
          throw StateError('Native login invalidated');
        }
        return NativePasswordDecision.authenticated;
      }
      throw StateError('Unexpected native password response');
    } finally {
      _end();
    }
  }

  @override
  Future<void> verifyTotp(String code) async {
    final challenge = _challenge;
    if (challenge == null || !RegExp(r'^\d{6}$').hasMatch(code)) {
      throw StateError('Native second factor unavailable');
    }
    _start();
    final epoch = _epoch;
    try {
      final tokens = await port.mfa(challenge: challenge, code: code);
      await _activate(tokens, epoch);
      if (epoch != _epoch || fence.ticket == null) {
        throw StateError('Native MFA completion invalidated');
      }
      _challenge = null;
    } finally {
      _end();
    }
  }

  @override
  Future<void> abandonChallenge() async {
    _epoch++;
    _challenge = null;
    // In-flight MFA/credential writes must finish cleaning up BEFORE a
    // caller may start a new native login on this coordinator.
    final pending = _finished?.future;
    if (pending != null) await pending;
  }

  /// Synchronously close the request gate first. The future only resolves
  /// after server-side revocation and secure storage cleanup both succeed.
  /// On failure the fence remains closed and vault content is retained for
  /// explicit retry; never report logout as successfully completed.
  Future<void> logout() {
    final existing = _logoutInProgress;
    if (existing != null) return existing;
    _logoutRequired = true;
    _epoch++;
    fence.revoke();
    _access = null;
    _accessDeadline = null;
    _challenge = null;
    final result = _finishLogout();
    _logoutInProgress = result;
    return result;
  }

  Future<void> _finishLogout() async {
    try {
      final pending = _finished?.future;
      if (pending != null) await pending;
      final refresh = await vault.read();
      if (refresh != null) await port.revoke(refresh: refresh);
      await vault.clear();
      _logoutRequired = false;
    } finally {
      // Failed server/storage cleanup leaves _logoutRequired=true. Another
      // logout() may retry; no new sign-in can start until then.
      _logoutInProgress = null;
    }
  }
}
