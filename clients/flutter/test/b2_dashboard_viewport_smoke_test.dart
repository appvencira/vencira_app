import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/main.dart';
import 'package:vencira/ui/dashboard_screen.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';

/// B2 isolated UI smoke. No HTTP client or credentials are ever constructed.
/// Missing API operations fail closed rather than silently simulating success.
class _EmptyWorkspaceApi implements VenciraApi {
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => <VenciraWorkspace>[];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('B2 UI smoke: API operation disabled');
}

/// Simulates an unavailable backend without constructing an HTTP client.
class _UnavailableWorkspaceApi implements VenciraApi {
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async =>
      throw const VenciraApiException();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('B2 UI smoke: API operation disabled');
}

/// Non-identifying fixture that exercises a real workspace and one renewal.
class _SyntheticWorkspaceApi extends VenciraApi {
  int renewalRequests = 0;
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async =>
      const <VenciraWorkspace>[
        VenciraWorkspace(id: 'fixture-ws', name: 'Espacio de prueba',
            role: 'owner'),
      ];

  @override
  Future<VenciraRenewalPage> fetchRenewals(
      String workspaceId, {int page = 1, String search = '',
      String status = ''}) async {
    renewalRequests++;
    if (workspaceId != 'fixture-ws') {
      throw const VenciraApiException();
    }
    return VenciraRenewalPage(
      total: 1,
      hasNext: false,
      items: <VenciraRenewal>[
        VenciraRenewal(
          id: 'fixture-renewal',
          reference: 'REF-DEMO-001',
          fullName: 'Caso sintético',
          expiresOn: DateTime(2027, 3, 15),
          status: 'pending',
          modality: 'auto',
        ),
      ],
    );
  }

  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async {
    if (workspaceId != 'fixture-ws' || renewalId != 'fixture-renewal') {
      throw const VenciraApiException();
    }
    return VenciraRenewal(
      id: 'fixture-renewal',
      reference: 'REF-DEMO-001',
      fullName: 'Caso sintético',
      expiresOn: DateTime(2027, 3, 15),
      status: 'pending',
      modality: 'auto',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('B2 UI smoke: API operation disabled');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final width in <double>[320, 390]) {
    testWidgets('B2 dashboard empty state renders at ${width.toInt()}px',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(VenciraApp(api: _EmptyWorkspaceApi()));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(VenciraDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  for (final width in <double>[320, 390]) {
    testWidgets('B2 dashboard unavailable backend at ${width.toInt()}px',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(VenciraApp(api: _UnavailableWorkspaceApi()));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(VenciraDashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in <double>[320, 390]) {
    testWidgets('B2 synthetic workspace and renewal at ${width.toInt()}px',
        (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(width, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final api = _SyntheticWorkspaceApi();
      await tester.pumpWidget(VenciraApp(api: api));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(find.byType(VenciraDashboardScreen), findsOneWidget);
      expect(api.renewalRequests, greaterThan(0));
      // The dashboard uses a lazy-scrolling ListView. On narrow viewports
      // the renewal card is below the filters and does not exist in the
      // element tree until it enters the visible viewport.
      await tester.scrollUntilVisible(
        find.text('Caso sintético'),
        220,
        scrollable: find.descendant(
          of: find.byType(VenciraDashboardScreen),
          matching: find.byType(Scrollable),
        ).first,
        maxScrolls: 25,
      );
      expect(find.text('Caso sintético'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('B2 synthetic renewal opens details and returns', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final api = _SyntheticWorkspaceApi();
    await tester.pumpWidget(VenciraApp(api: api));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Caso sintético'),
      220,
      scrollable: find.descendant(
        of: find.byType(VenciraDashboardScreen),
        matching: find.byType(Scrollable),
      ).first,
      maxScrolls: 25,
    );
    await tester.tap(find.text('Caso sintético'));
    await tester.pumpAndSettle();
    expect(find.byType(VenciraRenewalDetailScreen), findsOneWidget);
    expect(find.text('REF-DEMO-001'), findsWidgets);
    expect(tester.takeException(), isNull);

    // pageBack() only locates Cupertino back buttons. VENCIRA uses Material
    // routes, so pop the actual Navigator instead of assuming an iOS control.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(VenciraRenewalDetailScreen), findsNothing);
    expect(find.byType(VenciraDashboardScreen), findsOneWidget);
    expect(api.renewalRequests, greaterThan(1));
    expect(tester.takeException(), isNull);
  });

}
