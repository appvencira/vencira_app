import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/ui/android_web_access_screen.dart';

void main() {
  testWidgets('Android access remains fail-closed without native auth',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: AndroidWebAccessScreen(),
    ));
    expect(find.text('Acceso seguro a VENCIRA'), findsOneWidget);
    expect(find.text('Abrir VENCIRA en el navegador'), findsOneWidget);
    expect(find.textContaining('aún no admite inicio de sesión seguro'),
        findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(AndroidWebAccessScreen.previewUri.scheme, 'https');
    expect(AndroidWebAccessScreen.previewUri.host, 'dev.vencira.es');
  });
}
