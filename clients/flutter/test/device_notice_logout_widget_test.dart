import 'dart:async';

import 'package:flutter/foundation.dart';
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

const otherWorkspace = VenciraWorkspace(
  id: '99999999-9999-4999-8999-999999999999', name: 'Equipo nuevo',
  role: 'member',
);

class FakeApi implements VenciraApi {
  int logoutCalls = 0;
  bool unauthorizedWorkspaces = false;
  bool membershipRemoved = false;
  bool unauthorizedModalities = false;
  bool unauthorizedInsurers = false;
  Completer<List<VenciraModalityOption>>? delayedModalities;

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async {
    if (unauthorizedWorkspaces) throw const VenciraUnauthorized();
    return membershipRemoved ? [otherWorkspace] : [workspace];
  }

  @override
  Future<VenciraRenewalPage> fetchFilteredRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = '', String entry = '', String modality = '',
      String insurer = ''}) async =>
      const VenciraRenewalPage(total: 0, items: [], hasNext: false);

  @override
  Future<List<VenciraModalityOption>> fetchModalities(String id) async {
    if (delayedModalities != null) return delayedModalities!.future;
    if (unauthorizedModalities) throw const VenciraUnauthorized();
    return VenciraModalityOption.defaults;
  }
  @override
  Future<List<VenciraInsurer>> fetchInsurers(
      String id, {String search = ''}) async {
    if (unauthorizedInsurers) throw const VenciraUnauthorized();
    return const [];
  }

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

  testWidgets('Remote membership loss revokes old alarms before auto-switch',
      (tester) async {
    final api = FakeApi();
    var revoked = 0;
    await tester.pumpWidget(shell(api, () async { revoked++; }));
    await tester.pumpAndSettle();
    expect(find.text('Equipo de pruebas'), findsWidgets);
    api.membershipRemoved = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(revoked, 1);
    expect(find.text('Equipo de pruebas'), findsNothing);
    expect(find.text('Equipo nuevo'), findsWidgets);
  });

  testWidgets('Membership loss and failed cancel never shows new workspace',
      (tester) async {
    final api = FakeApi();
    var fail = true;
    var attempts = 0;
    await tester.pumpWidget(shell(api, () async {
      attempts++;
      if (fail) throw StateError('OS cancellation not acknowledged');
    }));
    await tester.pumpAndSettle();
    api.membershipRemoved = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('Equipo nuevo'), findsNothing);
    fail = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Equipo nuevo'), findsWidgets);
  });

  testWidgets('Failed membership revocation clears cached workspace and blocks late data',
      (tester) async {
    final api = FakeApi();
    var fail = true;
    await tester.pumpWidget(shell(api, () async {
      if (fail) throw StateError('OS cancellation not acknowledged');
    }));
    await tester.pumpAndSettle();
    expect(find.text('Equipo de pruebas'), findsWidgets);
    api.membershipRemoved = true;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Equipo de pruebas'), findsNothing);
    expect(find.text('Equipo nuevo'), findsNothing);
    fail = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Equipo nuevo'), findsWidgets);
  });

  testWidgets('Android privacy settings offer a real cancellation-only action',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
    final api = FakeApi();
    var cancellations = 0;
    await tester.pumpWidget(shell(api, () async { cancellations++; }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    final action = find.byKey(
        const ValueKey('settings-clear-local-notices'));
    expect(action, findsOneWidget);
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(cancellations, 1);
    expect(api.logoutCalls, 0);
    } finally {
      // Flutter asserts that foundation globals are reset by test body end.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  for (final endpoint in ['modalities', 'insurers']) {
    testWidgets('401 from $endpoint hides customer data and revokes alarms',
        (tester) async {
      final api = FakeApi();
      if (endpoint == 'modalities') {
        api.unauthorizedModalities = true;
      } else {
        api.unauthorizedInsurers = true;
      }
      var revoked = 0;
      await tester.pumpWidget(shell(api, () async { revoked++; }));
      await tester.pumpAndSettle();
      expect(revoked, greaterThanOrEqualTo(1));
      expect(find.text('Equipo de pruebas'), findsNothing);
      expect(api.logoutCalls, 0);
    });
  }

  testWidgets('Late catalog 401 after logout cannot trigger another revocation',
      (tester) async {
    final api = FakeApi()
      ..delayedModalities = Completer<List<VenciraModalityOption>>();
    var revocations = 0;
    await tester.pumpWidget(shell(api, () async { revocations++; }));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.logout));
    await tester.pumpAndSettle();
    expect(api.logoutCalls, 1);
    expect(revocations, 1);
    api.delayedModalities!.completeError(const VenciraUnauthorized());
    await tester.pumpAndSettle();
    expect(revocations, 1);
    expect(find.text('Equipo de pruebas'), findsNothing);
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
