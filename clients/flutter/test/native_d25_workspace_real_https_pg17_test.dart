// D25 real TLS workspace read against synthetic PG17 and internal HTTPS Django.
// No operational Android API, no external hostname resolution.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:vencira/api/native_api_endpoint.dart';
import 'package:vencira/api/native_api_transport.dart';
import 'package:vencira/api/native_session_fence.dart';
import 'package:vencira/api/native_workspace_read_port.dart';

const _host = 'dev.vencira.es';

class _LiveNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

SecurityContext _context() {
  const file = '/tmp/d25-public-ca.pem';
  if (Platform.environment['VENCIRA_D25_PUBLIC_CA_FILE'] != file ||
      !File(file).existsSync()) {
    throw StateError('D25 isolated public CA required');
  }
  return SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(File(file).readAsBytesSync());
}

void main() {
  if (Platform.environment['VENCIRA_D25_WORKSPACE_TLS_LAB'] != '1' ||
      Platform.environment['VENCIRA_ENV'] != 'test' ||
      Platform.environment['VENCIRA_I8M_FLUTTER_INTERNAL_ONLY'] != '1') {
    test('D25 disabled without disposable HTTPS+PG17 lab', () {},
        skip: 'No isolated D25 environment');
    return;
  }
  _LiveNetworkBinding();
  final workspace = Platform.environment['VENCIRA_D25_WORKSPACE_ID'] ?? '';
  final access = Platform.environment['VENCIRA_D25_ACCESS'] ?? '';
  if (workspace.isEmpty || access.isEmpty) {
    throw StateError('Missing synthetic workspace/issuer fixture');
  }

  test('D25 verified TLS, scoped pagination and no PII', () async {
    final trusted = _context();

    // The same self-signed service must NOT work with default platform roots.
    final untrusted = HttpClient()..findProxy = (_) => 'DIRECT';
    try {
      await expectLater(
        untrusted.getUrl(Uri.parse('https://$_host/api/v1/mobile/me/')),
        throwsA(isA<HandshakeException>()),
      );
    } finally {
      untrusted.close(force: true);
    }

    // A wrong certificate hostname must fail, even with lab CA installed.
    final socket = await Socket.connect(_host, 443);
    try {
      await expectLater(
        SecureSocket.secure(socket, host: 'wrong-d25.invalid', context: trusted),
        throwsA(isA<HandshakeException>()),
      );
    } finally {
      socket.destroy();
    }
    print('D25_TLS_UNTRUSTED_CA_AND_HOST_MISMATCH_DENIED=PASS');

    final raw = HttpClient(context: trusted)..findProxy = (_) => 'DIRECT';
    raw.connectionTimeout = const Duration(seconds: 8);
    final client = IOClient(raw);
    final fence = NativeSessionFence()..activate();
    final reader = NativeWorkspaceReadPort(NativeApiTransport(
      endpoint: NativeApiEndpoint.parse('https://$_host'),
      client: client, accessToken: () async => access, sessionFence: fence,
    ));
    try {
      final first = await reader.loadPage(workspace);
      expect(first.results, hasLength(50));
      expect(first.nextOffset, 50);
      final second = await reader.loadPage(workspace, offset: 50);
      expect(second.results, hasLength(25));
      expect(second.nextOffset, isNull);
      final ids = {
        ...first.results.map((r) => r.id),
        ...second.results.map((r) => r.id),
      };
      expect(ids, hasLength(75));
      expect(fence.ticket, isNotNull);
      print('D25_REAL_TLS_WORKSPACE_PAGINATION_75=PASS');

      // A wrong workspace cannot leak data. The server currently responds
      // 401 uniformly, which fences the caller's session.
      await expectLater(
        reader.loadPage('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
        throwsA(isA<NativeApiSessionUnavailable>()),
      );
      expect(fence.ticket, isNull);
      print('D25_REAL_TLS_CROSS_WORKSPACE_DENIED=PASS');
    } finally {
      client.close();
    }
  });
}
