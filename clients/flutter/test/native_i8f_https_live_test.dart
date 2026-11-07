import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../tool/native_i8f_https_probe.dart' as probe;

/// Only the explicit Docker-internal network integration suite enables
/// real Dart HttpClient; other Flutter tests retain safe HTTP overrides.
class _I8FNetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _I8FNetworkBinding();
  test('I8-F native Flutter TLS against isolated I8-E PostgreSQL17',
      () async {
    await probe.runI8f();
  }, skip: Platform.environment['VENCIRA_I8F_INTERNAL_ACK'] != '1');
}
