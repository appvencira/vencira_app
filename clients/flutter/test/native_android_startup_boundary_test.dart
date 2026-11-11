import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/native_mobile_startup_gate.dart';
import 'package:vencira/ui/native_android_startup_boundary.dart';

void main() {
  testWidgets('clean device preserves browser handoff without native login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeAndroidStartupBoundary(
        inspect: () async => NativeStartupDisposition.cleanLogin,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Acceso seguro a VENCIRA'), findsOneWidget);
    expect(find.text('Abrir VENCIRA en el navegador'), findsOneWidget);
    expect(find.byKey(const Key('native-login-submit')), findsNothing);
    expect(find.byKey(const Key('native-startup-status')), findsNothing);
  });

  testWidgets('orphan refresh requires recovery and never exposes login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeAndroidStartupBoundary(
        inspect: () async => NativeStartupDisposition.fullReauthentication,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('No se reutilizarán sus credenciales'),
        findsOneWidget);
    expect(find.byKey(const Key('native-login-submit')), findsNothing);
    expect(find.text('Abrir VENCIRA en el navegador'), findsOneWidget);
  });

  testWidgets('protected store failure fails closed without native login',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: NativeAndroidStartupBoundary(
        inspect: () async => throw StateError('unavailable'),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('no se ha podido verificar'), findsOneWidget);
    expect(find.byKey(const Key('native-login-submit')), findsNothing);
  });

  testWidgets('recovery warning scrolls on a compact Android viewport',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: NativeAndroidStartupBoundary(
        inspect: () async => NativeStartupDisposition.fullReauthentication,
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.byKey(const Key('native-login-submit')), findsNothing);
    await tester.ensureVisible(
        find.text('Abrir VENCIRA en el navegador'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('startup waits for inspection before displaying the browser',
      (tester) async {
    final pending = Completer<NativeStartupDisposition>();
    await tester.pumpWidget(MaterialApp(
      home: NativeAndroidStartupBoundary(inspect: () => pending.future),
    ));
    expect(find.byKey(const Key('native-startup-checking')), findsOneWidget);
    expect(find.text('Abrir VENCIRA en el navegador'), findsNothing);
    pending.complete(NativeStartupDisposition.cleanLogin);
    await tester.pump();
    expect(find.text('Abrir VENCIRA en el navegador'), findsOneWidget);
  });
}
