import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_mobile_recovery_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const oldRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const newRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const newAccess = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const recoveryChallenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const refreshKey = 'vencira.mobile.dev.refresh.v1';

http.Response jsonResponse(Map<String, Object> value, {int status = 200}) =>
    http.Response(jsonEncode(value), status, headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store, max-age=0',
    });

class _DurableStore implements NativeSecretStore {
  final values = <String, String>{};
  bool failFreshWrite = false;
  bool loseMarkerDeletion = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (key == refreshKey && failFreshWrite) {
      throw StateError('synthetic protected write failure');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (loseMarkerDeletion && key.endsWith('uncertain.v1')) return;
    values.remove(key);
  }
}

class _Harness {
  _Harness(this.store, this.client) {
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    final gateway = NativeRecoveryLoginGateway(
      port: port, journal: journal, vault: vault, fence: fence,
    );
    entry = NativeMobileRecoveryEntry(
      startup: NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal,
      ),
      recovery: gateway,
    );
  }

  static final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  final _DurableStore store;
  final http.Client client;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final NativeMobileRecoveryEntry entry;
}

void main() {
  test('I8-L orphan credential: real JSON port, MFA and protected commit',
      () async {
    final store = _DurableStore()..values[refreshKey] = oldRefresh;
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      expect(request.url.host, 'dev.vencira.es');
      expect(request.url.scheme, 'https');
      expect(request.followRedirects, isFalse);
      expect(request.headers['Cookie'], isNull);
      expect(request.headers['Authorization'], isNull);
      if (request.url.path.endsWith('/recover/password/')) {
        expect(jsonDecode(request.body), {
          'username': 'synthetic', 'password': 'synthetic-password',
        });
        return jsonResponse({
          'status': 'mfa_required', 'challenge': recoveryChallenge,
        });
      }
      if (request.url.path.endsWith('/recover/mfa/')) {
        expect(jsonDecode(request.body), {
          'challenge': recoveryChallenge, 'code': '123456',
        });
        return jsonResponse({
          'status': 'authenticated', 'access': newAccess, 'refresh': newRefresh,
        });
      }
      return jsonResponse({'error': 'native_auth_unavailable'}, status: 404);
    });

    final harness = _Harness(store, client);
    expect(await harness.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await harness.journal.requiresReauthentication(), isTrue);
    expect(harness.fence.ticket, isNull);
    expect(await harness.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), NativePasswordDecision.mfaRequired);
    expect(await harness.entry.accessToken(), isNull);
    expect(await harness.vault.read(), oldRefresh);
    await harness.entry.verifyTotp('123456');
    expect(await harness.entry.accessToken(), newAccess);
    expect(harness.fence.ticket, isNotNull);
    expect(await harness.vault.read(), newRefresh);
    expect(await harness.journal.requiresReauthentication(), isFalse);
    expect(paths, [
      '/api/v1/mobile/auth/recover/password/',
      '/api/v1/mobile/auth/recover/mfa/',
    ]);
    client.close();
  });

  test('I8-L hostile password-only token response never activates a session',
      () async {
    final store = _DurableStore()..values[refreshKey] = oldRefresh;
    final client = MockClient((_) async => jsonResponse({
      'status': 'authenticated', 'access': newAccess, 'refresh': newRefresh,
    }));
    final harness = _Harness(store, client);
    expect(await harness.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    await expectLater(harness.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), throwsA(isA<NativeHttpAuthFailure>()));
    expect(harness.fence.ticket, isNull);
    expect(await harness.vault.read(), oldRefresh);
    expect(await harness.journal.requiresReauthentication(), isTrue);
    client.close();
  });

  test('I8-L ambiguous MFA response keeps marker and prior vault sealed',
      () async {
    final store = _DurableStore()..values[refreshKey] = oldRefresh;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/recover/password/')) {
        return jsonResponse({
          'status': 'mfa_required', 'challenge': recoveryChallenge,
        });
      }
      // Server may already have committed: do NOT retry MFA on timeout.
      throw TimeoutException('synthetic lost recovery response');
    });
    final harness = _Harness(store, client);
    expect(await harness.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await harness.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), NativePasswordDecision.mfaRequired);
    await expectLater(harness.entry.verifyTotp('123456'),
        throwsA(isA<NativeHttpAuthFailure>()));
    expect(harness.fence.ticket, isNull);
    expect(await harness.entry.accessToken(), isNull);
    expect(await harness.vault.read(), oldRefresh);
    expect(await harness.journal.requiresReauthentication(), isTrue);
    client.close();
  });

  test('I8-L failed protected write never exposes recovered bearer',
      () async {
    final store = _DurableStore()..values[refreshKey] = oldRefresh;
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.endsWith('/recover/password/')) {
        return jsonResponse({
          'status': 'mfa_required', 'challenge': recoveryChallenge,
        });
      }
      if (request.url.path.endsWith('/recover/mfa/')) {
        return jsonResponse({
          'status': 'authenticated', 'access': newAccess,
          'refresh': newRefresh,
        });
      }
      // I8-K deliberately has no single-device revoke endpoint. Marker
      // MUST remain until full account recovery is completed again.
      return jsonResponse({'error': 'native_auth_unavailable'}, status: 404);
    });
    final harness = _Harness(store, client);
    expect(await harness.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await harness.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), NativePasswordDecision.mfaRequired);
    store.failFreshWrite = true;
    await expectLater(harness.entry.verifyTotp('123456'), throwsStateError);
    expect(harness.fence.ticket, isNull);
    expect(await harness.entry.accessToken(), isNull);
    expect(await harness.vault.read(), oldRefresh);
    expect(await harness.journal.requiresReauthentication(), isTrue);
    expect(paths, [
      '/api/v1/mobile/auth/recover/password/',
      '/api/v1/mobile/auth/recover/mfa/',
      '/api/v1/mobile/token/revoke/',
    ]);
    client.close();
  });

  test('I8-L corrupt startup marker blocks all HTTP calls',
      () async {
    final store = _DurableStore()
      ..values['vencira.mobile.dev.uncertain.v1'] = 'corrupted';
    var count = 0;
    final client = MockClient((_) async {
      count++;
      return jsonResponse({'status': 'mfa_required'});
    });
    final harness = _Harness(store, client);
    await expectLater(harness.entry.inspect(), throwsStateError);
    expect(() => harness.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), throwsStateError);
    expect(count, 0);
    expect(harness.fence.ticket, isNull);
    client.close();
  });

  test('I8-L a second process remains fenced after ambiguous MFA result',
      () async {
    final store = _DurableStore()..values[refreshKey] = oldRefresh;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/recover/password/')) {
        return jsonResponse({
          'status': 'mfa_required', 'challenge': recoveryChallenge,
        });
      }
      return jsonResponse({'error': 'native_auth_unavailable'}, status: 401);
    });
    final first = _Harness(store, client);
    expect(await first.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await first.entry.verifyPassword(
      username: 'synthetic', password: 'synthetic-password',
    ), NativePasswordDecision.mfaRequired);
    await expectLater(first.entry.verifyTotp('123456'),
        throwsA(isA<NativeHttpAuthFailure>()));
    final restart = _Harness(store, client);
    expect(await restart.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(restart.fence.ticket, isNull);
    expect(await restart.entry.accessToken(), isNull);
    expect(await restart.journal.requiresReauthentication(), isTrue);
    client.close();
  });
}
