import 'native_api_endpoint.dart';
import 'native_refresh_credential_vault.dart';
import 'native_session_fence.dart';

/// Protected G6 crash marker. NOT installed in main.dart or a live session.
///
/// Contract: arm() MUST finish before any network operation that may issue or
/// rotate a token. A crashed application starts with an inactive fence; the
/// presence of the marker REQUIRES password + MFA reauthentication through the
/// independently reviewed account-wide revocation endpoint. Never replay the
/// old one-use refresh. No token or secret is stored in this marker.
class NativeRefreshRecoveryJournal {
  NativeRefreshRecoveryJournal({
    required NativeApiEndpoint endpoint,
    required NativeSecretStore store,
    required this.fence,
  }) : _store = store,
       _key = endpoint.origin.host == 'dev.vencira.es'
           ? 'vencira.mobile.dev.uncertain.v1'
           : 'vencira.mobile.prod.uncertain.v1';

  final NativeSecretStore _store;
  final NativeSessionFence fence;
  final String _key;
  Future<void> _previous = Future<void>.value();
  static const String _pending = 'full-reauth-required-v1';

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _previous.then((_) => action());
    _previous = next.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return next;
  }

  /// Permanently fence the previous session before writing a durable marker.
  /// If this fails, do not send any password, MFA or refresh HTTP request.
  Future<void> arm() {
    fence.revoke();
    return _serial(() async {
      final existing = await _store.read(_key);
      if (existing != null && existing != _pending) {
        throw StateError('Corrupted recovery journal');
      }
      await _store.write(_key, _pending);
      if (await _store.read(_key) != _pending) {
        throw StateError('Recovery marker not durably stored');
      }
    });
  }

  /// At cold start, no caller may activate an old access/refresh credential.
  /// Malformed protected storage MUST block rather than silently downgrade.
  Future<bool> requiresReauthentication() => _serial(() async {
    final existing = await _store.read(_key);
    if (existing == null) return false;
    if (existing != _pending) {
      throw StateError('Corrupted recovery journal');
    }
    return true;
  });

  /// Called ONLY after a NEW full password/MFA verification that revokes all
  /// prior device sessions on the server. The injected callback MUST replace
  /// and verify the new refresh in secure storage. This journal cannot itself
  /// attest server identity; operational integration remains blocked.
  ///
  /// The fence stays closed until the marker is verifiably erased. If the app
  /// dies in between, it repeats full reauthentication, never stale refresh.
  Future<void> confirmFullReauthentication({
    required NativeRefreshCredentialVault vault,
    required Future<void> Function() verifyAndReplace,
  }) {
    fence.revoke();
    return _serial(() async {
      final marker = await _store.read(_key);
      if (marker != _pending) {
        throw StateError('No valid recovery checkpoint');
      }
      final previous = await vault.read();
      try {
        await verifyAndReplace();
        if (fence.ticket != null) {
          throw StateError('Session activated before recovery commit');
        }
        final next = await vault.read();
        if (next == null || next == previous) {
          throw StateError('No verified fresh protected credential');
        }
        await _store.delete(_key);
        if (await _store.read(_key) != null) {
          throw StateError('Recovery checkpoint deletion not verified');
        }
      } catch (_) {
        fence.revoke();
        rethrow;
      }
    });
  }
  /// G10 first issuance differs from full *account-wide* recovery: only an
  /// EMPTY protected vault may enter this commit. The durable journal must
  /// already be armed BEFORE the password/MFA HTTP request was sent.
  /// The session fence stays closed until refresh storage and marker erase
  /// are both read-back verified. On any failure a new full account recovery
  /// is required; never retry the potentially committed issuance.
  Future<void> confirmFirstIssuance({
    required NativeRefreshCredentialVault vault,
    required Future<void> Function() verifyAndReplace,
  }) {
    fence.revoke();
    return _serial(() async {
      if (await _store.read(_key) != _pending) {
        throw StateError('First issuance checkpoint missing');
      }
      if (await vault.read() != null) {
        throw StateError('First issuance requires an empty protected vault');
      }
      try {
        await verifyAndReplace();
        if (fence.ticket != null || await vault.read() == null) {
          throw StateError('First issuance storage commit not verified');
        }
        await _store.delete(_key);
        if (await _store.read(_key) != null) {
          throw StateError('First issuance marker deletion not verified');
        }
      } catch (_) {
        fence.revoke();
        rethrow;
      }
    });
  }

  /// G10 logout completion: caller MUST have verified remote revocation and
  /// vault.clear() before invoking this. The checkpoint remains durable if
  /// revocation, vault removal or marker deletion cannot be verified.
  Future<void> confirmLogoutCompleted({
    required NativeRefreshCredentialVault vault,
  }) {
    fence.revoke();
    return _serial(() async {
      if (await _store.read(_key) != _pending) {
        throw StateError('Logout checkpoint missing');
      }
      if (await vault.read() != null) {
        throw StateError('Logout credential still protected');
      }
      await _store.delete(_key);
      if (await _store.read(_key) != null) {
        throw StateError('Logout checkpoint deletion not verified');
      }
    });
  }

}
