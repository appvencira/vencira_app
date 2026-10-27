import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/ui/renewal_attachments_card.dart';

void main() {
  for (final locale in ['es', 'ca']) {
    for (final width in [320.0, 375.0, 768.0]) {
      testWidgets('C-FICHA adjuntos cerrados $locale $width', (tester) async {
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(body: SingleChildScrollView(
            child: VenciraRenewalAttachmentsCard(locale: locale),
          )),
        ));
        expect(find.byKey(const ValueKey('renewal-attachments-locked')), findsOneWidget);
        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
        expect(find.textContaining(locale == 'ca' ? 'desactivades' : 'desactivadas'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
