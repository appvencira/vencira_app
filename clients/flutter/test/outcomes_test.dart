import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';
import 'package:vencira/ui/vencira_theme.dart';

class _OutcomesApi extends VenciraApi {
  VenciraRenewal item = VenciraRenewal(
    id: 'b2222222-2222-4222-8222-222222222222',
    reference: 'O3-DEMO',
    expiresOn: DateTime(2028, 2, 29),
    status: 'contacted', entry: 'prospects', notes: 'Ficticio',
  );
  VenciraFollowUp? followUp;
  int writes = 0;
  String? lastKind;
  DateTime? lastFollowDay;

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async => item;
  @override
  Future<VenciraFollowUp?> fetchManualFollowUp(
      String workspaceId, String renewalId) async => followUp;
  @override
  Future<void> applyOutcome(
      String workspaceId, String renewalId, String kind,
      {DateTime? scheduledFor}) async {
    writes++;
    lastKind = kind;
    lastFollowDay = scheduledFor;
    final archived = kind == 'won' || kind == 'discarded';
    if (kind == 'undecided') {
      followUp = VenciraFollowUp(
        id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
        scheduledFor: scheduledFor!,
      );
    }
    item = VenciraRenewal(
      id: item.id, reference: item.reference,
      expiresOn: kind == 'declined' ? DateTime(2029, 2, 28)
                                  : item.expiresOn,
      status: archived ? 'closed' :
          kind == 'restored' || kind == 'declined'
              ? 'pending' : item.status,
      entry: kind == 'won' ? 'clients'
           : kind == 'restored' ? 'prospects' : item.entry,
      notes: item.notes,
      archiveOutcome: archived ? kind : '',
    );
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
      String workspaceId, DateTime month) async => throw UnimplementedError();
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
  for (final lang in ['es', 'ca']) {
    testWidgets('O3 resultado ganado archivado y recuperable en móvil $lang',
        (tester) async {
      tester.view.physicalSize = const Size(375, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _OutcomesApi();
      await tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        theme: VenciraTheme.light(),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraRenewalDetailScreen(
          api: api,
          workspace: const VenciraWorkspace(
            id: '11111111-1111-4111-8111-111111111111',
            name: 'Demo', role: 'owner'),
          renewalId: api.item.id,
        ),
      ));
      await tester.pumpAndSettle();

      final choose = find.byKey(const ValueKey('choose-outcome'));
      // This card is below O1/O2 content in a lazily built ListView.
      // Build it by scrolling first, then bring it into the viewport.
      await tester.scrollUntilVisible(
        choose, 180, scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(choose);
      await tester.pumpAndSettle();
      await tester.tap(choose);
      await tester.pumpAndSettle();
      final won = find.byKey(const ValueKey('outcome-won'));
      expect(won, findsOneWidget);
      expect(api.writes, 0);
      await tester.tap(won);
      await tester.pumpAndSettle();
      expect(api.writes, 0);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.lastKind, 'won');
      expect(api.writes, 1);
      expect(api.item.status, 'closed');
      expect(api.item.entry, 'clients');

      final restore = find.byKey(const ValueKey('restore-outcome'));
      // The archived card is rebuilt after the POST and may be lazy.
      await tester.scrollUntilVisible(
        restore, 180, scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(restore);
      await tester.pumpAndSettle();
      await tester.tap(restore);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
      expect(api.writes, 2);
      expect(api.item.status, 'pending');
      expect(api.item.entry, 'prospects');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('O3 aún sin decidir utiliza fecha civil y O2',
      (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _OutcomesApi();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'), theme: VenciraTheme.light(),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: VenciraRenewalDetailScreen(
        api: api,
        workspace: const VenciraWorkspace(
          id: '11111111-1111-4111-8111-111111111111',
          name: 'Demo', role: 'owner'),
        renewalId: api.item.id,
      ),
    ));
    await tester.pumpAndSettle();
    final choose = find.byKey(const ValueKey('choose-outcome'));
    // This card is below O1/O2 content in a lazily built ListView.
    // Build it by scrolling first, then bring it into the viewport.
    await tester.scrollUntilVisible(
      choose, 180, scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(choose);
    await tester.pumpAndSettle();
    await tester.tap(choose);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('outcome-undecided')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('En 3 días'));
    await tester.pumpAndSettle();
    expect(api.writes, 0);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(api.lastKind, 'undecided');
    expect(api.lastFollowDay, isNotNull);
    expect(api.followUp, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
