import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/operational_inbox_screen.dart';

class _InboxApi extends VenciraApi {
  String? lastAction;
  String? lastScope;
  int requests = 0;

  @override
  Future<VenciraOperationalInbox> fetchOperationalInbox(
      String workspaceId, DateTime day, {String scope = 'due', int page = 1}) async {
    lastScope = scope;
    requests++;
    return VenciraOperationalInbox(
      day: day, scope: scope, overdue: 0, today: 1, upcoming: 0,
      hasNext: false,
      items: [
        VenciraInboxItem(
          renewalId: '22222222-2222-4222-8222-222222222222',
          reference: 'DEMO-AVISO-001',
          overdue: false,
          reminder: VenciraOperationalReminder(
            id: '11111111-1111-4111-8111-111111111111',
            state: 'planned', day: day,
            reason: 'Comprobar la renovación de la póliza',
            controlQuestion: false),
        ),
      ],
    );
  }

  @override
  Future<VenciraOperationalReminder> updateOperationalReminder(
      String workspaceId, String renewalId,
      VenciraOperationalReminder reminder, String action,
      String idempotencyKey, {int? daysLater}) async {
    lastAction = action;
    return VenciraOperationalReminder(
      id: reminder.id, state: 'snoozed',
      day: reminder.day, reason: reminder.reason,
      controlQuestion: reminder.controlQuestion);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const workspace = VenciraWorkspace(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    name: 'Demo', role: 'owner');

  Future<void> mount(WidgetTester tester, _InboxApi api) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: VenciraOperationalInboxScreen(api: api, workspace: workspace),
    ));
    await tester.pumpAndSettle();
  }

  for (final width in <double>[320, 375, 768]) {
    testWidgets('B premium: tarjeta sin botonera ni overflow a ${width.toInt()}px',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _InboxApi();
      await mount(tester, api);
      expect(find.text('DEMO-AVISO-001'), findsOneWidget);
      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byKey(const ValueKey(
          'inbox-more-11111111-1111-4111-8111-111111111111')), findsOneWidget);
      expect(find.text('Ver anotación'), findsNothing);
      expect(find.text('Completada'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('B premium: acciones en sheet y aplazamiento preservado',
      (tester) async {
    final api = _InboxApi();
    await mount(tester, api);
    await tester.tap(find.byKey(const ValueKey(
        'inbox-more-11111111-1111-4111-8111-111111111111')));
    await tester.pumpAndSettle();
    expect(find.text('Acciones del aviso'), findsOneWidget);
    expect(find.text('Ver anotación'), findsOneWidget);
    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Mañana'), findsOneWidget);
    expect(find.text('Elegir fecha'), findsOneWidget);
    await tester.tap(find.text('Mañana'));
    await tester.pumpAndSettle();
    expect(api.lastAction, 'tomorrow');
    expect(api.requests, greaterThan(1));
    expect(tester.takeException(), isNull);
  });
}
