import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/month_agenda_screen.dart';
import 'package:vencira/ui/vencira_theme.dart';

class _SyntheticCalendarApi extends VenciraApi {
  static const empty = VenciraMonthCounts(pending: 0, contacted: 0);
  static const active = VenciraMonthCounts(pending: 1, contacted: 0);
  static const contacted = VenciraMonthCounts(pending: 0, contacted: 1);

  @override
  Future<VenciraAgendaMonth> fetchAgendaMonth(
    String workspaceId, DateTime month,
  ) async => VenciraAgendaMonth(month: month, days: [
    VenciraMonthDay(
      day: DateTime(2027, 3, 11),
      expiry: active, notice: contacted, reminder: empty,
    ),
    VenciraMonthDay(
      day: DateTime(2027, 3, 12),
      expiry: empty, notice: active, reminder: empty,
    ),
    VenciraMonthDay(
      day: DateTime(2027, 3, 13),
      expiry: empty, notice: empty, reminder: active,
    ),
  ]);

  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => const [];

  @override
  Future<VenciraRenewalPage> fetchRenewals(
    String workspaceId, {
    int page = 1, String search = '', String status = '',
  }) async => throw UnimplementedError();

  @override
  Future<VenciraAgendaDayPage> fetchAgendaDay(
    String workspaceId, DateTime day, {int page = 1},
  }) async => throw UnimplementedError();

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
    String workspaceId, String renewalId,
  ) async => throw UnimplementedError();

  @override
  Future<VenciraHistoryPage> fetchRenewalHistory(
    String workspaceId, String renewalId, {int page = 1},
  }) async => throw UnimplementedError();

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

void main() {
  const workspace = VenciraWorkspace(
    id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    name: 'DEMO', role: 'owner',
  );

  for (final dark in [false, true]) {
    testWidgets(
      'V3 pinta celda completa y mantiene marcas, tema ${dark ? 'oscuro' : 'claro'}',
      (tester) async {
        tester.view.physicalSize = const Size(375, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final theme = dark ? VenciraTheme.dark() : VenciraTheme.light();
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: VenciraMonthAgendaScreen(
            api: _SyntheticCalendarApi(),
            workspace: workspace,
            initialMonth: DateTime(2027, 3),
          ),
        ));
        await tester.pumpAndSettle();

        Color tileColor(String day) {
          final tile = find.byKey(ValueKey('month-day-2027-03-$day'));
          final tileMaterial = find.ancestor(
            of: tile,
            matching: find.byWidgetPredicate((widget) =>
              widget is Material &&
              widget.shape is RoundedRectangleBorder &&
              (widget.shape! as RoundedRectangleBorder).borderRadius ==
                  BorderRadius.circular(13)),
          );
          expect(tileMaterial, findsOneWidget);
          return tester.widget<Material>(tileMaterial).color!;
        }

        final scheme = theme.colorScheme;
        final strength = dark ? 0.36 : 0.20;
        expect(tileColor('11'),
          Color.lerp(scheme.surface, scheme.error, strength));
        expect(tileColor('12'),
          Color.lerp(scheme.surface, scheme.tertiary, strength));
        expect(tileColor('13'),
          Color.lerp(scheme.surface, scheme.primary, strength));

        // Vencimiento y preaviso simultáneos: la celda usa prioridad de
        // vencimiento sin suprimir la marca secundaria ni el estado contactado.
        expect(find.byKey(const ValueKey(
          'month-mark-2027-03-11-expiry-pending')), findsOneWidget);
        expect(find.byKey(const ValueKey(
          'month-mark-2027-03-11-notice-contacted')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
