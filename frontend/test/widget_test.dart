import 'package:flutter_test/flutter_test.dart';
import 'package:phtoo/main.dart';

void main() {
  testWidgets('Login screen loads correctly', (WidgetTester tester) async {
    // Build the real app
    await tester.pumpWidget(const PhotoSelectorApp());

    // Verify login screen UI appears
    expect(find.text("AI Photo Selector"), findsOneWidget);
    expect(find.text("LOGIN"), findsOneWidget);
  });
}
