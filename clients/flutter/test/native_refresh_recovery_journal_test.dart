import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';

const first = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const second = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAE';

class DurableFakeSecretStore implements NativeSecretStore {
  final records = <String, String>{};
  bool failWrite = false;
  bool failDelete = false;
  bool silentlyIgnoreWrite = false;
  bool silentlyIgnoreDelete = false;

  @override
  Future<String?> read(String key) async => records[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Synthetic storage write failed');
    if (!silentlyIgnoreWrite) records[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('Synthetic storage delete failed');
    if (!silentlyIgnoreDelete) records.remove(key);
  }
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  late DurableFakeSecretStore storage;
  late NativeSessionFence fence;
  late NativeRefreshCredentialVault vault;
  late NativeRefreshRecoveryJournal journal;

  setUp(() {
    storage = DurableFakeSecretStore();
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(
      endpoint: endpoint, store: storage,
    );
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: storage, fence: fence,
    );
  });

  test('arm fences immediately and marker survives process restart',
      () async {
    await vault.replace(first);
    fence.activate();
    await journal.arm();
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
    final restartedFence = NativeSessionFence();
    final restarted = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: storage, fence: restartedFence,
    );
    expect(restartedFence.ticket, isNull);
    expect(await restarted.requiresReauthentication(), isTrue);
    expect(await vault.read(), first);
    // Old token must never be replayed by a future mobile coordinator.
  });

  test('successful recovery requires a new protected credential and erases marker',
      () async {
    await vault.replace(first);
    await journal.arm();
    await journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () => vault.replace(second),
    );
    expect(await journal.requiresReauthentication(), isFalse);
    expect(await vault.read(), second);
    expect(fence.ticket, isNull);
  });

  test('network failure leaves durable marker and session locked', () async {
    await vault.replace(first);
    await journal.arm();
    await expectLater(journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () async {
        throw StateError('Synthetic uncertain network response');
      },
    ), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), first);
    expect(fence.ticket, isNull);
  });

  test('server did not return a new refresh: cannot clear marker', () async {
    await vault.replace(first);
    await journal.arm();
    await expectLater(journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () => vault.replace(first),
    ), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(fence.ticket, isNull);
  });

  test('protected marker write failure forbids any HTTP exchange', () async {
    storage.silentlyIgnoreWrite = true;
    await expectLater(journal.arm(), throwsStateError);
    expect(fence.ticket, isNull);
    storage.silentlyIgnoreWrite = false;
    storage.failWrite = true;
    await expectLater(journal.arm(), throwsStateError);
    expect(fence.ticket, isNull);
  });

  test('marker erase failure remains recoverable after restart', () async {
    await vault.replace(first);
    await journal.arm();
    storage.silentlyIgnoreDelete = true;
    await expectLater(journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () => vault.replace(second),
    ), throwsStateError);
    expect(await journal.requiresReauthentication(), isTrue);
    final restarted = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: storage,
      fence: NativeSessionFence(),
    );
    expect(await restarted.requiresReauthentication(), isTrue);
  });

  test('unexpected local activation during recovery is immediately revoked',
      () async {
    await vault.replace(first);
    await journal.arm();
    await expectLater(journal.confirmFullReauthentication(
      vault: vault,
      verifyAndReplace: () async {
        await vault.replace(second);
        fence.activate();
      },
    ), throwsStateError);
    expect(fence.ticket, isNull);
    expect(await journal.requiresReauthentication(), isTrue);
  });

  test('corrupted journal fails closed and cannot be silently cleared',
      () async {
    await journal.arm();
    final key = storage.records.keys.single;
    storage.records[key] = 'unexpected';
    await expectLater(
      journal.requiresReauthentication(), throwsStateError,
    );
    await expectLater(journal.arm(), throwsStateError);
  });

  test('dev and production recovery markers are isolated', () async {
    await journal.arm();
    final prod = NativeRefreshRecoveryJournal(
      endpoint: NativeApiEndpoint.parse('https://vencira.es'),
      store: storage, fence: NativeSessionFence(),
    );
    expect(await prod.requiresReauthentication(), isFalse);
    expect(await journal.requiresReauthentication(), isTrue);
  });
}
