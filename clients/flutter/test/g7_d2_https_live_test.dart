import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/g7_d2_https_probe.dart' as live_probe;

/// The standard widget-test binding replaces HttpClient with HTTP 400.
/// This binding is only instantiated in this explicitly isolated, single-file
/// network integration suite; none of the G7-A/B unit tests use it.
class _G7D2NetworkTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _G7D2NetworkTestBinding();

  test('G7-D2 real Dart HTTPS -> disposable Django issuer', () async {
    // The probe checks G7_D2_ISOLATED_NETWORK_ACK and the temporary CA file.
    // Running on a normal machine must fail closed before any TCP connection.
    await live_probe.main();
  }, skip: Platform.environment['G7_D2_ISOLATED_NETWORK_ACK'] != '1');
}
