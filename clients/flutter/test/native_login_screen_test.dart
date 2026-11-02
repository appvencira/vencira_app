import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/ui/native_login_screen.dart';

class FakeNativeLoginGateway implements NativeLoginGateway {
  NativePasswordDecision decision = NativePasswordDecision.mfaRequired;
  Completer<NativePasswordDecision>? blockedPassword;
  Completer<void>? blockedTotp;
  bool failPassword = false;
  bool failTotp = false;
  String? receivedUsername;
  String? receivedPassword;
  String? receivedTotp;
  int cancellations = 0;

  @override
  Future<NativePasswordDecision> verifyPassword({
    required String username,
    required String password,
  }) async {
    receivedUsername = username;
    receivedPassword = password;
    if (blockedPassword != null) return blockedPassword!.future;
    if (failPassword) throw StateError('internal synthetic error');
    return decision;
  }

  @override
  Future<void> verifyTotp(String code) async {
    receivedTotp = code;
    if (blockedTotp != null) await blockedTotp!.future;
    if (failTotp) throw StateError('synthetic MFA failure');
  }

  @override
  Future<void> abandonChallenge() async {
    cancellations++;
  }
}

void main() {
  Future<void> enterPassword(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const Key('native-login-username')), '  agent1  ');
    await tester.enterText(
      find.byKey(const Key('native-login-password')),
      'test-only-not-a-real-secret',
    );
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pumpAndSettle();
  }

  testWidgets('password login uses native fields without browser',
      (tester) async {
    final gateway = FakeNativeLoginGateway()
      ..decision = NativePasswordDecision.authenticated;
    var authenticated = 0;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => authenticated++,
    )));
    expect(find.text('Acceso seguro'), findsOneWidget);
    await enterPassword(tester);
    expect(gateway.receivedUsername, 'agent1');
    expect(gateway.receivedPassword, 'test-only-not-a-real-secret');
    expect(authenticated, 1);
    expect(find.text('Verificación en dos pasos'), findsNothing);
    expect(find.text('test-only-not-a-real-secret'), findsNothing);
  });

  testWidgets('MFA requires six digits before authenticated callback',
      (tester) async {
    final gateway = FakeNativeLoginGateway();
    var authenticated = 0;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => authenticated++,
    )));
    await enterPassword(tester);
    expect(authenticated, 0);
    expect(find.text('Verificación en dos pasos'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('native-login-totp')), '123');
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Introduce los seis dígitos.'), findsOneWidget);
    expect(gateway.receivedTotp, isNull);
    await tester.enterText(find.byKey(const Key('native-login-totp')),
        '123456');
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pumpAndSettle();
    expect(gateway.receivedTotp, '123456');
    expect(authenticated, 1);
  });

  testWidgets('password rejection shows generic error, never credentials',
      (tester) async {
    final gateway = FakeNativeLoginGateway()..failPassword = true;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => fail('unexpected successful auth'),
    )));
    await enterPassword(tester);
    expect(find.text('No se ha podido verificar el acceso.'), findsOneWidget);
    expect(find.textContaining('internal synthetic error'), findsNothing);
    final passwordField = tester.widget<TextField>(
      find.byKey(const Key('native-login-password')),
    );
    expect(passwordField.controller!.text, isEmpty);
  });

  testWidgets('MFA failure can retry but never unlocks the app',
      (tester) async {
    final gateway = FakeNativeLoginGateway()..failTotp = true;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => fail('unexpected successful auth'),
    )));
    await enterPassword(tester);
    await tester.enterText(find.byKey(const Key('native-login-totp')),
        '123456');
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pumpAndSettle();
    expect(find.text('No se ha podido verificar el código.'), findsOneWidget);
    expect(tester.widget<TextField>(
        find.byKey(const Key('native-login-totp'))).controller!.text, isEmpty);
  });

  testWidgets('going back invalidates delayed MFA success',
      (tester) async {
    final gateway = FakeNativeLoginGateway()
      ..blockedTotp = Completer<void>();
    var authenticated = 0;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => authenticated++,
    )));
    await enterPassword(tester);
    await tester.enterText(find.byKey(const Key('native-login-totp')),
        '123456');
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byKey(const Key('native-login-back')));
    await tester.pumpAndSettle();
    expect(gateway.cancellations, 1);
    expect(find.text('Acceso seguro'), findsOneWidget);
    gateway.blockedTotp!.complete();
    await tester.pumpAndSettle();
    expect(authenticated, 0);
  });

  testWidgets('disposed login ignores delayed password verification',
      (tester) async {
    final gateway = FakeNativeLoginGateway()
      ..blockedPassword = Completer<NativePasswordDecision>();
    var authenticated = 0;
    await tester.pumpWidget(MaterialApp(home: NativeLoginScreen(
      gateway: gateway,
      onAuthenticated: () => authenticated++,
    )));
    await tester.enterText(
      find.byKey(const Key('native-login-username')), 'operator');
    await tester.enterText(
      find.byKey(const Key('native-login-password')), 'synthetic-password');
    await tester.tap(find.byKey(const Key('native-login-submit')));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    gateway.blockedPassword!.complete(NativePasswordDecision.authenticated);
    await tester.pump();
    expect(authenticated, 0);
  });
}
