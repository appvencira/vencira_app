import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';

const syntheticRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _markerKey = 'vencira.mobile.dev.uncertain.v1';

class _ProtectedStore implements NativeSecretStore {
  final values = <String, String>{};
  bool denyRead = false;
  bool denyWrite = false;
  bool swallowWrites = false;
  Completer<void>? delayedRead;
  int readCalls = 0;

  @override
  Future<String?> read(String key) async {
    readCalls++;
    final wait = delayedRead;
    if (wait != null) await wait.future;
    if (denyRead) throw StateError('synthetic protected read denied');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (denyWrite) throw StateError('synthetic protected write denied');
    if (!swallowWrites) values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  late _ProtectedStore store;
  late NativeSessionFence fence;
  late NativeRefreshCredentialVault vault;
  late NativeRefreshRecoveryJournal journal;
  late NativeMobileStartupGate boot;

  setUp(() {
    store = _ProtectedStore();
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    boot = NativeMobileStartupGate(
      fence: fence, vault: vault, journal: journal,
    );
  });

  test('no keys: closed fence, no token, clean login disposition', () async {
    fence.activate();
    final result = boot.inspect();
    expect(fence.ticket, isNull);
    expect(boot.disposition, NativeStartupDisposition.locked);
    expect(await result, NativeStartupDisposition.cleanLogin);
    expect(fence.ticket, isNull);
    expect(store.values, isEmpty);
  });

  test('durable marker alone always requires full recovery', () async {
    await journal.arm();
    expect(await boot.inspect(), NativeStartupDisposition.fullReauthentication);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(fence.ticket, isNull);
  });

  test('orphan refresh is fenced and gets durable marker before recovery', () async {
    await vault.replace(syntheticRefresh);
    fence.activate();
    final result = boot.inspect();
    expect(fence.ticket, isNull);
    expect(await result, NativeStartupDisposition.fullReauthentication);
    expect(await journal.requiresReauthentication(), isTrue);
    expect(await vault.read(), syntheticRefresh);
    expect(fence.ticket, isNull);
  });

  test('orphan marker write denied: cannot request recovery or login', () async {
    await vault.replace(syntheticRefresh);
    store.denyWrite = true;
    await expectLater(boot.inspect(), throwsStateError);
    expect(boot.disposition, NativeStartupDisposition.locked);
    expect(fence.ticket, isNull);
    expect(store.values.containsKey(_markerKey), isFalse);
    store.denyWrite = false;
    expect(await boot.inspect(), NativeStartupDisposition.fullReauthentication);
    expect(await journal.requiresReauthentication(), isTrue);
  });

  test('silently ignored orphan marker write fails closed', () async {
    await vault.replace(syntheticRefresh);
    store.swallowWrites = true;
    await expectLater(boot.inspect(), throwsStateError);
    expect(boot.disposition, NativeStartupDisposition.locked);
    expect(fence.ticket, isNull);
    expect(await vault.read(), syntheticRefresh);
    store.swallowWrites = false;
    expect(await boot.inspect(), NativeStartupDisposition.fullReauthentication);
    expect(await journal.requiresReauthentication(), isTrue);
  });

  test('corrupted journal never downgrades to clean login', () async {
    store.values[_markerKey] = 'tampered';
    await expectLater(boot.inspect(), throwsStateError);
    expect(boot.disposition, NativeStartupDisposition.locked);
    expect(fence.ticket, isNull);
    expect(store.values[_markerKey], 'tampered');
  });

  test('protected storage read failure keeps gate locked', () async {
    store.denyRead = true;
    fence.activate();
    await expectLater(boot.inspect(), throwsStateError);
    expect(fence.ticket, isNull);
    expect(boot.disposition, NativeStartupDisposition.locked);
    store.denyRead = false;
    expect(await boot.inspect(), NativeStartupDisposition.cleanLogin);
    expect(fence.ticket, isNull);
  });

  test('concurrent inspections share one locked transition', () async {
    store.delayedRead = Completer<void>();
    fence.activate();
    final first = boot.inspect();
    final second = boot.inspect();
    expect(fence.ticket, isNull);
    expect(boot.disposition, NativeStartupDisposition.locked);
    expect(identical(first, second), isTrue);
    store.delayedRead!.complete();
    expect(await first, NativeStartupDisposition.cleanLogin);
    expect(await second, NativeStartupDisposition.cleanLogin);
    expect(boot.disposition, NativeStartupDisposition.cleanLogin);
  });

  test('previous recovery result cannot be reclassified by repeat boot', () async {
    await vault.replace(syntheticRefresh);
    expect(await boot.inspect(), NativeStartupDisposition.fullReauthentication);
    store.values.clear();
    expect(await boot.inspect(), NativeStartupDisposition.fullReauthentication);
    expect(fence.ticket, isNull);
  });

  test('wrong journal fence fails without any protected read', () async {
    final foreignFence = NativeSessionFence()..activate();
    final foreignJournal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: foreignFence,
    );
    final mismatched = NativeMobileStartupGate(
      fence: fence, vault: vault, journal: foreignJournal,
    );
    fence.activate();
    expect(() => mismatched.inspect(), throwsStateError);
    expect(fence.ticket, isNull);
    expect(store.readCalls, 0);
  });

  test('dev boot does not interpret unrelated production refresh', () async {
    final prodVault = NativeRefreshCredentialVault(
      endpoint: NativeApiEndpoint.parse('https://vencira.es'),
      store: store,
    );
    await prodVault.replace(syntheticRefresh);
    expect(await boot.inspect(), NativeStartupDisposition.cleanLogin);
    expect(await prodVault.read(), syntheticRefresh);
    expect(fence.ticket, isNull);
  });
}
