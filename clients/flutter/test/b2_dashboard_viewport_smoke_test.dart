import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/main.dart';
import 'package:vencira/ui/dashboard_screen.dart';

/// B2 isolated UI smoke. No HTTP client or credentials are ever constructed.
/// Missing API operations fail closed rather than silently simulating success.
class _EmptyWorkspaceApi implements VenciraApi {
  @override
  Future<List<VenciraWorkspace>> fetchWorkspaces() async => <VenciraWorkspace>[];

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
}
