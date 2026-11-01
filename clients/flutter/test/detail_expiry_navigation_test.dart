import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_detail_screen.dart';

const workspace = VenciraWorkspace(
  id: '11111111-1111-4111-8111-111111111111',
  name: 'Workspace de prueba',
  role: 'owner',
);

class ExpiredDetailApi implements VenciraApi {
  @override
  Future<VenciraRenewal> fetchRenewalDetail(
      String workspaceId, String renewalId) async {
    throw const VenciraUnauthorized();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Revoked detail notifies parent then dismisses secondary route',
      (tester) async {
    var expired = 0;
    final api = ExpiredDetailApi();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: Builder(builder: (context) => Scaffold(
        body: FilledButton(
          key: const ValueKey('open-expired-detail'),
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => VenciraRenewalDetailScreen(
                api: api,
                workspace: workspace,
                renewalId: '22222222-2222-4222-8222-222222222222',
                onSessionExpired: () async { expired++; },
              ),
            ));
          },
          child: const Text('Panel principal'),
        ),
      )),
    ));
    await tester.tap(find.byKey(const ValueKey('open-expired-detail')));
    await tester.pumpAndSettle();
    expect(expired, 1);
    expect(find.text('Panel principal'), findsOneWidget);
    expect(find.byType(VenciraRenewalDetailScreen), findsNothing);
  });
}
