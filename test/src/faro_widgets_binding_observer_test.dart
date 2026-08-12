import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeIntegration extends Mock implements NativeIntegration {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.passive);
  });

  late MockFaro mockFaro;
  late MockNativeIntegration mockNativeIntegration;
  late MockSessionManager mockSessionManager;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeIntegration = MockNativeIntegration();
    mockSessionManager = MockSessionManager();
    Faro.instance = mockFaro;

    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
    when(() => mockNativeIntegration.setWarmStart()).thenReturn(null);
    when(() => mockNativeIntegration.getWarmStart()).thenAnswer((_) async {});
    when(
      () => mockSessionManager.checkSession(activity: any(named: 'activity')),
    ).thenReturn(null);
  });

  group('FaroWidgetsBindingObserver:', () {
    test('emits app_lifecycle_changed events', () {
      final observer = FaroWidgetsBindingObserver(
        nativeIntegration: mockNativeIntegration,
        sessionManager: mockSessionManager,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      verify(
        () => mockFaro.pushEvent(
          'app_lifecycle_changed',
          attributes: {'fromState': '', 'toState': 'paused'},
        ),
      ).called(1);
    });

    test('refreshes activity only after a real background return', () {
      final observer = FaroWidgetsBindingObserver(
        nativeIntegration: mockNativeIntegration,
        sessionManager: mockSessionManager,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      verifyNever(
        () => mockSessionManager.checkSession(activity: any(named: 'activity')),
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      verifyNever(
        () => mockSessionManager.checkSession(activity: any(named: 'activity')),
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
    });
  });

  group('FaroWidgetsBindingObserver warm start:', () {
    /// Drives the observer through [states] and flushes the post-frame
    /// callback the warm start measurement is scheduled on.
    Future<void> lifecycle(
      WidgetTester tester,
      List<AppLifecycleState> states,
    ) async {
      final observer = FaroWidgetsBindingObserver(
        nativeIntegration: mockNativeIntegration,
        sessionManager: mockSessionManager,
      );
      await tester.pumpWidget(const SizedBox());
      for (final state in states) {
        observer.didChangeAppLifecycleState(state);
      }
      // A post-frame callback registered outside a frame only runs once a
      // frame is actually scheduled.
      tester.binding.scheduleFrame();
      await tester.pump();
    }

    testWidgets('is not measured for the resume that completes launch', (
      tester,
    ) async {
      // The first callback an app receives can be `resumed`, which only means
      // the launch finished. The cold start already covers that interval.
      await lifecycle(tester, [AppLifecycleState.resumed]);

      verifyNever(() => mockNativeIntegration.getWarmStart());
    });

    testWidgets('is measured when the app returns from the background', (
      tester,
    ) async {
      await lifecycle(tester, [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      verify(() => mockNativeIntegration.getWarmStart()).called(1);
    });

    testWidgets('is not measured for a transient loss of focus', (
      tester,
    ) async {
      // A notification banner or a glance at the app switcher: the app never
      // left the foreground, so there is nothing to warm up from.
      await lifecycle(tester, [
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      verifyNever(() => mockNativeIntegration.getWarmStart());
    });

    testWidgets('is measured once per background cycle', (tester) async {
      await lifecycle(tester, [
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]);

      verify(() => mockNativeIntegration.getWarmStart()).called(1);
    });
  });
}
