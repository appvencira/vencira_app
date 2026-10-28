import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/main.dart';
import 'package:vencira/ui/day_agenda_screen.dart';

class DemoAgendaApi extends VenciraApi {
  DemoAgendaApi({this.waitForMarch});

  final Completer<VenciraAgendaDayPage>? waitForMarch;
  final requests = <String>[];
  final monthRequests = <String>[];
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
  Future<VenciraAgendaMonth> fetchAgendaMonth(
      String workspaceId, DateTime month) async {
    expect(workspaceId, DemoAgendaApi.workspaceId);
    monthRequests.add('${month.year}-${month.month}');
    return VenciraAgendaMonth(
      month: DateTime(month.year, month.month, 1),
      days: month.month == 3 ? [
        VenciraMonthDay(
          day: DateTime(2027, 3, 31),
          expiry: const VenciraMonthCounts(pending: 1, contacted: 0),
          notice: const VenciraMonthCounts(pending: 0, contacted: 0),
          reminder: const VenciraMonthCounts(pending: 0, contacted: 1),
        ),
      ] : month.month == 4 ? [
        VenciraMonthDay(
          day: DateTime(2027, 4, 1),
          expiry: const VenciraMonthCounts(pending: 0, contacted: 0),
          notice: const VenciraMonthCounts(pending: 1, contacted: 0),
          reminder: const VenciraMonthCounts(pending: 0, contacted: 0),
        ),
      ] : const [],
    );
  }

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
    if (day.month == 4 && day.day == 20) {
      return VenciraAgendaDayPage(
        day: DateTime(2027, 4, 20),
        total: 1,
        hasNext: false,
        entries: [
          VenciraAgendaEntry(
            renewal: VenciraRenewal(
              id: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
              reference: 'PREAVISO-CONTRACTUAL',
              expiresOn: DateTime(2027, 5, 1),
              noticeDeadlineOn: DateTime(2027, 4, 20),
              status: 'pending',
            ),
            events: const [
              VenciraAgendaEvent(kind: 'notice_deadline'),
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
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async =>
      VenciraRenewal(
        id: renewalId, reference: 'AVISO-FICTICIO-DE-PRUEBA',
        expiresOn: DateTime(2027, 5, 1), status: 'pending');

  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
      String workspaceId, String renewalId, {int page = 1}) async =>
      VenciraHistoryPage(total: 1, hasNext: false,
        events: [
          VenciraHistoryEvent(action: 'created',
            timestamp: DateTime.utc(2027, 3, 1, 10),
            actor: 'usuario-demo', fields: const ['expires_on'],
            metadata: const {}),
        ]);

  @override
  Future<void> logout() async {}
}

Widget _screen(
  DemoAgendaApi api, {
  String locale = 'es',
  ThemeMode theme = ThemeMode.light,
  DateTime? initialDay,
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
    initialDay: initialDay ?? DateTime(2027, 3, 31),
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

  for (final locale in <String>['es', 'ca']) {
    testWidgets('preaviso contractual sin avisos se ve con fecha en $locale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = DemoAgendaApi();
      await tester.pumpWidget(_screen(
        api, locale: locale, initialDay: DateTime(2027, 4, 20),
      ));
      await tester.pumpAndSettle();
      expect(find.text('PREAVISO-CONTRACTUAL'), findsOneWidget);
      expect(find.text(locale == 'es'
          ? 'Límite contractual de preaviso'
          : 'Límit contractual de preavís'), findsOneWidget);
      expect(find.text(locale == 'es'
          ? 'Límite de preaviso: 20/04/2027'
          : 'Límit de preavís: 20/04/2027'), findsOneWidget);
      expect(find.text(locale == 'es'
          ? 'Vence el 01/05/2027'
          : 'Venç el 01/05/2027'), findsOneWidget);
      expect(find.text(locale == 'es'
          ? 'Aviso previsto · Preaviso'
          : 'Avís previst · Preavís'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('al tocar anotación abre ficha, y no historial en móvil',
      (tester) async {
    tester.view.physicalSize = const Size(375, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = DemoAgendaApi();
    await tester.pumpWidget(_screen(api));
    await tester.pumpAndSettle();
    const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final annotation = find.byKey(const ValueKey('agenda-annotation-' + id));
    await tester.ensureVisible(annotation);
    await tester.tap(annotation);
    await tester.pumpAndSettle();
    expect(find.text('Ficha de anotación'), findsOneWidget);
    expect(find.text('AVISO-FICTICIO-DE-PRUEBA'), findsOneWidget);
    expect(find.text('Consultar historial'), findsNothing);
  });

  testWidgets('historial se consulta solo en vista de escritorio web',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_screen(DemoAgendaApi()));
    await tester.pumpAndSettle();
    const id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
    final annotation = find.byKey(const ValueKey('agenda-annotation-' + id));
    await tester.ensureVisible(annotation);
    await tester.tap(annotation);
    await tester.pumpAndSettle();
    expect(find.text('Ficha de anotación'), findsOneWidget);
    // En test Flutter no web, kIsWeb es false: no se publican datos de
    // historial en aplicaciones nativas aunque tengan pantalla grande.
    expect(find.text('Consultar historial'), findsNothing);
  });

  for (final width in <double>[320, 375, 768]) {
    for (final locale in <String>['es', 'ca']) {
      testWidgets('siete días alineados con y sin marcas a $width px en $locale',
          (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = DemoAgendaApi();
        await tester.pumpWidget(_screen(
          api, locale: locale,
          theme: locale == 'ca' ? ThemeMode.dark : ThemeMode.light,
        ));
        await tester.pumpAndSettle();
        final heights = <double>[];
        for (var i = 0; i < 7; i++) {
          final slot = find.byKey(ValueKey('agenda-week-slot-$i'));
          final day = find.byKey(ValueKey('agenda-weekday-$i'));
          expect(slot, findsOneWidget);
          expect(tester.getSize(slot).height, 32);
          heights.add(tester.getSize(day).height);
        }
        for (final height in heights) {
          expect(height, closeTo(heights.first, 0.1));
        }
        // Dos clases de evento, y un día sin actividad: misma altura.
        expect(find.byKey(
          const ValueKey('week-mark-2027-03-31-expiry-pending')),
          findsOneWidget);
        expect(find.byKey(
          const ValueKey('week-mark-2027-04-01-notice-pending')),
          findsOneWidget);
        expect(find.byKey(
          const ValueKey('week-mark-2027-04-02-expiry-pending')),
          findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('la franja semanal comparte marcas con mes aunque cruce dos meses',
      (tester) async {
    final api = DemoAgendaApi();
    await tester.pumpWidget(_screen(api));
    await tester.pumpAndSettle();
    expect(api.monthRequests, ['2027-3', '2027-4']);
    expect(find.byKey(const ValueKey('week-mark-2027-03-31-expiry-pending')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-mark-2027-03-31-reminder-contacted')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-mark-2027-04-01-notice-pending')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('week-mark-2027-04-02-expiry-pending')),
        findsNothing);

    // Cambiar de día en la misma semana no dispara otras consultas mensuales.
    await tester.tap(find.byKey(const ValueKey('agenda-weekday-3')));
    await tester.pumpAndSettle();
    expect(api.requests.last, '2027-4-1:1');
    expect(api.monthRequests, ['2027-3', '2027-4']);
    expect(find.byKey(const ValueKey('week-mark-2027-03-31-expiry-pending')),
        findsOneWidget);

    // Al entrar en otra semana no sobreviven marcadores antiguos.
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Día siguiente'));
      await tester.pumpAndSettle();
    }
    expect(api.requests.last, '2027-4-5:1');
    expect(api.monthRequests.last, '2027-4');
    expect(find.byKey(const ValueKey('week-mark-2027-03-31-expiry-pending')),
        findsNothing);
    expect(find.byKey(const ValueKey('week-mark-2027-04-01-notice-pending')),
        findsNothing);

    final before = api.monthRequests.length;
    await tester.tap(find.byTooltip('Actualizar'));
    await tester.pumpAndSettle();
    expect(api.monthRequests.length, before + 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in <double>[320, 375, 768]) {
    testWidgets('marcas semanales caben en móvil CA oscuro a ${width.toInt()} px',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(
        DemoAgendaApi(), locale: 'ca', theme: ThemeMode.dark,
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('week-mark-2027-04-01-notice-pending')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

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
    expect(find.text('No hay vencimientos, preavisos ni avisos previstos para este día.'),
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

  testWidgets('abre el mes, distingue estados y vuelve al día seleccionado',
      (tester) async {
    final api = DemoAgendaApi();
    await tester.pumpWidget(_screen(api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver mes'));
    await tester.pumpAndSettle();
    expect(find.text('Calendario mensual'), findsOneWidget);
    // La semana inicial ya consultó marzo y abril por cruzar el mes.
    expect(api.monthRequests, ['2027-3', '2027-4', '2027-3']);
    expect(find.byKey(const ValueKey('month-mark-2027-03-31-expiry-pending')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('month-mark-2027-03-31-reminder-contacted')),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('month-next')));
    await tester.pumpAndSettle();
    expect(api.monthRequests.last, '2027-4');
    await tester.tap(find.byKey(const ValueKey('month-previous')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('month-day-2027-03-31')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('month-day-2027-03-31')));
    await tester.pumpAndSettle();
    expect(find.text('Agenda diaria'), findsOneWidget);
    expect(api.requests.last, '2027-3-31:1');
  });

  for (final width in <double>[320, 375, 768]) {
    testWidgets('calendario mensual catalán oscuro sin overflow a $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_screen(DemoAgendaApi(),
          locale: 'ca', theme: ThemeMode.dark));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Veure mes'));
      await tester.pumpAndSettle();
      expect(find.text('Calendari mensual'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView).last, const Offset(0, -350));
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
