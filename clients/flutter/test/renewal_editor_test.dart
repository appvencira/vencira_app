import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_editor.dart';

void main() {
  for (final language in ['es', 'ca']) {
    testWidgets('Entrada obligatoria visible y Modalidad editable en $language',
        (tester) async {
      tester.view.physicalSize = const Size(375, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      VenciraRenewalInput? saved;
      await tester.pumpWidget(MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Builder(builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                saved = await showDialog<VenciraRenewalInput>(
                  context: context,
                  builder: (_) => VenciraRenewalEditor(
                    existing: VenciraRenewal(
                      id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
                      reference: 'TEST-EXTERNA-001',
                      expiresOn: DateTime(2027, 5, 31),
                      status: 'pending',
                    ),
                  ),
                );
              },
              child: const Text('Abrir editor'),
            ),
          )),
        ),
      ));
      await tester.tap(find.text('Abrir editor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('renewal-entry')), findsOneWidget);
      expect(find.byKey(const ValueKey('renewal-modality')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('renewal-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'es' ? 'Candidatos' : 'Candidats').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('renewal-modality')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'es' ? 'Hogar' : 'Llar').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(language == 'es' ? 'Guardar' : 'Desar'));
      await tester.pumpAndSettle();
      expect(saved?.entry, 'prospects');
      expect(saved?.modality, 'hogar');
      expect(saved?.reference, 'TEST-EXTERNA-001');
      expect(saved?.expiresOn, DateTime(2027, 5, 31));
      expect(tester.takeException(), isNull);
    });
  }
}
