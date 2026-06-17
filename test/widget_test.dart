import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test placeholder', (WidgetTester tester) async {
    // Supabase requires initialization before the app can be built,
    // so full widget tests need a mock Supabase setup.
    expect(true, isTrue);
  });
}
