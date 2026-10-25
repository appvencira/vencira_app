import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/operational_history_screen.dart';

class _HistoryApi extends VenciraApi {
  int requests = 0;

  @override
  Future<VenciraOperationalHistory> fetchOperationalHistory(
      String workspaceId, String renewalId, String reminderId,
      {int page = 1}) async {
    requests++;
    if (page == 1) {
      return VenciraOperationalHistory(count: 2, hasNext: true, items: [
        VenciraOperationalEvent(
          id: '11111111-1111-4111-8111-111111111111',
          action: 'tomorrow', previousState: 'planned',
          nextState: 'snoozed',
          scheduledFor: DateTime(2027, 3, 11),
          occurredAt: DateTime.utc(2027, 3, 10, 10, 15),
          actor: 'demo_user'),
      ]);
    }
    return VenciraOperationalHistory(count: 2, hasNext: false, items: [
      VenciraOperationalEvent(
        id: '22222222-2222-4222-8222-222222222222',
        action: 'planned', previousState: '', nextState: 'planned',
        scheduledFor: DateTime(2027, 3, 10),
        occurredAt: DateTime.utc(2027, 3, 1),
        actor: null),
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final example = <String, dynamic>{
    'count': 1, 'next': null, 'previous': null,
    'delivery_status': 'not_implemented',
    'results': [{
      'id': '11111111-1111-4111-8111-111111111111',
      'action': 'tomorrow', 'previous_state': 'planned',
      'next_state': 'snoozed', 'scheduled_for': '2027-03-11',
      'occurred_at': '2027-03-10T10:15:00+00:00', 'actor': 'demo_user'
    }],
  };

  test('historial: acciones, actor y fechas sin entregas simuladas', () {
    final history = VenciraOperationalHistory.fromJson(example);
    expect(history.count, 1);
    expect(history.hasNext, false);
    expect(history.items.single.actor, 'demo_user');
    expect(history.items.single.action, 'tomorrow');
    expect(history.items.single.scheduledFor.day, 11);
    expect(history.items.single.occurredAt.isUtc, true);
  });

  test('historial: no aceptar etiquetas de entrega ni acciones inventadas', () {
    expect(() => VenciraOperationalHistory.fromJson({
      ...example, 'delivery_status': 'delivered'
    }), throwsFormatException);
    expect(() => VenciraOperationalHistory.fromJson({
      ...example, 'results': [{
        ...(example['results'] as List).single as Map<String, dynamic>,
        'action': 'email_delivered'
      }]
    }), throwsFormatException);
    expect(() => VenciraOperationalHistory.fromJson({
      ...example, 'results': [{
        ...(example['results'] as List).single as Map<String, dynamic>,
        'scheduled_for': '2027-02-30'
      }]
    }), throwsFormatException);
  });

  for (final width in <double>[320, 375]) {
    testWidgets('historial UX a ${width.toInt()} px, paginación y tema oscuro',
        (tester) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _HistoryApi();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
        themeMode: ThemeMode.dark,
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: VenciraOperationalHistoryScreen(
          api: api,
          workspaceId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          renewalId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
          reminderId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
          reason: 'Revisar próxima renovación',
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Historial del aviso'), findsOneWidget);
      expect(find.text('Aplazado a mañana'), findsOneWidget);
      expect(find.textContaining('demo_user'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('history-more')));
      await tester.pumpAndSettle();
      expect(api.requests, 2);
      expect(find.text('Aviso programado'), findsOneWidget);
      expect(find.textContaining('Usuario no disponible'), findsOneWidget);
      expect(find.byKey(const ValueKey('history-more')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
