/// I8-F: native Flutter client against I8-E candidate over verified TLS.
///
/// Test-only executable: no production network, no platform secrets,
/// no main.dart wiring, and no certificate verification bypass.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_http_auth_port.dart';
import 'package:vencira/api/native_refresh_credential_vault.dart';
import 'package:vencira/api/native_session_coordinator.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/ui/native_login_screen.dart';

const _host = 'dev.vencira.es';
const _port = 8443;

void _check(bool value, String marker) {
  if (!value) throw StateError('I8F_$marker_FAILED');
  stdout.writeln('NATIVE_I8F_$marker=PASS');
}

InternetAddress _peer() {
  if (Platform.environment['VENCIRA_I8F_INTERNAL_ACK'] != '1') {
    throw StateError('I8F_ISOLATED_NETWORK_REQUIRED');
  }
  final peer = InternetAddress.tryParse(
    Platform.environment['VENCIRA_I8F_PEER_IPV4'] ?? '',
  );
  if (peer == null || peer.type != InternetAddressType.IPv4) {
    throw StateError('I8F_IPV4_REQUIRED');
  }
  final octets = peer.rawAddress;
  if (!(octets[0] == 10 ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168))) {
    throw StateError('I8F_PUBLIC_PEER_DENIED');
  }
  return peer;
}

HttpClient _client(SecurityContext trust) {
  final client = HttpClient(context: trust);
  client.findProxy = (_) => 'DIRECT';
  client.connectionTimeout = const Duration(seconds: 5);
  client.connectionFactory = (uri, proxyHost, proxyPort) {
    if (proxyHost != null || proxyPort != null ||
        uri.host != _host || uri.scheme != 'https' || uri.port != 443) {
      throw StateError('I8F_NON_LAB_ROUTE_DENIED');
    }
    return Socket.startConnect(_peer(), _port).then((task) {
      Socket? active;
      final verified = task.socket.then((raw) async {
        active = raw;
        try {
          final tls = await SecureSocket.secure(
            raw, host: uri.host, context: trust,
          );
          active = tls;
          return tls;
        } catch (_) {
          raw.destroy();
          rethrow;
        }
      });
      return ConnectionTask.fromSocket<Socket>(verified, () {
        task.cancel();
        active?.destroy();
      });
    });
  };
  return client;
}

class _EphemeralStore implements NativeSecretStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async { values[key] = value; }
  @override
  Future<void> delete(String key) async { values.remove(key); }
}

String _rfcSyntheticTotp() {
  // RFC 6238 public 20-byte ASCII test material. No user MFA secrets.
  final counter = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 30000;
  final message = ByteData(8)..setUint64(0, counter, Endian.big);
  final bytes = Hmac(sha1, utf8.encode('12345678901234567890'))
      .convert(message.buffer.asUint8List()).bytes;
  final offset = bytes.last & 15;
  final value = ((bytes[offset] & 0x7f) << 24) |
      ((bytes[offset + 1] & 0xff) << 16) |
      ((bytes[offset + 2] & 0xff) << 8) |
      (bytes[offset + 3] & 0xff);
  return (value % 1000000).toString().padLeft(6, '0');
}

Future<int> _meStatus(http.Client client, NativeApiEndpoint endpoint,
    String access) async {
  final request = http.Request('GET', endpoint.resolveApiPath('/api/v1/mobile/me/'))
    ..followRedirects = false
    ..headers['Authorization'] = 'Bearer $access';
  final reply = await client.send(request);
  await reply.stream.drain<void>();
  _check(!reply.headers.containsKey('set-cookie'), 'BEARER_COOKIELESS');
  return reply.statusCode;
}

Future<void> runI8f() async {
  final peer = _peer();
  final caFile = Platform.environment['VENCIRA_I8F_CA_FILE'];
  if (caFile == null || !caFile.startsWith('/tmp/') ||
      !File(caFile).existsSync()) {
    throw StateError('I8F_TEMPORARY_CA_REQUIRED');
  }
  final trust = SecurityContext(withTrustedRoots: false);
  trust.setTrustedCertificatesBytes(File(caFile).readAsBytesSync());
  final endpoint = NativeApiEndpoint.parse('https://dev.vencira.es');
  final socket = await Socket.connect(peer, _port);
  final tls = await SecureSocket.secure(socket, host: _host, context: trust);
  tls.destroy();
  _check(true, 'TLS_VERIFIED_HOSTNAME');

  final client = IOClient(_client(trust));
  try {
    final port = NativeHttpAuthPort(endpoint: endpoint, client: client);
    final store = _EphemeralStore();
    final fence = NativeSessionFence();
    final coordinator = NativeSessionCoordinator(
      port: port,
      vault: NativeRefreshCredentialVault(endpoint: endpoint, store: store),
      fence: fence,
    );
    final decision = await coordinator.verifyPassword(
      username: 'i8e-synthetic-logout',
      password: 'synthetic-i8e-password',
    );
    _check(decision == NativePasswordDecision.mfaRequired &&
        await coordinator.accessToken() == null &&
        store.values.isEmpty && fence.ticket == null,
        'PASSWORD_MFA_NO_ISSUANCE');
    await coordinator.verifyTotp(_rfcSyntheticTotp());
    final access = await coordinator.accessToken();
    _check(access != null && access.startsWith('v1.a.') &&
        store.values.length == 1 && fence.ticket != null,
        'TOTP_ISSUANCE_VAULT_CONFIRMED');
    _check(await _meStatus(client, endpoint, access!) == 200,
        'BEARER_VERIFIED_ME');

    // The fence must close synchronously before HTTP server acknowledgement.
    final logout = coordinator.logout();
    _check(fence.ticket == null && await coordinator.accessToken() == null,
        'LOGOUT_LOCAL_FENCE_CLOSED');
    await logout;
    _check(store.values.isEmpty && fence.ticket == null &&
        await _meStatus(client, endpoint, access) == 401,
        'LOGOUT_REMOTE_REVOKE_CONFIRMED');
    stdout.writeln('NATIVE_I8F_FLUTTER_HTTPS_GATE=PASS');
  } finally {
    client.close();
  }
}
