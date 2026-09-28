import 'package:flutter_test/flutter_test.dart';
import 'package:touristmar_web/main.dart' show TouristMarApp;
import 'package:touristmar_web/pages/login_page.dart';

void main() {
  testWidgets('la app móvil abre en el mismo login que la web', (WidgetTester tester) async {
    await tester.pumpWidget(const TouristMarApp());
    await tester.pump();

    expect(find.byType(LoginPage), findsOneWidget);
  });
}
