import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';
import 'package:vencira/ui/operational_history_index_screen.dart';
import 'package:vencira/ui/vencira_pagination_bar.dart';

class _HistoryIndexApi extends VenciraApi {
  _HistoryIndexApi(this.rows);
  final List<VenciraOperationalReminder> rows;

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async => VenciraRenewal(
    id: renewalId,
    reference: 'DEMO-CERRADO',
    fullName: 'Cliente de prueba',
    expiresOn: DateTime(2027, 6, 20),
    status: 'closed',
    archiveOutcome: 'won',
  );

  @override
  Future<List<VenciraOperationalReminder>> fetchOperationalReminders(
      String workspaceId, String renewalId) async => rows;

  @override
  Future<VenciraOperationalHistory> fetchOperationalHistory(
      String workspaceId, String renewalId, String reminderId,
      {int page = 1}) async => const VenciraOperationalHistory(
    count: 0, hasNext: false, items: []);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const workspace = VenciraWorkspace(
    id: '11111111-1111-4111-8111-111111111111',
    name: 'Demo',
    role: 'owner',
  );
  const renewalId = '22222222-2222-4222-8222-222222222222';

  Future<void> mountDetail(WidgetTester tester, _HistoryIndexApi api) async {
    await tester.pumpWidget(MaterialApp(
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      locale: const Locale('es'),
      home: VenciraRenewalDetailScreen(
        api: api, workspace: workspace, renewalId: renewalId),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in <double>[320, 375, 768]) {
    testWidgets('CTA premium historial llena el ancho de las tarjetas a ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraRenewalDetailScreen(
          api: _HistoryIndexApi([]),
          workspace: workspace,
          renewalId: renewalId),
      ));
      await tester.pumpAndSettle();
      final shortcut = find.byKey(const ValueKey('detail-operational-history'));
      final contact = find.ancestor(
        of: find.text('Contacto'), matching: find.byType(Card)).first;
      expect(shortcut, findsOneWidget);
      expect(contact, findsOneWidget);
      final actionRect = tester.getRect(shortcut);
      final contactRect = tester.getRect(contact);
      expect(actionRect.left, closeTo(contactRect.left, 1));
      expect(actionRect.right, closeTo(contactRect.right, 1));
      expect(actionRect.width, greaterThan(width * 0.8));
      expect(actionRect.height, greaterThanOrEqualTo(76));
      expect(find.text('Consultar actuaciones registradas'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[320, 375]) {
    testWidgets('Historial visible incluso en una anotación cerrada a ${width.toInt()}',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _HistoryIndexApi([
        VenciraOperationalReminder(
          id: '33333333-3333-4333-8333-333333333333',
          reason: 'Aviso finalizado', state: 'completed',
          day: DateTime(2027, 2, 4), controlQuestion: false),
        VenciraOperationalReminder(
          id: '44444444-4444-4444-8444-444444444444',
          reason: 'Aviso cancelado', state: 'cancelled',
          day: DateTime(2027, 2, 5), controlQuestion: false),
      ]);
      await mountDetail(tester, api);
      final open = find.byKey(const ValueKey('detail-operational-history'));
      expect(open, findsOneWidget);
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.byType(VenciraOperationalHistoryIndexScreen), findsOneWidget);
      expect(find.text('Aviso finalizado'), findsOneWidget);
      expect(find.text('Aviso cancelado'), findsOneWidget);
      await tester.tap(find.text('Aviso finalizado'));
      await tester.pumpAndSettle();
      expect(find.text('Historial del aviso'), findsOneWidget);
      expect(find.text('Este aviso todavía no tiene actuaciones registradas.'),
        findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Historial index vacío accesible, sin mensajes de entrega',
      (tester) async {
    await mountDetail(tester, _HistoryIndexApi([]));
    final open = find.byKey(const ValueKey('detail-operational-history'));
    await tester.tap(open);
    await tester.pumpAndSettle();
    expect(find.text('Esta anotación no tiene avisos internos registrados.'),
      findsOneWidget);
    expect(find.textContaining('No representan notificaciones enviadas.'),
      findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 375, 768]) {
    testWidgets('Paginación centrada y estable a ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 750);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var previous = 0, next = 0;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        Padding(padding: const EdgeInsets.all(16),
          child: VenciraPaginationBar(
            pageLabel: 'Página 2',
            previousLabel: 'Anterior',
            nextLabel: 'Siguiente',
            onPrevious: () => previous++,
            onNext: () => next++,
          )),
      )));
      await tester.pumpAndSettle();
      final left = tester.getRect(find.byKey(
        const ValueKey('pagination-previous')));
      final right = tester.getRect(find.byKey(
        const ValueKey('pagination-next')));
      final label = tester.getRect(find.text('Página 2'));
      expect(left.top, closeTo(right.top, 0.5));
      expect(left.width, closeTo(right.width, 0.5));
      expect(label.center.dx, closeTo(width / 2, 0.6));
      await tester.tap(find.byKey(const ValueKey('pagination-previous')));
      await tester.tap(find.byKey(const ValueKey('pagination-next')));
      expect(previous, 1);
      expect(next, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
