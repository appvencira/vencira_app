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

  testWidgets('Changing security callback invalidates stale success',
      (tester) async {
    final previous = Completer<void>();
    final next = Completer<void>();
    Future<void> oldCleanup() => previous.future;
    Future<void> newCleanup() => next.future;
    await tester.pumpWidget(app(oldCleanup));
    await tester.pump();
    expect(find.text('Authorized customer dashboard'), findsNothing);

    await tester.pumpWidget(app(newCleanup));
    await tester.pump();
    previous.complete();
    await tester.pump();
    expect(find.text('Authorized customer dashboard'), findsNothing);

    next.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
  });

  testWidgets('Enabling security after an exempt session blocks dashboard',
      (tester) async {
    final cleanup = Completer<void>();
    Future<void> revoke() => cleanup.future;
    await tester.pumpWidget(app(revoke, enabled: false));
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
    await tester.pumpWidget(app(revoke));
    await tester.pump();
    expect(find.text('Authorized customer dashboard'), findsNothing);
    cleanup.complete();
    await tester.pumpAndSettle();
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
  testWidgets('Late failure from replaced cleanup cannot relock a successful gate',
      (tester) async {
    final oldWork = Completer<void>();
    Future<void> oldCleanup() => oldWork.future;
    var replacementCalls = 0;
    Future<void> newCleanup() async { replacementCalls++; }

    await tester.pumpWidget(app(oldCleanup));
    await tester.pump();
    await tester.pumpWidget(app(newCleanup));
    await tester.pumpAndSettle();
    expect(replacementCalls, 1);
    expect(find.text('Authorized customer dashboard'), findsOneWidget);

    oldWork.completeError(StateError('Old account cleanup failed'));
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-native-alarm-recovery')),
        findsNothing);
  });

  testWidgets('Late success from replaced cleanup cannot bypass new failure',
      (tester) async {
    final oldWork = Completer<void>();
    Future<void> oldCleanup() => oldWork.future;
    Future<void> newCleanup() async {
      throw StateError('New account protected storage unavailable');
    }

    await tester.pumpWidget(app(oldCleanup));
    await tester.pump();
    await tester.pumpWidget(app(newCleanup));
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byKey(const ValueKey('retry-native-alarm-recovery')),
        findsOneWidget);

    oldWork.complete();
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byKey(const ValueKey('retry-native-alarm-recovery')),
        findsOneWidget);
  });

  testWidgets('Repeated recovery taps never start overlapping cleanups',
      (tester) async {
    final retryWork = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(app(() async {
      attempts++;
      if (attempts == 1) throw StateError('Initial protected read failed');
      await retryWork.future;
    }));
    await tester.pumpAndSettle();
    expect(attempts, 1);

    final retry = find.byKey(const ValueKey('retry-native-alarm-recovery'));
    await tester.tap(retry);
    await tester.pump();
    expect(attempts, 2);
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(retry, findsNothing);

    retryWork.complete();
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
  });

  testWidgets('Disabled-to-enabled transition requires new cleanup even after failure',
      (tester) async {
    var attempts = 0;
    Future<void> cleanup() async {
      attempts++;
      if (attempts == 1) throw StateError('Unverified alarm ledger');
    }

    await tester.pumpWidget(app(cleanup));
    await tester.pumpAndSettle();
    expect(find.text('Authorized customer dashboard'), findsNothing);
    expect(find.byKey(const ValueKey('retry-native-alarm-recovery')),
        findsOneWidget);

    await tester.pumpWidget(app(cleanup, enabled: false));
    await tester.pump();
    expect(find.text('Authorized customer dashboard'), findsOneWidget);

    await tester.pumpWidget(app(cleanup));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Authorized customer dashboard'), findsOneWidget);
  });

}
