import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/notifications/device_notice_startup_gate.dart';

Widget app(Future<void> Function() cleanup, {bool enabled = true,
    Locale locale = const Locale('es')}) => MaterialApp(
  locale: locale,
  home: DeviceNoticeStartupGate(
    enabled: enabled,
    cancelPreviousAlarms: cleanup,
    child: const Scaffold(body: Text('Authorized customer dashboard')),
  ),
);

void main() {
  testWidgets('Android dashboard is not mounted until previous alarms revoked',
      (tester) async {
    final gate = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(app(() async {
      calls++;
      await gate.future;
    }));
    await tester.pump();
    expect(calls, 1);
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Failed cleanup cannot be skipped; retry executes again',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(app(() async {
      attempts++;
      if (attempts == 1) throw StateError('Keystore unavailable');
    }, locale: const Locale('ca')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byKey(const ValueKey('retry-native-alarm-recovery')),
        findsOneWidget);
    await tester.tap(find.byKey(
        const ValueKey('retry-native-alarm-recovery')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
  });

  testWidgets('Injected test client skips native Android operations',
      (tester) async {
    var called = false;
    await tester.pumpWidget(app(() async { called = true; },
        enabled: false));
    await tester.pumpAndSettle();
    expect(called, isFalse);
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
  });

  testWidgets('Restarted gate repeats recovery rather than trusting UI state',
      (tester) async {
    var attempts = 0;
    Widget keyed(Key key) => MaterialApp(
      home: DeviceNoticeStartupGate(
        key: key, cancelPreviousAlarms: () async { attempts++; },
        child: const Scaffold(body: Text('Authorized customer dashboard')),
      ),
    );
    await tester.pumpWidget(keyed(const ValueKey('first-app')));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    await tester.pumpWidget(keyed(const ValueKey('new-app-process')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
