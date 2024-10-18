import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:ui';

class MockPlatformDispatcher extends Mock implements PlatformDispatcher {}

class OnErrorIntegration {
  final PlatformDispatcher platformDispatcher;

  OnErrorIntegration({required this.platformDispatcher});

  bool isOnErrorSupported() {
    try {
      platformDispatcher.onError;
      return true;
    } catch (e) {
      return false;
    }
  }
}

void main() {
  late OnErrorIntegration onErrorIntegration;
  late MockPlatformDispatcher mockPlatformDispatcher;

  setUp(() {
    mockPlatformDispatcher = MockPlatformDispatcher();
    onErrorIntegration = OnErrorIntegration(platformDispatcher: mockPlatformDispatcher);
  });

  test('call method sets up error integration correctly', () {
    when(() => mockPlatformDispatcher.onError).thenReturn((_, __) => true);

    final result = onErrorIntegration.isOnErrorSupported();

    expect(result, true);
  });

  test('isOnErrorSupported returns false when onError is not supported', () {
    when(() => mockPlatformDispatcher.onError).thenThrow(NoSuchMethodError.withInvocation(
      mockPlatformDispatcher,
      Invocation.getter(#onError),
    ));

    final result = onErrorIntegration.isOnErrorSupported();

    expect(result, false);
  });

  test('isOnErrorSupported returns false when onError throws an exception', () {
    when(() => mockPlatformDispatcher.onError).thenThrow(Exception());

    final result = onErrorIntegration.isOnErrorSupported();

    expect(result, false);
  });

  test('isOnErrorSupported returns true when onError is supported', () {
    when(() => mockPlatformDispatcher.onError).thenReturn((_, __) => true);

    final result = onErrorIntegration.isOnErrorSupported();

    expect(result, true);
  });
}
