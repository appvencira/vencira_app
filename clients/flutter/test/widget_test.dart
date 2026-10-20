import 'package:flutter_test/flutter_test.dart';
import 'package:vencira/main.dart';

void main() {
  testWidgets('identidad y estado vacío', (tester) async {
    await tester.pumpWidget(const VenciraApp());
    expect(find.text('VENCIRA'), findsOneWidget);
    expect(find.textContaining('Aún no hay vencimientos'), findsOneWidget);
  });
}
