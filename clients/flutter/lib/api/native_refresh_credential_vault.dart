import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'native_api_endpoint.dart';

/// Low-level port for platform-protected secrets. Never use SharedPreferences.
abstract class NativeSecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Android encrypted storage and iOS Keychain, configured independently from
/// the existing alarm/consent stores. Not instantiated by the application yet.
class FlutterNativeSecretStore implements NativeSecretStore {
  FlutterNativeSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(
          aOptions: AndroidOptions(
            storageNamespace: 'vencira_mobile_refresh_v1',
            resetOnError: false,
            migrateOnAlgorithmChange: false,
          ),
          iOptions: IOSOptions(
            accountName: 'vencira_mobile_refresh_v1',
            accessibility: KeychainAccessibility.unlocked_this_device,
            synchronizable: false,
          ),
        );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Stores ONLY a future opaque refresh credential, never password, access
/// token, identity profile or workspace data. Requires a reviewed N1 backend.
/// An unsuccessful read/write/delete MUST block future session activation.
///
/// Environment-specific names avoid treating dev credentials as production.
class NativeRefreshCredentialVault {
  NativeRefreshCredentialVault({
    required NativeApiEndpoint endpoint,
    required NativeSecretStore store,
  }) : _store = store,
       _key = endpoint.origin.host == 'dev.vencira.es'
           ? 'vencira.mobile.dev.refresh.v1'
           : 'vencira.mobile.prod.refresh.v1';

  final NativeSecretStore _store;
  final String _key;

  static bool _valid(String credential) {
    if (credential.length < 32 || credential.length > 4096) return false;
    for (final codeUnit in credential.codeUnits) {
      final allowed =
          (codeUnit >= 48 && codeUnit <= 57) ||
          (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122) ||
          codeUnit == 45 || codeUnit == 46 || codeUnit == 95 ||
          codeUnit == 126 || codeUnit == 43 || codeUnit == 47 ||
          codeUnit == 61;
      if (!allowed) return false;
    }
    return true;
  }

  Future<String?> read() async {
    final credential = await _store.read(_key);
    if (credential != null && !_valid(credential)) {
      throw StateError('Invalid protected mobile credential');
    }
    return credential;
  }

  /// Replace is called only after server-approved refresh token rotation.
  /// Do not issue authenticated requests until a verified write succeeds.
  Future<void> replace(String credential) async {
    if (!_valid(credential)) {
      throw const FormatException('Invalid mobile credential');
    }
    await _store.write(_key, credential);
    if (await read() != credential) {
      throw StateError('Mobile credential write not verified');
    }
  }

  /// Called after synchronous session fence revocation and server revocation.
  /// If deletion cannot be verified, keep the session blocked and retry.
  Future<void> clear() async {
    await _store.delete(_key);
    if (await _store.read(_key) != null) {
      throw StateError('Mobile credential deletion not verified');
    }
  }
}
