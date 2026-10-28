import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/ui/vencira_select.dart';
import 'package:vencira/ui/vencira_theme.dart';

void main() {
  for (final dark in [false, true]) {
    for (final width in <double>[320, 375]) {
      testWidgets(
        'V3.1 selector accesible y desplazable a $width, dark=$dark',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          var selected = 'pending';
          await tester.pumpWidget(MaterialApp(
            theme: dark ? VenciraTheme.dark() : VenciraTheme.light(),
            home: Scaffold(body: Padding(
              padding: const EdgeInsets.all(16),
              child: StatefulBuilder(builder: (context, setState) {
                return VenciraSelect<String>(
                  key: const ValueKey('premium-select-test'),
                  label: 'Estado',
                  value: selected,
                  options: const [
                    VenciraOption(value: 'pending', label: 'Pendiente'),
                    VenciraOption(value: 'contacted', label: 'Contactado'),
                    VenciraOption(value: 'closed', label: 'Cerrado'),
                  ],
                  onChanged: (choice) => setState(() => selected = choice),
                );
              }),
            )),
          ));

          await tester.tap(find.byKey(const ValueKey('premium-select-test')));
          await tester.pumpAndSettle();
          expect(find.text('Contactado'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.text('Contactado'));
          await tester.pumpAndSettle();
          expect(selected, 'contacted');
          expect(find.text('Contactado'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('V3.1 estado pendiente, contactado y cerrado tienen tintes distintos',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: VenciraTheme.light(),
      home: const Scaffold(body: Column(children: [
        VenciraStatusBadge(status: 'pending', label: 'Pendiente'),
        VenciraStatusBadge(status: 'contacted', label: 'Contactado'),
        VenciraStatusBadge(status: 'closed', label: 'Cerrado'),
      ])),
    ));
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Contactado'), findsOneWidget);
    expect(find.text('Cerrado'), findsOneWidget);

    final colors = <Color>[];
    for (final state in ['pending', 'contacted', 'closed']) {
      final badge = find.byWidgetPredicate((widget) =>
        widget is VenciraStatusBadge && widget.status == state);
      final container = find.descendant(
        of: badge, matching: find.byType(Container),
      ).first;
      final decoration = tester.widget<Container>(container).decoration
          as BoxDecoration;
      colors.add(decoration.color!);
    }
    expect(colors.toSet().length, 3);
    expect(tester.takeException(), isNull);
  });
  testWidgets('V3.1 insignia larga se contrae sin overflow en una tarjeta estrecha',
      (tester) async {
    tester.view.physicalSize = const Size(320, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      theme: VenciraTheme.dark(),
      home: const Scaffold(body: Center(
        child: SizedBox(width: 94, child: VenciraStatusBadge(
          status: 'contacted',
          label: 'Contactado / contactat',
        )),
      )),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(VenciraStatusBadge), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
