import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_navigation_observer.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaro mockFaro;
  late MockSessionManager mockSessionManager;
  late FaroNavigationObserver observer;
  late Faro originalFaro;

  PageRoute<void> route([String? name]) {
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.meaningful);
  });

  setUp(() {
    originalFaro = Faro();
    mockFaro = MockFaro();
    mockSessionManager = MockSessionManager();
    Faro.instance = mockFaro;
    pod.overrideProvider(sessionManagerProvider, (_) => mockSessionManager);
    observer = FaroNavigationObserver();

    when(() => mockFaro.setViewMeta(name: any(named: 'name'))).thenReturn(null);
    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
  });

  tearDown(() {
    Faro.instance = originalFaro;
    pod.removeOverride(sessionManagerProvider);
  });

  group('FaroNavigationObserver', () {
    test('preserves the current view when pushing an unnamed route', () {
      observer.didPush(route(), route('/home'));

      verifyNever(() => mockFaro.setViewMeta(name: any(named: 'name')));
      verify(
        () => mockFaro.pushEvent(
          'view_changed',
          attributes: {'fromView': '/home', 'toView': null},
        ),
      ).called(1);
    });

    test('sets the previous named view when popping', () {
      observer.didPop(route(), route('/home'));

      verify(() => mockFaro.setViewMeta(name: '/home')).called(1);
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
      verify(
        () => mockFaro.pushEvent(
          'view_changed',
          attributes: {'fromView': null, 'toView': '/home'},
        ),
      ).called(1);
    });

    test('preserves the current view when popping to an unnamed route', () {
      observer.didPop(route('/details'), route());

      verifyNever(() => mockFaro.setViewMeta(name: any(named: 'name')));
      verify(
        () => mockFaro.pushEvent(
          'view_changed',
          attributes: {'fromView': '/details', 'toView': null},
        ),
      ).called(1);
    });

    test('preserves the current view when replacing with an unnamed route', () {
      observer.didReplace(newRoute: route(), oldRoute: route('/home'));

      verifyNever(() => mockFaro.setViewMeta(name: any(named: 'name')));
      verify(
        () => mockFaro.pushEvent(
          'view_changed',
          attributes: {'fromView': '/home', 'toView': null},
        ),
      ).called(1);
    });

    test('refreshes the session without emitting an empty view change', () {
      observer.didReplace(newRoute: route(), oldRoute: route());

      verifyNever(() => mockFaro.setViewMeta(name: any(named: 'name')));
      verifyNever(
        () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
      );
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
    });
  });
}
