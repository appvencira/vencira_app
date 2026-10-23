import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';
import 'package:vencira/ui/vencira_theme.dart';

class _FakeFollowUps extends VenciraApi {
  final renewal = VenciraRenewal(
    id: 'b2222222-2222-4222-8222-222222222222',
    reference: 'DEMO-2027', expiresOn: DateTime(2027, 6, 15),
    status: 'contacted',
  );
  VenciraFollowUp? followUp;
  int schedules = 0;
  int resolves = 0;

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async => renewal;
  @override
  Future<VenciraFollowUp?> fetchManualFollowUp(
      String workspaceId, String renewalId) async => followUp;
  @override
  Future<VenciraFollowUp> scheduleManualFollowUp(
      String workspaceId, String renewalId, DateTime day) async {
    schedules++;
    followUp = VenciraFollowUp(
      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', scheduledFor: day);
    return followUp!;
  }
  @override
  Future<void> resolveManualFollowUp(
      String workspaceId, String renewalId, String followUpId,
      String action) async {
    resolves++;
    followUp = null;
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => const [];
  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = ''}) async => throw UnimplementedError();
  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
      String workspaceId, DateTime day, {int page = 1}) async =>
      throw UnimplementedError();
  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async =>
      throw UnimplementedError();
  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1}) async =>
      throw UnimplementedError();
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

void main() {
  for (final language in ['es', 'ca']) {
    testWidgets('O2 programa, confirma y cancela fecha civil - $language',
        (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _FakeFollowUps();
      await tester.pumpWidget(MaterialApp(
        theme: VenciraTheme.light(), locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraRenewalDetailScreen(
          api: api,
          workspace: const VenciraWorkspace(
            id: '11111111-1111-4111-8111-111111111111',
            name: 'Demo', role: 'owner'),
          renewalId: api.renewal.id,
        ),
      ));
      await tester.pumpAndSettle();
      final schedule = find.byKey(const ValueKey('schedule-follow-up'));
      // The ListView eagerly builds its children: scrollUntilVisible can
      // return before scrolling because the widget already exists off-screen.
      await tester.ensureVisible(schedule);
      await tester.pumpAndSettle();
      await tester.tap(schedule);
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'ca'
          ? 'D’aquí a 3 dies' : 'En 3 días'));
      await tester.pumpAndSettle();
      expect(api.schedules, 1);
      expect(api.followUp, isNotNull);
      expect(tester.takeException(), isNull);

      final complete = find.byKey(const ValueKey('complete-follow-up'));
      await tester.ensureVisible(complete);
      await tester.pumpAndSettle();
      await tester.tap(complete);
      await tester.pumpAndSettle();
      expect(api.resolves, 0);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.resolves, 1);
      expect(api.followUp, isNull);
      expect(tester.takeException(), isNull);
    });
  }

  test('Agenda O2 acepta follow-up e historial mensual sin eventos clásicos', () {
    final entry = VenciraAgendaEvent.fromJson({'kind': 'follow_up'});
    expect(entry.kind, 'follow_up');
    final month = VenciraAgendaMonth.fromJson({
      'month': '2027-03',
      'days': [
        {
          'day': '2027-03-25',
          'expiry': {'pending': 0, 'contacted': 0},
          'notice_deadline': {'pending': 0, 'contacted': 0},
          'reminder': {'pending': 0, 'contacted': 0},
          'follow_up': {'pending': 1, 'contacted': 0},
        }
      ],
    });
    expect(month.days.single.followUp.pending, 1);
    expect(month.days.single.expiry.total, 0);
  });
}
