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
  late Faro originalFaro;

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.passive);
  });

  setUp(() {
    originalFaro = Faro();
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
    Faro.instance = originalFaro;
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

  testWidgets(
    'records an unsupported tap without emitting an interaction event',
    (tester) async {
      const targetKey = Key('unsupported-tap-target');
      await tester.pumpWidget(
        FaroUserInteractionWidget(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GestureDetector(
                  key: targetKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(targetKey));

      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
      verifyNever(
        () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
      );
    },
  );

  testWidgets('records a drag without emitting a tap event', (tester) async {
    const targetKey = Key('drag-target');
    await tester.pumpWidget(
      FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                key: targetKey,
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (_) {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(targetKey), const Offset(0, -40));

    verify(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    ).called(1);
    verifyNever(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    );
  });

  testWidgets('does not record a cancelled pointer sequence', (tester) async {
    const targetKey = Key('cancel-target');
    await tester.pumpWidget(
      const FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Listener(
                key: targetKey,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await gesture.cancel();

    verifyNever(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    );
    verifyNever(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    );
  });
}
