import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/day_agenda_screen.dart';

const workspace = VenciraWorkspace(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Equipo de prueba', role: 'owner',
);

class FakeTodayApi implements VenciraApi {
  final requested = <Completer<VenciraOperationalInbox>>[];
  @override
  Future<VenciraOperationalInbox> fetchOperationalInbox(
      String id, DateTime day, {String scope = 'due', int page = 1}) {
    expect(id, workspace.id);
    expect(scope, 'due');
    requested.add(Completer<VenciraOperationalInbox>());
    return requested.last.future;
  }

  @override
  Future<VenciraAgendaDayPage> fetchFilteredAgendaDay(
    String id, DateTime day, {int page = 1, String entry = '',
    String modality = '', String insurer = ''}) async {
    // The agenda error is independent of the authorized inbox count.
    throw const VenciraApiException();
  }

  @override
  Future<VenciraAgendaMonth> fetchFilteredAgendaMonth(String id,
    DateTime month, {String entry = '', String modality = '',
    String insurer = ''}) async {
    throw const VenciraApiException();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

VenciraOperationalInbox fakeInbox({int overdue = 2, int today = 1}) {
  final now = DateTime.now();
  final day = '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
  return VenciraOperationalInbox.fromJson({
    'day': day, 'scope': 'due', 'count': overdue + today,
    'next': null, 'previous': null,
    'counts': {'overdue': overdue, 'today': today, 'upcoming': 0},
    'results': <Map<String, dynamic>>[],
  });
}

Widget app(FakeTodayApi api) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  home: VenciraDayAgendaScreen(api: api, workspace: workspace),
);

void main() {
  testWidgets('Today shows authorized due count from operational inbox',
      (tester) async {
    final api = FakeTodayApi();
    await tester.pumpWidget(app(api));
    expect(api.requested.length, 1);
    api.requested.single.complete(fakeInbox(overdue: 2, today: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-today-inbox-shortcut')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('agenda-due-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('Toda la cuenta'), findsOneWidget);
  });

  testWidgets('Failed inbox never displays guessed counts; retry recovers',
      (tester) async {
    final api = FakeTodayApi();
    await tester.pumpWidget(app(api));
    api.requested.single.completeError(const VenciraApiException());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-due-count')), findsNothing);
    expect(find.textContaining('No se pudo consultar la bandeja'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agenda-inbox-open')));
    await tester.pump();
    expect(api.requested.length, 2);
    api.requested.last.complete(fakeInbox(overdue: 1, today: 0));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(
      find.byKey(const ValueKey('agenda-due-count'))).data, '1');
  });

  testWidgets('Late inbox reply cannot display count for another day',
      (tester) async {
    final api = FakeTodayApi();
    await tester.pumpWidget(app(api));
    expect(api.requested.length, 1);
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pump();
    api.requested.single.complete(fakeInbox(overdue: 4, today: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('agenda-today-inbox-shortcut')),
        findsNothing);
    expect(find.byKey(const ValueKey('agenda-due-count')), findsNothing);
  });
}
