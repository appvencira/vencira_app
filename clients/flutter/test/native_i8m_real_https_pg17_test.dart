// I8-M: actual Dart IOClient over TLS, against an INTERNAL Docker-only
// Django/PostgreSQL lab. Never included in main.dart or mobile release.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_mobile_recovery_entry.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/api/native_recovery_login_gateway.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_refresh_recovery_journal.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _labHost = 'dev.vencira.es';
const _labRefresh = 'v1.r.0123456789abcdef0123456789abcdef.'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
const _rfc6238Secret = '12345678901234567890';

class _Store implements NativeSecretStore {
  final values = <String, String>{
    'vencira.mobile.dev.refresh.v1': _labRefresh,
  };
  bool rejectRefreshWrites = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (rejectRefreshWrites && key.endsWith('.refresh.v1')) {
      throw StateError('Synthetic secure-store write rejected');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

String _totp() {
  final counter = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
  final bytes = ByteData(8)..setUint64(0, counter, Endian.big);
  final hmac = Hmac(sha1, utf8.encode(_rfc6238Secret))
      .convert(bytes.buffer.asUint8List()).bytes;
  final offset = hmac.last & 0x0f;
  final value = ((hmac[offset] & 0x7f) << 24) |
      (hmac[offset + 1] << 16) |
      (hmac[offset + 2] << 8) |
      hmac[offset + 3];
  return (value % 1000000).toString().padLeft(6, '0');
}

class _Session {
  _Session(IOClient client, this.store) {
    fence = NativeSessionFence();
    vault = NativeRefreshCredentialVault(endpoint: endpoint, store: store);
    journal = NativeRefreshRecoveryJournal(
      endpoint: endpoint, store: store, fence: fence,
    );
    gateway = NativeRecoveryLoginGateway(
      port: NativeHttpAuthPort(endpoint: endpoint, client: client),
      journal: journal, vault: vault, fence: fence,
    );
    entry = NativeMobileRecoveryEntry(
      startup: NativeMobileStartupGate(
        fence: fence, vault: vault, journal: journal,
      ),
      recovery: gateway,
    );
  }

  static final endpoint = NativeApiEndpoint.parse('https://$_labHost');
  final _Store store;
  late final NativeSessionFence fence;
  late final NativeRefreshCredentialVault vault;
  late final NativeRefreshRecoveryJournal journal;
  late final NativeRecoveryLoginGateway gateway;
  late final NativeMobileRecoveryEntry entry;
}

SecurityContext _trustContext() {
  final ca = Platform.environment['VENCIRA_I8M_PUBLIC_CA_FILE'];
  if (ca != '/tmp/i8m-lab-ca.pem' || !File(ca!).existsSync()) {
    throw StateError('Internal TLS fixture CA required');
  }
  final context = SecurityContext(withTrustedRoots: false);
  context.setTrustedCertificatesBytes(File(ca).readAsBytesSync());
  return context;
}

Future<void> _negativeTlsChecks(SecurityContext trusted) async {
  final defaultClient = HttpClient()..findProxy = (_) => 'DIRECT';
  try {
    await expectLater(
      defaultClient.getUrl(Uri.parse('https://$_labHost/api/v1/mobile/me/')),
      throwsA(isA<HandshakeException>()),
    );
  } finally {
    defaultClient.close(force: true);
  }
  // Connect to the correct Docker-local IP, then present an INCORRECT SNI
  // hostname. Certificate verification must fail before HTTP.
  final socket = await Socket.connect(_labHost, 443);
  try {
    await expectLater(
      SecureSocket.secure(socket, host: 'wrong-i8m.invalid', context: trusted),
      throwsA(isA<HandshakeException>()),
    );
  } finally {
    socket.destroy();
  }
  // A verified handshake with the correct host is required independently
  // of any HTTP adapter or mocked client.
  final good = await SecureSocket.connect(_labHost, 443, context: trusted);
  good.destroy();
  print('MAIN_I8M_FLUTTER_TLS_CA_AND_HOSTNAME=PASS');
}

// Real sockets are allowed only in this gated integration test. Other
// Flutter tests retain the default no-network HttpClient override.
class _I8MNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  final isolated = Platform.environment['VENCIRA_I8M_FLUTTER_INTERNAL_ONLY'] == '1' &&
      Platform.environment['VENCIRA_ENV'] == 'test' &&
      Platform.environment['POSTGRES_DB'] == 'i8klab';
  if (!isolated) {
    test('I8-M real HTTPS requires isolated Docker lab', () {},
        skip: 'No lab-only network or disposable PG17 context');
    return;
  }
  _I8MNetworkBinding();

  test('I8-M verified IOClient TLS and recovery MFA committed', () async {
    final trusted = _trustContext();
    await _negativeTlsChecks(trusted);
    final raw = HttpClient(context: trusted)..findProxy = (_) => 'DIRECT';
    raw.connectionTimeout = const Duration(seconds: 8);
    final client = IOClient(raw);
    try {
      final session = _Session(client, _Store());
      expect(await session.entry.inspect(),
          NativeStartupDisposition.fullReauthentication);
      expect(session.fence.ticket, isNull);
      final password = await session.entry.verifyPassword(
        username: 'i8m-recovery', password: 'synthetic-i8m-password',
      );
      expect(password, NativePasswordDecision.mfaRequired);
      expect(await session.entry.accessToken(), isNull);
      await session.entry.verifyTotp(_totp());
      final access = await session.entry.accessToken();
      expect(access, isNotNull);
      expect(session.fence.ticket, isNotNull);
      expect(await session.vault.read(), isNot(_labRefresh));
      expect(await session.journal.requiresReauthentication(), isFalse);
      // The returned access credential must work over the same verified TLS.
      final request = await raw.getUrl(
          Uri.parse('https://$_labHost/api/v1/mobile/me/'));
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $access');
      final response = await request.close();
      expect(response.statusCode, 200);
      expect(response.headers.value('set-cookie'), isNull);
      await response.drain<void>();
      print('MAIN_I8M_FLUTTER_RECOVERY_MFA_TLS=PASS');
    } finally {
      client.close();
    }
  });

  test('I8-M failed storage write triggers remote revoke over real TLS',
      () async {
    final raw = HttpClient(context: _trustContext())
      ..findProxy = (_) => 'DIRECT';
    raw.connectionTimeout = const Duration(seconds: 8);
    final client = IOClient(raw);
    try {
      final store = _Store()..rejectRefreshWrites = true;
      final session = _Session(client, store);
      expect(await session.entry.inspect(),
          NativeStartupDisposition.fullReauthentication);
      expect(await session.entry.verifyPassword(
        username: 'i8m-failedstore', password: 'synthetic-i8m-password',
      ), NativePasswordDecision.mfaRequired);
      await expectLater(session.entry.verifyTotp(_totp()), throwsStateError);
      expect(session.fence.ticket, isNull);
      expect(await session.entry.accessToken(), isNull);
      expect(await session.vault.read(), _labRefresh);
      expect(await session.journal.requiresReauthentication(), isTrue);
      // Verify exact backend revocation in PG17 after this test in runner.
      print('MAIN_I8M_FLUTTER_FAILURE_LOCAL_FENCE=PASS');
    } finally {
      client.close();
    }
  });
}
