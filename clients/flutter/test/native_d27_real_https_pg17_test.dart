// D27 live IOClient TLS lab, internal disposable Django/PG17 only.
// Never wired to application main.dart or operational routes.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _host = 'dev.vencira.es';
const _secret = '12345678901234567890';
const _username = 'd27-tls';
const _password = 'synthetic-d27-tls-password';

class _MemoryStore implements NativeSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
}

String _totpAt(int seconds) {
  final counter = seconds ~/ 30;
  final bytes = ByteData(8)..setUint64(0, counter, Endian.big);
  final hashed = Hmac(sha1, utf8.encode(_secret))
      .convert(bytes.buffer.asUint8List()).bytes;
  final offset = hashed.last & 0x0f;
  final number = ((hashed[offset] & 0x7f) << 24) |
      (hashed[offset + 1] << 16) |
      (hashed[offset + 2] << 8) |
      hashed[offset + 3];
  return (number % 1000000).toString().padLeft(6, '0');
}

SecurityContext _trustedLabContext() {
  final ca = Platform.environment['VENCIRA_D27_PUBLIC_CA_FILE'];
  if (ca != '/tmp/d27-lab-ca.pem' || !File(ca!).existsSync()) {
    throw StateError('D27 lab CA not mounted');
  }
  return SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(File(ca).readAsBytesSync());
}

Future<int> _me(HttpClient client, String token) async {
  final request = await client.getUrl(
      Uri.parse('https://$_host/api/v1/mobile/me/'));
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
  final response = await request.close();
  final status = response.statusCode;
  expect(response.headers.value('set-cookie'), isNull);
  await response.drain<void>();
  return status;
}

// Only this explicitly gated file may open real sockets in widget tests.
class _AllowLabSockets extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  final lab = Platform.environment['VENCIRA_D27_REAL_TLS_LAB'] == '1' &&
      Platform.environment['VENCIRA_ENV'] == 'test' &&
      Platform.environment['POSTGRES_DB'] == 'i8klab';
  if (!lab) {
    test('D27 real TLS integration disabled outside isolated lab', () {},
        skip: 'Requires disposable D27 PG17 HTTPS lab');
    return;
  }
  _AllowLabSockets();
  test('D27 real TLS first issuance and account-wide recovery through Flutter',
      () async {
    final trusted = _trustedLabContext();
    final untrusted = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      await expectLater(
          untrusted.getUrl(Uri.parse('https://$_host/api/v1/mobile/me/')),
          throwsA(isA<HandshakeException>()));
    } finally {
      untrusted.close(force: true);
    }
    final badSocket = await Socket.connect(_host, 443);
    try {
      await expectLater(
        SecureSocket.secure(badSocket, host: 'invalid-d27-host.example',
            context: trusted),
        throwsA(isA<HandshakeException>()),
      );
    } finally {
      badSocket.destroy();
    }
    print('D27_REAL_TLS_CA_AND_HOSTNAME=PASS');

    final raw = HttpClient(context: trusted)..findProxy = (_) => 'DIRECT';
    raw.connectionTimeout = const Duration(seconds: 8);
    final client = IOClient(raw);
    try {
      final endpoint = NativeApiEndpoint.parse('https://$_host');
      final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
      final decision = await port.password(
          username: _username, password: _password);
      expect(decision, isA<NativePasswordMfaRequired>());
      final challenge = (decision as NativePasswordMfaRequired).challenge;
      expect(challenge, startsWith('oc1.'));
      final issued = await port.mfa(
          challenge: challenge,
          code: _totpAt(DateTime.now().millisecondsSinceEpoch ~/ 1000 - 30));
      expect(await _me(raw, issued.access), 200);
      print('D27_FLUTTER_REAL_TLS_FIRST_ISSUANCE=PASS');

      // Account recovery reuses the candidate gateway, durable storage and
      // journal, not an invented second transport or ordinary refresh.
      final store = _MemoryStore();
      final fence = NativeSessionFence();
      final vault = NativeRefreshCredentialVault(
          endpoint: endpoint, store: store);
      final journal = NativeRefreshRecoveryJournal(
          endpoint: endpoint, store: store, fence: fence);
      await vault.replace(issued.refresh);
      final startup = NativeMobileStartupGate(
          fence: fence, vault: vault, journal: journal);
      expect(await startup.inspect(),
          NativeStartupDisposition.fullReauthentication);
      final gateway = NativeRecoveryLoginGateway(
          port: port, journal: journal, vault: vault, fence: fence);
      expect(await gateway.requiresRecovery(), isTrue);
      expect(await gateway.verifyPassword(
          username: _username, password: _password),
          NativePasswordDecision.mfaRequired);
      expect(fence.ticket, isNull);
      await gateway.verifyTotp(
          _totpAt(DateTime.now().millisecondsSinceEpoch ~/ 1000));
      final fresh = await gateway.accessToken();
      final confirmedAccess = fresh ?? (throw StateError('Missing recovered access'));
      expect(await _me(raw, issued.access), 401);
      expect(await _me(raw, confirmedAccess), 200);
      expect(await journal.requiresReauthentication(), isFalse);
      expect(await vault.read(), isNot(issued.refresh));
      print('D27_FLUTTER_REAL_TLS_RECOVERY_AND_REVOKE=PASS');

      await port.revoke(refresh: (await vault.read())!);
      expect(await _me(raw, confirmedAccess), 401);
      print('D27_FLUTTER_REAL_TLS_DEVICE_REVOKE=PASS');
    } finally {
      client.close();
    }
  });
}
