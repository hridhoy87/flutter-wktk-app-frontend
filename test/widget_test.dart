// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:walkie_talkie/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: This might require mocking repositories in a real scenario
    await tester.pumpWidget(const WalkieTalkieApp());

    // Basic check to see if the app starts
    expect(find.byType(WalkieTalkieApp), findsOneWidget);
  });
}
