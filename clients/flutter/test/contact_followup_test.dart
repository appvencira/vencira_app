import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';
import 'package:vencira/ui/vencira_theme.dart';

class _ContactApi extends VenciraApi {
  VenciraRenewal renewal = VenciraRenewal(
    id: 'b2222222-2222-4222-8222-222222222222',
    reference: 'DEMO-SIN-DATOS-REALES',
    expiresOn: DateTime(2027, 5, 1),
    status: 'pending',
    notes: 'Anotación sintética previa',
  );
  int writes = 0;

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async => renewal;

  @override
  Future<VenciraRenewal> changeRenewalStatus(
      String workspaceId, String renewalId, String status) async {
    writes++;
    renewal = VenciraRenewal(
      id: renewal.id, reference: renewal.reference,
      expiresOn: renewal.expiresOn,
      noticeDeadlineOn: renewal.noticeDeadlineOn,
      status: status,
      notes: renewal.notes,
    );
    return renewal;
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
      String workspaceId, String renewalId,
      VenciraRenewalInput input) async => throw UnimplementedError();
  @override
  Future<void> logout() async {}
}

void main() {
  for (final code in ['es', 'ca']) {
    testWidgets('contacto manual exige confirmar y no altera notas ($code)',
        (tester) async {
      tester.view.physicalSize = const Size(375, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _ContactApi();
      await tester.pumpWidget(MaterialApp(
        theme: VenciraTheme.light(),
        locale: Locale(code),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraRenewalDetailScreen(
          api: api,
          workspace: const VenciraWorkspace(
            id: '11111111-1111-4111-8111-111111111111',
            name: 'Demo', role: 'owner',
          ),
          renewalId: api.renewal.id,
        ),
      ));
      await tester.pumpAndSettle();
      final action = find.byKey(const ValueKey('mark-contacted'));
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      expect(find.text(code == 'ca' ? 'Registrar contacte'
          : 'Registrar contacto'), findsOneWidget);
      await tester.tap(find.text(
        AppLocalizations.of(tester.element(find.byType(AlertDialog)))!.cancel));
      await tester.pumpAndSettle();
      expect(api.writes, 0);

      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.writes, 1);
      expect(api.renewal.status, 'contacted');
      expect(api.renewal.notes, 'Anotación sintética previa');
      expect(find.byKey(const ValueKey('restore-pending')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
