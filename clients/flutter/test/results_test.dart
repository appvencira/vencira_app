import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/results_screen.dart';
import 'package:vencira/ui/dashboard_screen.dart';

const work = VenciraWorkspace(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Cuenta de pruebas', role: 'owner',
);

class FakeResultsApi extends VenciraApi {
  String period = '';
  String workspaceId = '';
  int? month;
  int? quarter;
  int year = 0;
  int fetches = 0;
  bool deny = false;
  bool includeBreakdown = false;

  @override
  Future<VenciraResultsSummary> fetchResults(
      String workspaceId, {required String period, required int year,
      int? month, int? quarter}) async {
    if (deny) throw const VenciraUnauthorized();
    this.workspaceId = workspaceId;
    this.period = period;
    this.month = month;
    this.quarter = quarter;
    this.year = year;
    fetches++;
    return VenciraResultsSummary(
      period: period, won: 3, declined: 2, discarded: 1, pending: 4,
      byUser: includeBreakdown ? const [
        VenciraResultsUser(userId: '17', name: 'Mediador de prueba',
          won: 3, declined: 2, discarded: 1, pending: 4),
      ] : const [],
    );
  }
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [work];
  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '', String status = ''}) async =>
      const VenciraRenewalPage(total: 0, items: [], hasNext: false);
  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
      String workspaceId, DateTime day, {int page = 1}) async =>
      VenciraAgendaDayPage(day: day, total: 0, entries: const [], hasNext: false);
  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async =>
      VenciraAgendaMonth(month: month, days: const []);
  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async => throw UnimplementedError();
  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1}) async =>
      const VenciraHistoryPage(total: 0, events: [], hasNext: false);
  @override
  Future<VenciraRenewal> createRenewal(
      String workspaceId, VenciraRenewalInput input) async =>
      throw UnimplementedError();
  @override
  Future<VenciraRenewal> updateRenewal(
      String workspaceId, String renewalId, VenciraRenewalInput input) async =>
      throw UnimplementedError();
  @override
  Future<void> logout() async {}
}

Widget shell(Widget child, String lang) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  test('API results type validation rejects invalid counts', () {
    const base = {
      'period': 'month', 'from': '2027-03-01',
      'to_exclusive': '2027-04-01',
      'won': 3, 'declined': 0, 'discarded': 1, 'pending': 4,
      'by_user': [
        {'user_id': '17', 'name': 'Mediador de prueba',
         'won': 3, 'declined': 0, 'discarded': 1, 'pending': 4},
      ],
    };
    final result = VenciraResultsSummary.fromJson(base);
    expect(result.won, 3);
    expect(result.pending, 4);
    expect(() => VenciraResultsSummary.fromJson({...base, 'won': -1}),
        throwsFormatException);
    expect(() => VenciraResultsSummary.fromJson({...base, 'won': '3'}),
        throwsFormatException);
    expect(() => VenciraResultsSummary.fromJson({...base, 'period': 'week'}),
        throwsFormatException);
  });

  test('M3 results rejects nonreconciled, duplicate or invalid users', () {
    const base = <String, dynamic>{
      'period': 'month', 'from': '2027-03-01',
      'to_exclusive': '2027-04-01',
      'won': 1, 'declined': 0, 'discarded': 0, 'pending': 0,
      'by_user': [
        {'user_id': '9', 'name': 'Operador',
         'won': 1, 'declined': 0, 'discarded': 0, 'pending': 0},
      ],
    };
    expect(VenciraResultsSummary.fromJson(base).byUser.single.name,
        'Operador');
    expect(() => VenciraResultsSummary.fromJson({
      ...base, 'won': 2,
    }), throwsFormatException);
    expect(() => VenciraResultsSummary.fromJson({
      ...base,
      'by_user': [...(base['by_user'] as List), ...(base['by_user'] as List)],
    }), throwsFormatException);
    expect(() => VenciraResultsSummary.fromJson({
      ...base,
      'by_user': [
        {'user_id': null, 'name': 'Someone',
         'won': 1, 'declined': 0, 'discarded': 0, 'pending': 0},
      ],
    }), throwsFormatException);
  });

  for (final lang in ['es', 'ca']) {
    testWidgets('M3 owner sees per-user results table $lang', (tester) async {
      tester.view.physicalSize = const Size(1100, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeResultsApi()..includeBreakdown = true;
      await tester.pumpWidget(shell(VenciraResultsScreen(
        api: api, workspace: work), lang));
      await tester.pumpAndSettle();
      expect(find.text('Mediador de prueba'), findsOneWidget);
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text(lang == 'es'
        ? 'Resultados por usuario' : 'Resultats per usuari'), findsOneWidget);
    });
  }

  for (final lang in ['es', 'ca']) {
    testWidgets('O7 resultados agregados desktop y cambios de periodo $lang',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeResultsApi();
      await tester.pumpWidget(shell(VenciraResultsScreen(
        api: api, workspace: work), lang));
      await tester.pumpAndSettle();
      expect(api.period, 'month');
      expect(api.workspaceId, work.id);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('results-period-quarter')));
      await tester.pumpAndSettle();
      expect(api.period, 'quarter');
      expect(api.quarter, isNotNull);
      await tester.tap(find.byKey(const ValueKey('results-previous')));
      await tester.pumpAndSettle();
      expect(api.fetches, greaterThanOrEqualTo(3));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('results-period-year')));
      await tester.pumpAndSettle();
      expect(api.period, 'year');
      expect(api.month, isNull);
      expect(api.quarter, isNull);
    });
  }

  testWidgets('O7 no datos ni contadores si la sesión caduca',
      (tester) async {
    final api = FakeResultsApi()..deny = true;
    await tester.pumpWidget(shell(VenciraResultsScreen(
        api: api, workspace: work), 'es'));
    await tester.pumpAndSettle();
    expect(find.text('Necesitas iniciar sesión para acceder a VENCIRA.'),
        findsOneWidget);
    expect(find.text('3'), findsNothing);
  });

  testWidgets('O7 no añade resultados en dashboard móvil', (tester) async {
    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(shell(
      VenciraDashboardScreen(api: FakeResultsApi()), 'es',
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('open-results')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
