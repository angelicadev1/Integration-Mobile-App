import 'package:flutter_test/flutter_test.dart';
import 'package:frontend_mobile/main.dart';

void main() {
  testWidgets('CapstoneBankingApp smoke test - verifies Login screen loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CapstoneBankingApp());
    await tester.pumpAndSettle();

    // Verify that the title and login fields exist
    expect(find.text('CAPSTONE LEDGER'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('ONE-CLICK DEMO PERSONAS'), findsOneWidget);
  });
}
