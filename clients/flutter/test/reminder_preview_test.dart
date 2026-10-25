import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/reminder_preview_card.dart';

class FakePreviewApi extends VenciraApi {
  int reads = 0;
  List<int>? lastDays;
  @override
  Future<VenciraReminderPreview> fetchReminderPreview(
      String workspaceId, String renewalId, {List<int>? daysBefore}) async {
    reads++;
    lastDays = daysBefore;
    return VenciraReminderPreview(
      expiresOn: DateTime(2027, 3, 15),
      cutoffOn: DateTime(2027, 2, 15),
      referenceDay: DateTime(2027, 1, 1),
      noPreCutoffNotice: daysBefore != null && !daysBefore.contains(60),
      lateControlNeedsDecision: false,
      cutoffAlreadyElapsed: false,
      lifeRuleRequiresReview: false,
      reminders: [
        VenciraPreviewReminder(
          daysBefore: 60, scheduledFor: _day,
          controlQuestion: false, alreadyElapsed: false),
      ],
    );
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [];
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

final DateTime _day = DateTime(2027, 1, 14);

Widget screen(FakePreviewApi api, String lang) => MaterialApp(
  locale: Locale(lang),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: Scaffold(body: ListView(children: [
    VenciraReminderPreviewCard(
      api: api,
      workspaceId: '11111111-1111-4111-8111-111111111111',
      renewalId: '22222222-2222-4222-8222-222222222222',
    ),
  ])),
);

void main() {
  test('Read-only server contract rejects forged delivery and dates', () {
    final data = <String, dynamic>{
      'expires_on': '2027-03-15', 'reference_day': '2027-01-01',
      'informational_cutoff_on': '2027-02-15',
      'preview_only': true, 'delivered': false,
      'no_pre_cutoff_notice': false,
      'late_control_needs_decision': false,
      'cutoff_already_elapsed': false,
      'life_rule_requires_review': false,
      'reminders': [
        <String, dynamic>{
          'days_before': 35, 'scheduled_for': '2027-02-08',
          'before_cutoff': true, 'control_question': true,
          'already_elapsed': false,
        },
      ],
    };
    final parsed = VenciraReminderPreview.fromJson(data);
    expect(parsed.reminders.single.daysBefore, 35);
    expect(parsed.reminders.single.controlQuestion, true);
    expect(() => VenciraReminderPreview.fromJson({...data, 'delivered': true}),
        throwsFormatException);
    expect(() => VenciraReminderPreview.fromJson({
      ...data, 'informational_cutoff_on': '2027-02-30'
    }), throwsFormatException);
  });

  for (final lang in ['es', 'ca']) {
    testWidgets('O8b localized preview is read-only and validates input $lang',
        (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = FakePreviewApi();
      await tester.pumpWidget(screen(api, lang));
      await tester.pumpAndSettle();
      expect(api.reads, 1);
      expect(find.text(lang == 'ca' ? 'Simulador d’avisos' : 'Simulador de avisos'),
          findsOneWidget);
      expect(find.textContaining('60'), findsWidgets);
      await tester.enterText(find.byKey(const ValueKey('reminder-preview-days')),
          '20,15');
      await tester.ensureVisible(find.byKey(
          const ValueKey('reminder-preview-calculate')));
      await tester.tap(find.byKey(const ValueKey('reminder-preview-calculate')));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(api.lastDays, [20, 15]);
      await tester.enterText(find.byKey(const ValueKey('reminder-preview-days')),
          '35,35');
      await tester.tap(find.byKey(const ValueKey('reminder-preview-calculate')));
      await tester.pumpAndSettle();
      expect(api.reads, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
