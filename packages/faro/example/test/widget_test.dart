// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:faro_example/main.dart';

void main() {
  testWidgets('Verify MyApp can run', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that MyApp can be built without errors
    // This test passes if the widget builds without throwing any exceptions
    expect(find.byType(MyApp), findsOneWidget);
  });
}
