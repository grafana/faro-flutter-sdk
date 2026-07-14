import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_widgets_binding_observer.dart';
import 'package:faro/src/integrations/native_integration.dart';
import 'package:faro/src/session/app_lifecycle_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockNativeIntegration extends Mock implements NativeIntegration {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaro mockFaro;
  late MockNativeIntegration mockNativeIntegration;
  late AppLifecycleService lifecycleService;

  setUp(() {
    mockFaro = MockFaro();
    mockNativeIntegration = MockNativeIntegration();
    lifecycleService = AppLifecycleService();
    Faro.instance = mockFaro;

    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
  });

  group('FaroWidgetsBindingObserver:', () {
    test('updates AppLifecycleService on lifecycle change', () {
      final observer = FaroWidgetsBindingObserver(
        appLifecycleService: lifecycleService,
        nativeIntegration: mockNativeIntegration,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(lifecycleService.isInForeground, isFalse);

      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lifecycleService.isInForeground, isTrue);
    });

    test('emits app_lifecycle_changed events', () {
      final observer = FaroWidgetsBindingObserver(
        appLifecycleService: lifecycleService,
        nativeIntegration: mockNativeIntegration,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);

      verify(
        () => mockFaro.pushEvent(
          'app_lifecycle_changed',
          attributes: {'fromState': '', 'toState': 'paused'},
        ),
      ).called(1);
    });
  });
}
