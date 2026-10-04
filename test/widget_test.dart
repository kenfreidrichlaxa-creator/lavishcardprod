import 'package:flutter_test/flutter_test.dart';
import 'package:lavish_admin/main.dart';

void main() {
  testWidgets('Admin app renders shell', (WidgetTester tester) async {
    await tester.pumpWidget(const LavishAdminApp());
    expect(find.text('Dashboard'), findsWidgets);
  });
}
