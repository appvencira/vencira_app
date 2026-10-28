import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/dashboard_screen.dart';
import 'package:vencira/ui/renewal_archive_screen.dart';

const workspace = VenciraWorkspace(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Correduría ficticia', role: 'owner',
);

class ArchiveApi extends VenciraApi {
  String lastStatus = '';
  String lastWorkspace = '';
  int lastPage = 0;
  bool deny = false;

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [workspace];

  @override
  Future<VenciraRenewalPage> fetchFilteredRenewals(
    String workspaceId, {int page = 1, String search = '', String status = '',
    String entry = '', String modality = '', String insurer = '',
  }) async {
    lastStatus = status;
    lastWorkspace = workspaceId;
    lastPage = page;
    if (deny) throw const VenciraUnauthorized();
    if (status != 'closed') {
      return const VenciraRenewalPage(total: 0, items: [], hasNext: false);
    }
    if (page > 1) {
      return const VenciraRenewalPage(total: 2, items: [], hasNext: false);
    }
    return VenciraRenewalPage(total: 2, hasNext: true, items: [
      VenciraRenewal(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        reference: 'DEMO-CONSEGUIDO',
        expiresOn: DateTime(2027, 5, 15), status: 'closed',
        archiveOutcome: 'won',
      ),
      VenciraRenewal(
        id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
        reference: 'DEMO-ANTIGUO',
        expiresOn: DateTime(2027, 8, 1), status: 'closed',
      ),
    ]);
  }

  @override
  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {int page = 1, String search = '', String status = '',
  }) async => fetchFilteredRenewals(
    workspaceId, page: page, search: search, status: status,
  );

  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1}
  ) async => VenciraAgendaDayPage(
    day: day, total: 0, entries: const [], hasNext: false,
  );

  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
    String workspaceId, DateTime month,
  ) async => VenciraAgendaMonth(month: month, days: const []);

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
    String workspaceId, String renewalId,
  ) async => throw UnimplementedError();

  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
    String workspaceId, String renewalId, {int page = 1}
  ) async => const VenciraHistoryPage(total: 0, events: [], hasNext: false);

  @override
  Future<VenciraRenewal> createRenewal(
    String workspaceId, VenciraRenewalInput input,
  ) async => throw UnimplementedError();

  @override
  Future<VenciraRenewal> updateRenewal(
    String workspaceId, String renewalId, VenciraRenewalInput input,
  ) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

Widget wrap(Widget child, String lang) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);

void main() {
  for (final lang in ['es', 'ca']) {
    testWidgets('O6 archivo autorizado, outcome legacy y página $lang',
        (tester) async {
      tester.view.physicalSize = const Size(375, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ArchiveApi();
      await tester.pumpWidget(wrap(
        VenciraArchiveScreen(api: api, workspace: workspace), lang,
      ));
      await tester.pumpAndSettle();
      expect(api.lastStatus, 'closed');
      expect(api.lastWorkspace, workspace.id);
      expect(api.lastPage, 1);
      expect(find.text('DEMO-CONSEGUIDO'), findsOneWidget);
      expect(find.text('DEMO-ANTIGUO'), findsOneWidget);
      expect(find.textContaining(lang == 'ca'
        ? 'Tancament anterior · Sense desenllaç registrat'
        : 'Cierre anterior · Sin desenlace registrado'), findsOneWidget);
      expect(find.byKey(const ValueKey(
        'archive-item-aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text(lang == 'ca' ? 'Següent' : 'Siguiente'));
      await tester.pumpAndSettle();
      expect(api.lastPage, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('O6 entrada desde panel sin perder ámbito $lang',
        (tester) async {
      tester.view.physicalSize = const Size(375, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ArchiveApi();
      await tester.pumpWidget(wrap(
        VenciraDashboardScreen(api: api), lang,
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('open-archive')));
      await tester.tap(find.byKey(const ValueKey('open-archive')));
      await tester.pumpAndSettle();
      expect(find.byType(VenciraArchiveScreen), findsOneWidget);
      expect(api.lastStatus, 'closed');
      expect(api.lastWorkspace, workspace.id);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('O6 no filtra anotaciones al perder sesión',
      (tester) async {
    final api = ArchiveApi()..deny = true;
    await tester.pumpWidget(wrap(
      VenciraArchiveScreen(api: api, workspace: workspace), 'es',
    ));
    await tester.pumpAndSettle();
    expect(find.text('Necesitas iniciar sesión para acceder a VENCIRA.'),
        findsOneWidget);
    expect(find.text('DEMO-CONSEGUIDO'), findsNothing);
  });
}
