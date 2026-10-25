import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/reminder_draft_card.dart';

class FakeDraftApi extends VenciraApi {
  int reads = 0;
  int writes = 0;
  int revision = 0;
  bool conflict = false;
  List<int> days = [60, 45, 35];

  VenciraReminderDraft get current => VenciraReminderDraft(
    daysBefore: List<int>.from(days), revision: revision,
    isPersisted: revision > 0, noPreCutoffNotice: days.length == 2,
    lifeRuleRequiresReview: false,
  );

  @override
  Future<VenciraReminderDraft> fetchReminderDraft(
      String workspaceId, String renewalId) async {
    reads++;
    return current;
  }

  @override
  Future<VenciraReminderDraft> saveReminderDraft(
      String workspaceId, String renewalId,
      {required int revision, required List<int> daysBefore}) async {
    writes++;
    if (conflict || revision != this.revision) {
      throw const VenciraConflictException();
    }
    days = List<int>.from(daysBefore)..sort((a, b) => b.compareTo(a));
    this.revision += 1;
    return current;
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [];
  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = ''}) async =>
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

Widget shell(FakeDraftApi api, String language, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  locale: Locale(language),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: VenciraReminderDraftCard(
    api: api,
    workspaceId: '11111111-1111-4111-8111-111111111111',
    renewalId: '22222222-2222-4222-8222-222222222222',
  ))),
);

void main() {
  test('El contrato tipado rechaza aviso habilitado o entregado', () {
    final json = <String, dynamic>{
      'state': 'draft', 'revision': 0, 'is_persisted': false,
      'days_before': [60, 45, 35], 'no_pre_cutoff_notice': false,
      'life_rule_requires_review': false, 'delivered': false,
      'scheduling_enabled': false,
    };
    expect(VenciraReminderDraft.fromJson(json).revision, 0);
    expect(() => VenciraReminderDraft.fromJson({
      ...json, 'scheduling_enabled': true,
    }), throwsFormatException);
    expect(() => VenciraReminderDraft.fromJson({
      ...json, 'state': 'enabled',
    }), throwsFormatException);
    expect(() => VenciraReminderDraft.fromJson({
      ...json, 'is_persisted': true,
    }), throwsFormatException);
  });

  for (final lang in ['es', 'ca']) {
    testWidgets('O8c guarda borrador y rechaza dias duplicados: $lang',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeDraftApi();
      await tester.pumpWidget(shell(api, lang));
      await tester.pumpAndSettle();
      expect(api.reads, 1);
      expect(find.text(lang == 'ca' ? 'Desar esborrany d’avisos'
                                   : 'Guardar borrador de avisos'),
          findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('draft-days')), '20,15');
      final save = find.byKey(const ValueKey('save-draft'));
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(api.days, [20, 15]);
      expect(api.revision, 1);
      await tester.enterText(find.byKey(const ValueKey('draft-days')), '35,35');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lang in ['es', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets('O8c márgenes legibles a 320px: $lang dark=$dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = FakeDraftApi()
          ..revision = 1
          ..days = [20, 15];
        await tester.pumpWidget(shell(
          api,
          lang,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
            useMaterial3: true,
          ),
        ));
        await tester.pumpAndSettle();

        final savedText = lang == 'ca'
            ? 'Esborrany desat' : 'Borrador guardado';
        final warningText = lang == 'ca'
            ? 'Sense avís anterior al límit informatiu.'
            : 'Sin aviso anterior al límite informativo.';
        final saved = find.text(savedText);
        final field = find.byKey(const ValueKey('draft-days'));
        final warning = find.text(warningText);
        final save = find.byKey(const ValueKey('save-draft'));

        expect(saved, findsOneWidget);
        expect(field, findsOneWidget);
        expect(warning, findsOneWidget);
        await tester.ensureVisible(save);
        await tester.pumpAndSettle();

        // El estado no puede pisar la etiqueta flotante del TextField.
        final statusBottom = tester.getBottomLeft(saved).dy;
        final inputTop = tester.getTopLeft(field).dy;
        expect(inputTop - statusBottom, greaterThanOrEqualTo(16));

        // El aviso legal debe terminar antes del botón de guardar.
        final warningBottom = tester.getBottomLeft(warning).dy;
        final buttonTop = tester.getTopLeft(save).dy;
        expect(buttonTop - warningBottom, greaterThanOrEqualTo(12));
        expect(tester.takeException(), isNull);
        expect(api.writes, 0);
      });
    }
  }

  testWidgets('O8c conflicto exige recargar y nunca sobrescribe', (tester) async {
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeDraftApi()..conflict = true;
    await tester.pumpWidget(shell(api, 'es'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('draft-days')), '20,15');
    await tester.ensureVisible(find.byKey(const ValueKey('save-draft')));
    await tester.tap(find.byKey(const ValueKey('save-draft')));
    await tester.pumpAndSettle();
    expect(api.writes, 1);
    expect(api.revision, 0);
    expect(find.byKey(const ValueKey('draft-reload')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('draft-reload')));
    await tester.tap(find.byKey(const ValueKey('draft-reload')));
    await tester.pumpAndSettle();
    expect(api.reads, 2);
    expect(tester.takeException(), isNull);
  });
}
