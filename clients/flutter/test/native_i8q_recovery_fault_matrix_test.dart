// I8-Q: deterministic network ambiguity + protected write failures.
// Uses the real NativeHttpAuthPort and recovery coordinator; only HTTP and
// storage fault boundaries are synthetic. No production/mobile entrypoint.
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

const _old = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _new = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const _access = 'v1.a.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAQ';
const _challenge = 'lc1.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _refreshKey = 'vencira.mobile.dev.refresh.v1';
const _markerKey = 'vencira.mobile.dev.uncertain.v1';

http.Response _json(Map<String, String> body) => http.Response(
      jsonEncode(body), 200,
      headers: {'content-type': 'application/json',
        'cache-control': 'no-store, max-age=0'},
    );

class _FaultStore implements NativeSecretStore {
  final values = <String, String>{_refreshKey: _old};
  bool denyFreshWrite = false;
  bool ignoreMarkerDelete = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (denyFreshWrite && key == _refreshKey && value != _old) {
      throw StateError('synthetic protected storage failure');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (ignoreMarkerDelete && key == _markerKey) return;
    values.remove(key);
  }
}

class _Rig {
  _Rig(this.store, http.Client client) {
    fence = NativeSessionFence();
    final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
        endpoint: endpoint, store: store, fence: fence);
    final gateway = NativeRecoveryLoginGateway(
      port: NativeHttpAuthPort(endpoint: endpoint, client: client),
      journal: journal, vault: vault, fence: fence,
    );
    entry = NativeMobileRecoveryEntry(
      startup: NativeMobileStartupGate(
          fence: fence, vault: vault, journal: journal),
      recovery: gateway,
    );
  }

  final _FaultStore store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final NativeMobileRecoveryEntry entry;
}

Future<void> _checkColdStart(_FaultStore store) async {
  final fence = NativeSessionFence();
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  final vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
  final journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence);
  final startup = NativeMobileStartupGate(
      fence: fence, vault: vault, journal: journal);
  expect(await startup.inspect(), NativeStartupDisposition.fullReauthentication);
  expect(fence.ticket, isNull);
  expect(await journal.requiresReauthentication(), isTrue);
}

void main() {
  test('I8-Q timeout before password reply: checkpoint and fence survive',
      () async {
    final store = _FaultStore();
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      expect(request.url.path, '/api/v1/mobile/auth/recover/password/');
      throw TimeoutException('synthetic transport loss before password reply');
    });
    final rig = _Rig(store, client);
    expect(await rig.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    await expectLater(
      rig.entry.verifyPassword(
          username: 'synthetic', password: 'synthetic-password'),
      throwsA(isA<NativeHttpAuthFailure>()),
    );
    expect(calls, 1);
    expect(rig.fence.ticket, isNull);
    expect(await rig.entry.accessToken(), isNull);
    expect(await rig.vault.read(), _old);
    await _checkColdStart(store);
    client.close();
    print('I8Q_PASSWORD_TIMEOUT_FENCED=PASS');
  });

  test('I8-Q lost post-MFA reply: no retry or unknown token promotion',
      () async {
    final store = _FaultStore();
    var passwordCalls = 0;
    var mfaCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/recover/password/')) {
        passwordCalls++;
        return _json({'status': 'mfa_required', 'challenge': _challenge});
      }
      if (request.url.path.endsWith('/recover/mfa/')) {
        mfaCalls++;
        // The backend MAY have issued a session. A transport exception
        // must not assume it has not; never repeat this one-time request.
        throw TimeoutException('synthetic response lost after MFA issue');
      }
      fail('No other recovery endpoint may be contacted');
    });
    final rig = _Rig(store, client);
    expect(await rig.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await rig.entry.verifyPassword(
          username: 'synthetic', password: 'synthetic-password'),
        NativePasswordDecision.mfaRequired);
    await expectLater(
        rig.entry.verifyTotp('123456'),
        throwsA(isA<NativeHttpAuthFailure>()));
    expect(passwordCalls, 1);
    expect(mfaCalls, 1);
    expect(rig.fence.ticket, isNull);
    expect(await rig.entry.accessToken(), isNull);
    expect(await rig.vault.read(), _old);
    await _checkColdStart(store);
    client.close();
    print('I8Q_AMBIGUOUS_MFA_NO_RETRY=PASS');
  });

  test('I8-Q post-MFA storage failure + failed remote revoke stays sealed',
      () async {
    final store = _FaultStore()..denyFreshWrite = true;
    var revokes = 0;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/recover/password/')) {
        return _json({'status': 'mfa_required', 'challenge': _challenge});
      }
      if (request.url.path.endsWith('/recover/mfa/')) {
        return _json({
          'status': 'authenticated', 'access': _access, 'refresh': _new,
        });
      }
      if (request.url.path == '/api/v1/mobile/token/revoke/') {
        revokes++;
        expect(jsonDecode(request.body), {'refresh': _new});
        throw TimeoutException('synthetic revoke acknowledgement lost');
      }
      fail('Unexpected native endpoint');
    });
    final rig = _Rig(store, client);
    expect(await rig.entry.inspect(),
        NativeStartupDisposition.fullReauthentication);
    expect(await rig.entry.verifyPassword(
          username: 'synthetic', password: 'synthetic-password'),
        NativePasswordDecision.mfaRequired);
    await expectLater(rig.entry.verifyTotp('123456'), throwsStateError);
    expect(revokes, 1);
    expect(rig.fence.ticket, isNull);
    expect(await rig.entry.accessToken(), isNull);
    expect(await rig.vault.read(), _old);
    await _checkColdStart(store);
    client.close();
    print('I8Q_STORAGE_AND_REVOKE_UNKNOWN_FENCED=PASS');
  });
}
