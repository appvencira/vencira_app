// G11 independent HTTPS scenarios, invoked ONLY by the G7 disposable TLS lab.
// No production URL, key, user credentials or Android storage is used.
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_first_issuance_entry.dart';
import 'package:vencira/api/native_mobile_recovery_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _marker = 'vencira.mobile.dev.uncertain.v1';
const _pending = 'full-reauth-required-v1';
const _username = 'g7-d2-synthetic';
const _password = 'G7-D2-Only-Synthetic-Password-2026!';

void _check(bool result, String label) {
  if (!result) throw StateError('G11_' + label + '_FAILED');
  stdout.writeln('G11_' + label + '=OK');
}

class _Store implements NativeSecretStore {
  final values = <String, String>{};
  bool ignoreMarkerWrite = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (ignoreMarkerWrite && key == _marker) return;
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

// This instrumentation cannot see secrets: only a trusted in-memory marker
// value and the URL path. The real HTTP parser/issuer remain unchanged.
class _ObservedClient extends http.BaseClient {
  _ObservedClient(this.inner, this.store, this.fence);
  final http.Client inner;
  final _Store store;
  final NativeSessionFence fence;
  int passwordCalls = 0;
  int mfaCalls = 0;
  int revokeCalls = 0;
  int recoveryCalls = 0;
  bool loseNextPasswordResponse = false;
  bool refuseNextRevoke = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (request.method == 'POST' &&
        (path == '/api/v1/mobile/auth/password/' ||
         path == '/api/v1/mobile/auth/mfa/' ||
         path == '/api/v1/mobile/token/revoke/' ||
         path == '/api/v1/mobile/auth/recover/password/' ||
         path == '/api/v1/mobile/auth/recover/mfa/')) {
      if (fence.ticket != null || store.values[_marker] != _pending) {
        throw StateError('G11_DURABLE_MARKER_REQUIRED_BEFORE_HTTP');
      }
      if (path == '/api/v1/mobile/auth/password/') passwordCalls++;
      if (path == '/api/v1/mobile/auth/mfa/') mfaCalls++;
      if (path == '/api/v1/mobile/token/revoke/') {
        revokeCalls++;
        if (refuseNextRevoke) {
          refuseNextRevoke = false;
          throw const SocketException('G11_SYNTHETIC_REVOKE_NETWORK_FAILURE');
        }
      }
      if (path.startsWith('/api/v1/mobile/auth/recover/')) recoveryCalls++;
    }
    final response = await inner.send(request);
    if (path == '/api/v1/mobile/auth/password/' &&
        loseNextPasswordResponse) {
      loseNextPasswordResponse = false;
      // Django completed issuance, but the client is denied the response.
      await response.stream.drain<void>();
      throw const SocketException('G11_SYNTHETIC_RESPONSE_LOST');
    }
    return response;
  }

  @override
  void close() {} // Shared TLS client is closed by the parent lab.
}

class _Case {
  _Case(this.endpoint, http.Client shared)
      : store = _Store(),
        fence = NativeSessionFence() {
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    observed = _ObservedClient(shared, store, fence);
    port = NativeHttpAuthPort(endpoint: endpoint, client: observed);
    coordinator = NativeSessionCoordinator(
      port: port, vault: vault, fence: fence,
      firstIssuanceJournal: journal,
    );
    entry = NativeFirstIssuanceEntry(
      startup: NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal,
      ),
      coordinator: coordinator, journal: journal,
    );
  }

  final NativeApiEndpoint endpoint;
  final _Store store;
  final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final _ObservedClient observed;
  late final NativeHttpAuthPort port;
  late final NativeSessionCoordinator coordinator;
  late final NativeFirstIssuanceEntry entry;
}

Future<void> _expectHttpFailure(Future<Object?> Function() action) async {
  var failed = false;
  try {
    await action();
  } on NativeHttpAuthFailure {
    failed = true;
  }
  _check(failed, 'INTENTIONAL_HTTP_FAILURE_DENIED');
}

/// Real TLS, Django's disposable native issuer and synthetic test identities.
/// The caller MUST validate temporary CA, private TCP, SNI and Docker isolation.
Future<void> verifyG11Https(
  NativeApiEndpoint endpoint,
  http.Client trustedIsolatedClient, {
  required Future<int> Function(String access) bearerStatus,
  required String Function() syntheticTotp,
}) async {
  final normal = _Case(endpoint, trustedIsolatedClient);
  _check(await normal.entry.inspect() == NativeStartupDisposition.cleanLogin &&
      normal.fence.ticket == null, 'INITIAL_FENCE');
  final first = await normal.entry.verifyPassword(
    username: _username, password: _password,
  );
  final firstAccess = await normal.entry.accessToken();
  _check(first == NativePasswordDecision.authenticated &&
      normal.observed.passwordCalls == 1 &&
      normal.fence.ticket != null &&
      firstAccess != null &&
      await normal.vault.read() != null &&
      !await normal.journal.requiresReauthentication(),
      'FIRST_ISSUANCE_HTTPS_COMMITTED');
  _check(await bearerStatus(firstAccess!) == 200,
      'ISSUED_BEARER_ACCEPTED_BY_DJANGO');

  final logout = normal.entry.logout();
  _check(normal.fence.ticket == null, 'LOGOUT_FENCE_IMMEDIATE');
  await logout;
  _check(normal.observed.revokeCalls == 1 &&
      normal.fence.ticket == null &&
      await normal.vault.read() == null &&
      !await normal.journal.requiresReauthentication() &&
      await bearerStatus(firstAccess) == 401,
      'REMOTE_REVOKE_AND_LOCAL_CLEANUP');

  final cannotWrite = _Case(endpoint, trustedIsolatedClient);
  cannotWrite.store.ignoreMarkerWrite = true;
  _check(await cannotWrite.entry.inspect() ==
      NativeStartupDisposition.cleanLogin, 'STORAGE_FAILURE_PREFLIGHT');
  var deniedBeforeHttp = false;
  try {
    await cannotWrite.entry.verifyPassword(
      username: _username, password: _password,
    );
  } on StateError {
    deniedBeforeHttp = true;
  }
  _check(deniedBeforeHttp && cannotWrite.observed.passwordCalls == 0 &&
      cannotWrite.fence.ticket == null,
      'STORAGE_FAILURE_NO_PASSWORD_HTTP');

  // A request is accepted by real Django; its response is dropped *after*
  // issuance. G10 must not replay the password or refresh on reconnect.
  final uncertain = _Case(endpoint, trustedIsolatedClient);
  _check(await uncertain.entry.inspect() ==
      NativeStartupDisposition.cleanLogin, 'LOST_RESPONSE_PREFLIGHT');
  uncertain.observed.loseNextPasswordResponse = true;
  await _expectHttpFailure(() => uncertain.entry.verifyPassword(
    username: _username, password: _password,
  ));
  _check(uncertain.observed.passwordCalls == 1 &&
      await uncertain.journal.requiresReauthentication() &&
      await uncertain.vault.read() == null &&
      uncertain.fence.ticket == null,
      'LOST_ISSUANCE_RESPONSE_FENCED');

  // Simulate a fresh process using the SAME disposable protected backing
  // store, but newly constructed fence/vault/journal and recovery gateway.
  final rebootFence = NativeSessionFence();
  final rebootVault = NativeRefreshCredentialVault(
    endpoint: endpoint, store: uncertain.store,
  );
  final rebootJournal = NativeRefreshRecoveryJournal(
    endpoint: endpoint, store: uncertain.store, fence: rebootFence,
  );
  final rebootClient = _ObservedClient(
    trustedIsolatedClient, uncertain.store, rebootFence,
  );
  final rebootPort = NativeHttpAuthPort(
    endpoint: endpoint, client: rebootClient,
  );
  final recovery = NativeMobileRecoveryEntry(
    startup: NativeMobileStartupGate(
      fence: rebootFence, vault: rebootVault, journal: rebootJournal,
    ),
    recovery: NativeRecoveryLoginGateway(
      port: rebootPort, journal: rebootJournal,
      vault: rebootVault, fence: rebootFence,
    ),
  );
  _check(await recovery.inspect() ==
      NativeStartupDisposition.fullReauthentication,
      'AMBIGUOUS_ISSUANCE_REQUIRES_ACCOUNT_RECOVERY');
  final recovered = await recovery.verifyPassword(
    username: _username, password: _password,
  );
  _check(recovered == NativePasswordDecision.authenticated &&
      rebootClient.recoveryCalls == 1 &&
      await rebootVault.read() != null &&
      !await rebootJournal.requiresReauthentication() &&
      rebootFence.ticket != null,
      'FULL_RECOVERY_VERIFIED_HTTPS');
  // Test fixture does not survive teardown. Revoke the new synthetic session.
  await rebootJournal.arm();
  await rebootPort.revoke(refresh: (await rebootVault.read())!);
  await rebootVault.clear();
  await rebootJournal.confirmLogoutCompleted(vault: rebootVault);

  // Pre-revocation network failure: no local success, no credential erasure.
  final brokenLogout = _Case(endpoint, trustedIsolatedClient);
  _check(await brokenLogout.entry.inspect() ==
      NativeStartupDisposition.cleanLogin, 'REVOKE_FAULT_PREFLIGHT');
  await brokenLogout.entry.verifyPassword(
    username: _username, password: _password,
  );
  final pendingAccess = await brokenLogout.entry.accessToken();
  brokenLogout.observed.refuseNextRevoke = true;
  final failingLogout = brokenLogout.entry.logout();
  _check(brokenLogout.fence.ticket == null, 'REVOKE_FAULT_FENCE_CLOSED');
  await _expectHttpFailure(() => failingLogout);
  _check(await brokenLogout.journal.requiresReauthentication() &&
      await brokenLogout.vault.read() != null &&
      await brokenLogout.entry.accessToken() == null,
      'REMOTE_REVOKE_FAILURE_DURABLE');
  await brokenLogout.entry.logout();
  _check(brokenLogout.observed.revokeCalls == 2 &&
      await brokenLogout.vault.read() == null &&
      !await brokenLogout.journal.requiresReauthentication() &&
      await bearerStatus(pendingAccess!) == 401,
      'REVOKE_RETRY_SERVER_DENIES_OLD_ACCESS');

  // Real MFA completes only with the pre-issued durable checkpoint present.
  final mfa = _Case(endpoint, trustedIsolatedClient);
  _check(await mfa.entry.inspect() ==
      NativeStartupDisposition.cleanLogin, 'MFA_PREFLIGHT');
  final challenge = await mfa.entry.verifyPassword(
    username: 'g7-e-mfa-synthetic',
    password: 'G7-E-Only-Synthetic-Mfa-Password-2026!',
  );
  _check(challenge == NativePasswordDecision.mfaRequired &&
      mfa.observed.passwordCalls == 1 &&
      await mfa.journal.requiresReauthentication() &&
      mfa.fence.ticket == null, 'MFA_PASSWORD_MARKER');
  await mfa.entry.verifyTotp(syntheticTotp());
  final mfaAccess = await mfa.entry.accessToken();
  _check(mfa.observed.mfaCalls == 1 &&
      mfaAccess != null &&
      mfa.fence.ticket != null &&
      !await mfa.journal.requiresReauthentication() &&
      await bearerStatus(mfaAccess!) == 200,
      'MFA_REAL_HTTPS_COMMIT');
  await mfa.entry.logout();
  _check(await mfa.vault.read() == null &&
      !await mfa.journal.requiresReauthentication() &&
      await bearerStatus(mfaAccess) == 401,
      'MFA_SERVER_REVOKED_AFTER_LOGOUT');

  stdout.writeln('G11_HTTPS_FIRST_ISSUANCE_LOGOUT_RESULT=0');
}
