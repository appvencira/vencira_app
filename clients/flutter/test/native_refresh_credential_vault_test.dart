import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';

class FakeNativeSecretStore implements NativeSecretStore {
  final data = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  bool ignoreWrite = false;
  bool ignoreDelete = false;

  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('protected storage unavailable');
    return data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('write failed');
    if (!ignoreWrite) data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('delete failed');
    if (!ignoreDelete) data.remove(key);
  }
}

void main() {
  const token = 'synthetic-refresh-credential-for-unit-tests-only-1234';

  NativeRefreshCredentialVault vault(FakeNativeSecretStore store,
          {String origin = 'https://dev.vencira.es'}) =>
      NativeRefreshCredentialVault(
        endpoint: NativeApiEndpoint.parse(origin), store: store);

  test('writes, reads and verifies a protected refresh credential', () async {
    final store = FakeNativeSecretStore();
    final target = vault(store);
    expect(await target.read(), isNull);
    await target.replace(token);
    expect(await target.read(), token);
    await target.clear();
    expect(await target.read(), isNull);
  });

  test('dev and production credentials remain isolated', () async {
    final store = FakeNativeSecretStore();
    final dev = vault(store);
    final prod = vault(store, origin: 'https://vencira.es');
    await dev.replace(token);
    expect(await prod.read(), isNull);
    await prod.replace('synthetic-other-production-refresh-credential-5678');
    expect(await dev.read(), token);
    await dev.clear();
    expect(await prod.read(), isNotNull);
  });

  test('rejects malformed credential without touching storage', () async {
    final store = FakeNativeSecretStore();
    final target = vault(store);
    for (final bad in ['', 'short', 'secret\r\n' * 8,
        'contains whitespace and unsafe header characters!!!']) {
      await expectLater(target.replace(bad), throwsFormatException);
    }
    expect(store.data, isEmpty);
  });

  test('read rejects corrupted protected records', () async {
    final store = FakeNativeSecretStore();
    final target = vault(store);
    await target.replace(token);
    store.data[store.data.keys.single] = 'corrupted';
    await expectLater(target.read(), throwsStateError);
  });

  test('silent write and delete failures are detected', () async {
    final store = FakeNativeSecretStore();
    final target = vault(store);
    store.ignoreWrite = true;
    await expectLater(target.replace(token), throwsStateError);
    expect(await target.read(), isNull);
    store.ignoreWrite = false;
    await target.replace(token);
    store.ignoreDelete = true;
    await expectLater(target.clear(), throwsStateError);
    expect(await target.read(), token);
  });

  test('storage exceptions never become an apparent successful operation',
      () async {
    final store = FakeNativeSecretStore();
    final target = vault(store);
    store.failWrite = true;
    await expectLater(target.replace(token), throwsStateError);
    store.failWrite = false;
    await target.replace(token);
    store.failRead = true;
    await expectLater(target.read(), throwsStateError);
    await expectLater(target.replace(token), throwsStateError);
    store.failRead = false;
    store.failDelete = true;
    await expectLater(target.clear(), throwsStateError);
  });
}
