import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_navigation_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaro mockFaro;
  late FaroNavigationObserver observer;

  PageRoute<void> route([String? name]) {
    return PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  setUp(() {
    mockFaro = MockFaro();
    Faro.instance = mockFaro;
    observer = FaroNavigationObserver();

    when(() => mockFaro.setViewMeta(name: any(named: 'name'))).thenReturn(null);
    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
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

    test('does not emit a view change when both route names are null', () {
      observer.didReplace(newRoute: route(), oldRoute: route());

      verifyNever(() => mockFaro.setViewMeta(name: any(named: 'name')));
      verifyNever(
        () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
      );
    });
  });
}
