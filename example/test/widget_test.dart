// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:faro_example/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('features are grouped into dedicated destinations',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    expect(find.text('Change Route'), findsOneWidget);

    await tester.tap(find.text('Change Route'));
    await tester.pumpAndSettle();

    expect(find.text('Configure SDK'), findsOneWidget);
    expect(find.text('Explore Telemetry'), findsOneWidget);
    expect(find.text('Custom Telemetry'), findsOneWidget);
    expect(find.text('Network Requests'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('App Diagnostics'),
      300,
    );
    await tester.pumpAndSettle();
    expect(find.text('Stress Runtime Behavior'), findsOneWidget);
    expect(find.text('App Diagnostics'), findsOneWidget);
    expect(find.text('Custom Warn Log'), findsNothing);
    expect(find.text('HTTP POST Request - success'), findsNothing);
  });

  testWidgets('custom telemetry page is reachable from the catalog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    await tester.tap(find.text('Change Route'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom Telemetry'));
    await tester.pumpAndSettle();

    expect(find.text('Telemetry Signals'), findsOneWidget);
    expect(find.text('Warn Log'), findsOneWidget);
    expect(find.text('Custom Measurement'), findsOneWidget);
    expect(find.textContaining('Data Collection'), findsOneWidget);
  });
}
