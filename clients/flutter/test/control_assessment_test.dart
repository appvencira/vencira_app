import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/control_assessment_card.dart';

class FakeO9Api extends VenciraApi {
  int fetches = 0;
  bool manualReview = false;
  bool allowExplicit = false;
  int explicitCreates = 0;
  @override
  Future<void> createExplicitControl(String workspaceId, String renewalId,
      {required DateTime day, required String idempotencyKey}) async {
    explicitCreates++;
  }

  @override
  Future<VenciraControlAssessment> fetchControlAssessment(
      String workspaceId, String renewalId) async {
    fetches++;
    return VenciraControlAssessment(
      status: manualReview
          ? 'manual_review_required' : 'control_day_future_preview',
      reasons: manualReview ? ['no_notice_before_cutoff'] : [],
      controlDay: manualReview ? null : DateTime(2027, 2, 8),
      cutoffOn: DateTime(2027, 2, 15),
      controlDaysBefore: manualReview ? null : 35,
      draftPersisted: manualReview,
      c2Policy: allowExplicit ? VenciraC2Policy(
        allowSave: true, manualReviewRequired: true,
        warningCode: 'no_pre_cutoff_notice', offerExplicitControl: true,
        latestExplicitControlDay: DateTime.now().add(const Duration(days: 10)),
        isLife: false) : null,
    );
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
      VenciraAgendaDayPage(
          day: day, total: 0, entries: const [], hasNext: false);
  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async =>
      VenciraAgendaMonth(month: month, days: const []);
  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async =>
      throw UnimplementedError();
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

Widget screen(FakeO9Api api, String language, bool dark) => MaterialApp(
  locale: Locale(language),
  theme: ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
  ),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: SingleChildScrollView(child: VenciraControlAssessmentCard(
    api: api,
    workspaceId: '11111111-1111-4111-8111-111111111111',
    renewalId: '22222222-2222-4222-8222-222222222222',
  ))),
);

void main() {
  test('O9a tipado rechaza falsos envios y fechas imposibles', () {
    final data = <String, dynamic>{
      'assessment_only': true, 'answer_recorded': false,
      'scheduled': false, 'delivered': false,
      'status': 'control_day_future_preview', 'reasons': <String>[],
      'control_day': '2027-02-08',
      'informational_cutoff_on': '2027-02-15',
      'control_days_before': 35, 'draft_persisted': false,
    };
    final item = VenciraControlAssessment.fromJson(data);
    expect(item.controlDay, DateTime(2027, 2, 8));
    for (final field in ['answer_recorded', 'scheduled', 'delivered']) {
      expect(() => VenciraControlAssessment.fromJson({
        ...data, field: true,
      }), throwsFormatException);
    }
    expect(() => VenciraControlAssessment.fromJson({
      ...data, 'control_day': '2027-02-30',
    }), throwsFormatException);
    expect(() => VenciraControlAssessment.fromJson({
      ...data, 'reasons': ['not_a_real_reason'],
    }), throwsFormatException);
  });

  for (final lang in ['es', 'ca']) {
    testWidgets('C2 control explicito cancelar selector no crea nada $lang',
        (tester) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeO9Api()..manualReview = true..allowExplicit = true;
      await tester.pumpWidget(screen(api, lang, false));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('explicit-control-create'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(api.explicitCreates, 0);
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();

      await tester.pumpAndSettle();
      expect(api.explicitCreates, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lang in ['es', 'ca']) {
    testWidgets('C2 confirmation before single internal creation $lang',
        (tester) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakeO9Api()..manualReview = true..allowExplicit = true;
      await tester.pumpWidget(screen(api, lang, false));
      await tester.pumpAndSettle();
      final create = find.byKey(const ValueKey('explicit-control-create'));
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final date = DateUtils.dateOnly(DateTime.now());
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(date);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(api.explicitCreates, 0);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextButton)));
      await tester.pumpAndSettle();
      expect(api.explicitCreates, 0);
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DatePickerDialog))).pop(date);
      await tester.pumpAndSettle();
      expect(api.explicitCreates, 0);
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
      // Avoid waiting for all animations/indeterminate indicators to settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(api.explicitCreates, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final lang in ['es', 'ca']) {
    for (final dark in [false, true]) {
      testWidgets('O9a 320px no overflow ES/CA con recarga: $lang $dark',
          (tester) async {
        tester.view.physicalSize = const Size(320, 950);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final api = FakeO9Api();
        await tester.pumpWidget(screen(api, lang, dark));
        await tester.pumpAndSettle();
        expect(api.fetches, 1);
        expect(find.text(lang == 'ca'
            ? 'Control futur previst (no programat)'
            : 'Control futuro previsto (no programado)'), findsOneWidget);
        api.manualReview = true;
        final refresh = find.byKey(const ValueKey('control-assessment-refresh'));
        await tester.ensureVisible(refresh);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(api.fetches, 2);
        expect(find.text(lang == 'ca'
            ? 'Revisió manual pendent' : 'Revisión manual pendiente'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
