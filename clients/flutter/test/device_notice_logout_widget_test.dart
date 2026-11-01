import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/dashboard_screen.dart';
import 'package:vencira/ui/vencira_preferences.dart';

const workspace = VenciraWorkspace(
  id: '11111111-1111-4111-8111-111111111111', name: 'Equipo de pruebas',
  role: 'owner',
);

class FakeApi implements VenciraApi {
  int logoutCalls = 0;
  bool unauthorizedWorkspaces = false;

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async {
    if (unauthorizedWorkspaces) throw const VenciraUnauthorized();
    return [workspace];
  }

  @override
  Future<VenciraRenewalPage> fetchFilteredRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = '', String entry = '', String modality = '',
      String insurer = ''}) async =>
      const VenciraRenewalPage(total: 0, items: [], hasNext: false);

  @override
  Future<List<VenciraModalityOption>> fetchModalities(String id) async =>
      VenciraModalityOption.defaults;
  @override
  Future<List<VenciraInsurer>> fetchInsurers(
      String id, {String search = ''}) async => const [];

  @override
  Future<void> logout() async { logoutCalls++; }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Widget shell(FakeApi api, Future<void> Function() before) =>
    VenciraPreferences(
      themeMode: ThemeMode.light, locale: const Locale('es'),
      setThemeMode: (_) {}, setLocale: (_) {},
      child: MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        home: VenciraDashboardScreen(
          api: api, beforeSessionBoundary: before,
        ),
      ),
    );

void main() {
  testWidgets('Expired authenticated session triggers local alarm revocation',
      (tester) async {
    final api = FakeApi()..unauthorizedWorkspaces = true;
    var revoked = 0;
    await tester.pumpWidget(shell(api, () async { revoked++; }));
    await tester.pumpAndSettle();
    expect(revoked, 1);
    expect(api.logoutCalls, 0);
    expect(find.text('Equipo de pruebas'), findsNothing);
    api.unauthorizedWorkspaces = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Equipo de pruebas'), findsWidgets);
  });

  testWidgets('401 cleanup failure blocks reload until native retry succeeds',
      (tester) async {
    final api = FakeApi()..unauthorizedWorkspaces = true;
    var attempts = 0;
    var cannotCancel = true;
    await tester.pumpWidget(shell(api, () async {
      attempts++;
      if (cannotCancel) throw StateError('OS alarm failed');
    }));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('Equipo de pruebas'), findsNothing);
    api.unauthorizedWorkspaces = false;
    cannotCancel = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Equipo de pruebas'), findsWidgets);
  });

  testWidgets('Server logout waits for Android alarm cancellation',
      (tester) async {
    final api = FakeApi();
    final alarmBarrier = Completer<void>();
    var called = 0;
    await tester.pumpWidget(shell(api, () async {
      called++;
      await alarmBarrier.future;
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pump();
    expect(called, 1);
    expect(api.logoutCalls, 0);
    alarmBarrier.complete();
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
  });

  testWidgets('Cancellation failure blocks server logout and allows retry',
      (tester) async {
    final api = FakeApi();
    var fail = true;
    var calls = 0;
    await tester.pumpWidget(shell(api, () async {
      calls++;
      if (fail) throw StateError('Alarm revocation unavailable');
    }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 0);
    expect(calls, 1);
    fail = false;
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
    expect(calls, 2);
  });
}
