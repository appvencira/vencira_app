import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/operational_inbox_screen.dart';

const reminderId = '11111111-1111-4111-8111-111111111111';
const workspace = VenciraWorkspace(
  id: '22222222-2222-4222-8222-222222222222',
  name: 'Pruebas', role: 'owner',
);

VenciraOperationalInbox sampleInbox({
  String state = 'planned', bool controlQuestion = false,
  String? latestControlRepeatOn,
}) => VenciraOperationalInbox.fromJson({
  'day': '2027-03-10', 'scope': 'due', 'count': 1,
  'next': null, 'previous': null,
  'counts': {'overdue': 0, 'today': 1, 'upcoming': 0},
  'results': [{
    'id': reminderId,
    'renewal_id': '33333333-3333-4333-8333-333333333333',
    'reference': 'FICHA-SINTETICA',
    'kind': 'expiry',
    'scheduled_for': '2027-03-10',
    'original_scheduled_for': '2027-03-10',
    'state': state,
    'reason': 'Tarea interna de prueba',
    'control_question': controlQuestion,
    if (latestControlRepeatOn != null)
      'latest_control_repeat_on': latestControlRepeatOn,
    'overdue': false,
    'delivery_status': 'not_implemented',
  }],
});

class FakeInboxApi implements VenciraApi {
  final requests = <Completer<VenciraOperationalInbox>>[];
  int actionCalls = 0;

  @override
  Future<VenciraOperationalInbox> fetchOperationalInbox(
    String workspaceId, DateTime day, {String scope = 'due', int page = 1}) {
    final pending = Completer<VenciraOperationalInbox>();
    requests.add(pending);
    return pending.future;
  }

  @override
  Future<VenciraOperationalReminder> updateOperationalReminder(
    String workspaceId, String renewalId, VenciraOperationalReminder reminder,
    String action, String idempotencyKey, {int? daysLater}) async {
    actionCalls++;
    throw const VenciraApiException(); // Ambiguous server result.
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(FakeInboxApi api) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: VenciraOperationalInboxScreen(api: api, workspace: workspace),
);

Finder get item => find.byKey(ValueKey('inbox-item-$reminderId'));
Finder get actions => find.byKey(ValueKey('inbox-more-$reminderId'));

Future<void> loadFirst(WidgetTester tester, FakeInboxApi api) async {
  await tester.pumpWidget(app(api));
  expect(api.requests.length, 1);
  api.requests.single.complete(sampleInbox());
  await tester.pumpAndSettle();
  expect(item, findsOneWidget);
}

void main() {
  testWidgets('Control past deadline disables both postponement actions',
      (tester) async {
    final api = FakeInboxApi();
    await tester.pumpWidget(app(api));
    api.requests.single.complete(sampleInbox(
      controlQuestion: true, latestControlRepeatOn: '2000-01-01'));
    await tester.pumpAndSettle();

    await tester.tap(actions);
    await tester.pumpAndSettle();
    final tomorrow = tester.widget<InkWell>(find.ancestor(
      of: find.byIcon(Icons.wb_twilight_outlined),
      matching: find.byType(InkWell)).first);
    final anotherDay = tester.widget<InkWell>(find.ancestor(
      of: find.byIcon(Icons.event_outlined).last,
      matching: find.byType(InkWell)).first);
    expect(tomorrow.onTap, isNull);
    expect(anotherDay.onTap, isNull);
    expect(find.text(
      'No se puede aplazar este control antes del límite. Revisa la anotación.'
    ), findsOneWidget);
    expect(api.actionCalls, 0);
  });

  testWidgets('Control calendar stops strictly before cutoff',
      (tester) async {
    final api = FakeInboxApi();
    final today = DateTime.now();
    final last = DateTime(today.year, today.month, today.day + 3);
    final iso = '${last.year.toString().padLeft(4, '0')}-'
      '${last.month.toString().padLeft(2, '0')}-'
      '${last.day.toString().padLeft(2, '0')}';
    await tester.pumpWidget(app(api));
    api.requests.single.complete(sampleInbox(
      controlQuestion: true, latestControlRepeatOn: iso));
    await tester.pumpAndSettle();

    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.event_outlined).last);
    await tester.pumpAndSettle();
    final calendar = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog));
    expect(calendar.lastDate, last);
    expect(calendar.firstDate,
        DateTime(today.year, today.month, today.day + 2));
    expect(api.actionCalls, 0);
  });

  testWidgets('Snoozed item is visibly labeled as postponed',
      (tester) async {
    final api = FakeInboxApi();
    await tester.pumpWidget(app(api));
    api.requests.single.complete(sampleInbox(state: 'snoozed'));
    await tester.pumpAndSettle();
    expect(item, findsOneWidget);
    expect(find.byKey(ValueKey('inbox-state-$reminderId')), findsOneWidget);
    expect(find.text('Aplazado'), findsOneWidget);
    expect(find.text('Tarea interna de prueba'), findsOneWidget);
  });

  testWidgets('Failed refresh hides stale items, retry restores list',
      (tester) async {
    final api = FakeInboxApi();
    await loadFirst(tester, api);

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    expect(api.requests.length, 2);
    expect(item, findsOneWidget); // Kept while refreshing.
    final more = tester.widget<IconButton>(actions);
    expect(more.onPressed, isNull); // No mutations while reloading.

    api.requests[1].completeError(const VenciraApiException());
    await tester.pumpAndSettle();
    expect(item, findsNothing);
    expect(actions, findsNothing);
    expect(find.byKey(const ValueKey('inbox-summary')), findsNothing);

    await tester.tap(find.byType(TextButton).first);
    await tester.pump();
    expect(api.requests.length, 3);
    api.requests[2].complete(sampleInbox());
    await tester.pumpAndSettle();
    expect(item, findsOneWidget);
  });

  testWidgets('Unauthorized refresh removes items and actions',
      (tester) async {
    final api = FakeInboxApi();
    await loadFirst(tester, api);

    await tester.tap(find.byIcon(Icons.refresh).first);
    await tester.pump();
    api.requests[1].completeError(const VenciraUnauthorized());
    await tester.pumpAndSettle();
    expect(item, findsNothing);
    expect(actions, findsNothing);
    expect(api.actionCalls, 0);
  });

  testWidgets('Ambiguous action cannot leave stale actionable record',
      (tester) async {
    final api = FakeInboxApi();
    await loadFirst(tester, api);

    await tester.tap(actions);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check_circle_outline).last);
    await tester.pump();
    expect(api.actionCalls, 1);
    expect(api.requests.length, 2); // Must revalidate after write error.
    api.requests[1].completeError(const VenciraApiException());
    await tester.pumpAndSettle();
    expect(item, findsNothing);
    expect(actions, findsNothing);
    expect(api.actionCalls, 1);
  });
}
