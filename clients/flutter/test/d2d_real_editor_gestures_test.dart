import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/api/vencira_api.dart';
import 'package:vencira/l10n/app_localizations.dart';
import 'package:vencira/ui/renewal_editor.dart';

/// D2-D: genuine Flutter tester gestures and form validation, no backend,
/// credentials, remote network, or production state.
void main() {
  for (final size in [const Size(390, 844), const Size(1280, 800)]) {
    testWidgets('D2-D new renewal gestures/validation/save $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      VenciraRenewalInput? saved;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(body: Builder(builder: (context) =>
          Center(child: ElevatedButton(
            onPressed: () async {
              saved = await showDialog<VenciraRenewalInput>(
                context: context,
                builder: (_) => const VenciraRenewalEditor(),
              );
            },
            child: const Text('Abrir D2D'),
          )),
        )),
      ));
      await tester.tap(find.text('Abrir D2D'));
      await tester.pumpAndSettle();
      expect(find.byType(VenciraRenewalEditor), findsOneWidget);

      // Missing required fields must NOT close the editor or save.
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.byType(VenciraRenewalEditor), findsOneWidget);
      expect(saved, isNull);

      await tester.ensureVisible(find.byKey(const ValueKey('full-name')));
      await tester.enterText(find.byKey(const ValueKey('full-name')),
          'Persona ficticia D2D');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('renewal-entry')));
      await tester.tap(find.byKey(const ValueKey('renewal-entry')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clientes').last);
      await tester.pumpAndSettle();

      // The Material date picker is exercised by a real tap, rather than
      // injecting a date directly into the widget state.
      final dateTrigger = find.widgetWithText(OutlinedButton, 'Vencimiento:');
      // Labels may contain the initial "No definido" suffix.
      final trigger = dateTrigger.evaluate().isNotEmpty
          ? dateTrigger.first
          : find.byType(OutlinedButton).first;
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      final confirmDate = find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.byType(TextButton),
      ).last;
      await tester.tap(confirmDate);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(const ValueKey('renewal-notes')));
      await tester.enterText(find.byKey(const ValueKey('renewal-notes')),
          'Observacion ficticia D2D');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(saved, isNotNull);
      expect(saved!.fullName, 'Persona ficticia D2D');
      expect(saved!.entry, 'clients');
      expect(saved!.notes, 'Observacion ficticia D2D');
      expect(saved!.expiresOn.year, greaterThanOrEqualTo(2026));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('D2-D edit preserves identity, expiry and persists notes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VenciraRenewalInput? saved;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () async {
            saved = await showDialog<VenciraRenewalInput>(
              context: context,
              builder: (_) => VenciraRenewalEditor(
                existing: VenciraRenewal(
                  id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
                  reference: 'D2D-EDIT',
                  fullName: 'Persona ficticia',
                  notes: 'Antes',
                  entry: 'clients',
                  expiresOn: DateTime(2027, 5, 31),
                  status: 'pending',
                ),
              ),
            );
          },
          child: const Text('Editar D2D'),
        ),
      )),
    ));
    await tester.tap(find.text('Editar D2D'));
    await tester.pumpAndSettle();
    expect(find.byType(VenciraRenewalEditor), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('renewal-notes')));
    await tester.enterText(find.byKey(const ValueKey('renewal-notes')),
        'Despues D2D');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.reference, 'D2D-EDIT');
    expect(saved!.entry, 'clients');
    expect(saved!.expiresOn, DateTime(2027, 5, 31));
    expect(saved!.notes, 'Despues D2D');
    expect(tester.takeException(), isNull);
  });

  testWidgets('D2-D cancel does not produce an update', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    VenciraRenewalInput? saved;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: Builder(builder: (context) =>
        ElevatedButton(
          onPressed: () async {
            saved = await showDialog<VenciraRenewalInput>(
              context: context,
              builder: (_) => const VenciraRenewalEditor(),
            );
          },
          child: const Text('Abrir D2D'),
        ),
      )),
    ));
    await tester.tap(find.text('Abrir D2D'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('full-name')));
    await tester.enterText(find.byKey(const ValueKey('full-name')),
        'Edicion cancelada');
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.byType(VenciraRenewalEditor), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
