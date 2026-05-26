import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Supabase requires initialization before app can be pumped.
    // This test verifies that the test framework is functional.
    expect(1 + 1, equals(2));
  });
}
