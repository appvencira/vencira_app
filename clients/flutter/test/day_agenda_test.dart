import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/main.dart';
import 'package:vencira/ui/day_agenda_screen.dart';

class DemoAgendaApi implements VenciraApi {
  DemoAgendaApi({this.waitForMarch});

  final Completer<VenciraAgendaDayPage>? waitForMarch;
  final requests = <String>[];
  static const workspaceId = '11111111-1111-4111-8111-111111111111';
  static const workspace = VenciraWorkspace(
    id: workspaceId, name: 'ORGANIZACIÓN FICTICIA', role: 'owner',
  );

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => [workspace];

  @override
  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {int page = 1, String search = '', String status = '',
  }) async => const VenciraRenewalPage(total: 0, items: [], hasNext: false);

  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1,
  }) async {
    expect(workspaceId, DemoAgendaApi.workspaceId);
    final key = '${day.year}-${day.month}-${day.day}:$page';
    requests.add(key);
    if (day.month == 3 && day.day == 31 && waitForMarch != null) {
      return waitForMarch!.future;
    }
    if (day.month == 3 && day.day == 31) {
      return VenciraAgendaDayPage(
        day: DateTime(2027, 3, 31),
        total: 1,
        hasNext: false,
        entries: [
          VenciraAgendaEntry(
            renewal: VenciraRenewal(
              id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
              reference: 'AVISO-FICTICIO-DE-PRUEBA',
              expiresOn: DateTime(2027, 5, 1),
              status: 'pending',
            ),
            events: const [
              VenciraAgendaEvent(
                kind: 'reminder',
                basis: 'notice_deadline',
                candidateId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
              ),
            ],
          ),
        ],
      );
    }
    return VenciraAgendaDayPage(
      day: DateTime(day.year, day.month, day.day),
      total: 0, entries: const [], hasNext: false,
    );
  }

  @override
  Future<VenciraRenewal> createRenewal(
    String workspaceId, VenciraRenewalInput input,
  ) async => throw UnimplementedError();

  @override
  Future<VenciraRenewal> updateRenewal(
    String workspaceId, String renewalId, VenciraRenewalInput input,
  ) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}
}

Widget _screen(
  DemoAgendaApi api, {
  String locale = 'es',
  ThemeMode theme = ThemeMode.light,
}) => MaterialApp(
  locale: Locale(locale),
  theme: ThemeData(useMaterial3: true),
  darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
  themeMode: theme,
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: VenciraDayAgendaScreen(
    api: api,
    workspace: DemoAgendaApi.workspace,
    initialDay: DateTime(2027, 3, 31),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('agenda presenta avisos previstos sin llamarlos entregados',
      (tester) async {
    final api = DemoAgendaApi();
    await tester.pumpWidget(_screen(api));
    await tester.pumpAndSettle();
    expect(find.text('AVISO-FICTICIO-DE-PRUEBA'), findsOneWidget);
    expect(find.text('Aviso previsto · Preaviso'), findsOneWidget);
    expect(find.text('Anotaciones del día: 1'), findsOneWidget);
    expect(api.requests, ['2027-3-31:1']);
  });

  testWidgets('navega entre meses por flechas y tira de semana',
      (tester) async {
    final api = DemoAgendaApi();
    await tester.pumpWidget(_screen(api));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(api.requests.last, '2027-4-1:1');
    expect(find.text('AVISO-FICTICIO-DE-PRUEBA'), findsNothing);
    await tester.tap(find.byTooltip('Día anterior'));
    await tester.pumpAndSettle();
    expect(api.requests.last, '2027-3-31:1');
    expect(find.text('AVISO-FICTICIO-DE-PRUEBA'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('agenda-weekday-0')));
    await tester.pumpAndSettle();
    expect(api.requests.last, '2027-3-29:1');
  });

  testWidgets('respuesta antigua no reemplaza al día nuevo',
      (tester) async {
    final delayed = Completer<VenciraAgendaDayPage>();
    final api = DemoAgendaApi(waitForMarch: delayed);
    await tester.pumpWidget(_screen(api));
    await tester.pump();
    await tester.tap(find.byTooltip('Día siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('No hay vencimientos ni avisos previstos para este día.'),
        findsOneWidget);
    delayed.complete(VenciraAgendaDayPage(
      day: DateTime(2027, 3, 31),
      total: 1,
      hasNext: false,
      entries: [
        VenciraAgendaEntry(
          renewal: VenciraRenewal(
            id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
            reference: 'REFERENCIA-ANTIGUA',
            expiresOn: DateTime(2027, 5, 1),
            status: 'pending',
          ),
          events: const [VenciraAgendaEvent(kind: 'expiry')],
        ),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.text('REFERENCIA-ANTIGUA'), findsNothing);
    expect(api.requests.last, '2027-4-1:1');
  });

  for (final width in <double>[320, 375, 768]) {
    testWidgets('vista diaria CA oscura sin overflow a ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(
        DemoAgendaApi(), locale: 'ca', theme: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Agenda diària'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('se puede abrir desde el panel principal', (tester) async {
    final api = DemoAgendaApi();
    await tester.pumpWidget(VenciraApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda diaria'), findsOneWidget);
    expect(api.requests, isNotEmpty);
  });
}
