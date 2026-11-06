import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/insurer_catalog_screen.dart';

class InsurersApi extends VenciraApi {
  List<VenciraInsurer> companies = const [
    VenciraInsurer(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      name: 'Aseguradora Demo', active: true,
    ),
  ];

  @override
  Future<List<VenciraInsurer>> fetchInsurers(
      String workspaceId, {String search = ''}) async =>
      companies.where((x) =>
          x.name.toLowerCase().contains(search.toLowerCase())).toList();

  @override
  Future<VenciraInsurer> createInsurer(String workspaceId, String name) async {
    final value = VenciraInsurer(
      id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
      name: name, active: true,
    );
    companies = [...companies, value];
    return value;
  }

  @override
  Future<VenciraInsurer> renameInsurer(
      String workspaceId, String id, String name) async {
    companies = [
      for (final item in companies)
        if (item.id == id)
          VenciraInsurer(id: id, name: name, active: item.active)
        else item,
    ];
    return companies.firstWhere((x) => x.id == id);
  }

  @override
  Future<void> deactivateInsurer(String workspaceId, String id) async {
    companies = [
      for (final item in companies)
        if (item.id == id)
          VenciraInsurer(id: id, name: item.name, active: false)
        else item,
    ];
  }

  @override
  Future<VenciraInsurer> reactivateInsurer(String workspaceId, String id) async {
    companies = [
      for (final item in companies)
        if (item.id == id)
          VenciraInsurer(id: id, name: item.name, active: true)
        else item,
    ];
    return companies.firstWhere((x) => x.id == id);
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [];

  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = ''}) async =>
      const VenciraRenewalPage(total:0, items:[], hasNext:false);

  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
      String workspaceId, DateTime day, {int page = 1}) async =>
      VenciraAgendaDayPage(
        day: day, total:0, entries:const [], hasNext:false);

  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async =>
      VenciraAgendaMonth(month:month, days:const []);

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async =>
      throw const VenciraApiException();

  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1}) async =>
      const VenciraHistoryPage(total:0, events:[], hasNext:false);

  @override
  Future<VenciraRenewal> createRenewal(
      String workspaceId, VenciraRenewalInput input) async =>
      throw const VenciraApiException();

  @override
  Future<VenciraRenewal> updateRenewal(
      String workspaceId, String renewalId, VenciraRenewalInput input) async =>
      throw const VenciraApiException();

  @override
  Future<void> logout() async {}
}

void main() {
  for (final language in ['es', 'ca']) {
    testWidgets('catálogo de aseguradoras en móvil $language',
        (tester) async {
      tester.view.physicalSize = const Size(375, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = InsurersApi();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraInsurerCatalogScreen(
          api: api,
          workspace: const VenciraWorkspace(
            id: '11111111-1111-4111-8111-111111111111',
            name: 'Cuenta ficticia',
            role: 'owner',
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Aseguradora Demo'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('insurer-name')), 'Seguros Ficticios');
      await tester.tap(find.text(language == 'es' ? 'Guardar' : 'Desar').last);
      await tester.pumpAndSettle();
      expect(find.text('Seguros Ficticios'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('un miembro solo puede consultar', (tester) async {
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: VenciraInsurerCatalogScreen(
        api: InsurersApi(),
        workspace: const VenciraWorkspace(
          id: '11111111-1111-4111-8111-111111111111',
          name: 'Cuenta ficticia',
          role: 'member',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Aseguradora Demo'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
