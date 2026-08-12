import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_user_interaction_widget.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaro mockFaro;
  late MockSessionManager mockSessionManager;

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.passive);
  });

  setUp(() {
    mockFaro = MockFaro();
    mockSessionManager = MockSessionManager();
    Faro.instance = mockFaro;
    pod.overrideProvider(sessionManagerProvider, (_) => mockSessionManager);

    when(
      () => mockSessionManager.checkSession(activity: any(named: 'activity')),
    ).thenReturn(null);
    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
  });

  tearDown(() {
    pod.removeOverride(sessionManagerProvider);
  });

  testWidgets('records a recognized tap as meaningful session activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('Pay')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));

    verify(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    ).called(1);
    verify(
      () => mockFaro.pushEvent(
        'user_interaction',
        attributes: any(named: 'attributes'),
      ),
    ).called(1);
  });
}
