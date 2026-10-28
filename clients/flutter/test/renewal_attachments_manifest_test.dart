import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/ui/renewal_attachments_card.dart';

class FakeManifestApi extends VenciraApi {
  int requests = 0;
  bool fail = false;

  @override
  Future<Map<String, dynamic>> fetchAttachmentManifest(
      String workspaceId, String renewalId) async {
    requests++;
    if (fail) throw const VenciraApiException();
    return {
      'capabilities': {'upload': false, 'download': false, 'delete': false},
      'results': [
        {'id': 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
         'display_name': 'documento-ficticio.pdf', 'state': 'quarantined'},
      ],
    };
  }

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [];
  @override
  Future<VenciraRenewalPage> fetchRenewals(String workspaceId,
      {int page = 1, String search = '', String status = ''}) async =>
      const VenciraRenewalPage(total: 0, items: [], hasNext: false);
  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(String workspaceId,
      DateTime day, {int page = 1}) async =>
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

void main() {
  for (final locale in ['es', 'ca']) {
    testWidgets('manifest metadata only and no actions $locale', (tester) async {
      final api = FakeManifestApi();
      Widget panel() => MaterialApp(
        home: Scaffold(body: SingleChildScrollView(
          child: VenciraRenewalAttachmentsCard(
            locale: locale, api: api, workspaceId: 'workspace-test',
            renewalId: 'renewal-test'),
        )),
      );
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(find.text('documento-ficticio.pdf'), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
      expect(api.requests, 1);
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(api.requests, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('manifest errors fail closed $locale', (tester) async {
      final api = FakeManifestApi()..fail = true;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: VenciraRenewalAttachmentsCard(
          locale: locale, api: api,
          workspaceId: 'workspace-test', renewalId: 'renewal-test')),
      ));
      await tester.pumpAndSettle();
      expect(find.text(locale == 'ca'
        ? 'Documents no disponibles' : 'Documentos no disponibles'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
