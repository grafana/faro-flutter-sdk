import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/flutter_error_integration.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class Functions {
  void defaultOnError(FlutterErrorDetails details) async {
    return;
  }
}

class MockFunctions extends Mock implements Functions {}

class MockFaroTransport extends Mock implements FaroTransport {}

class MockBatchTransport extends Mock implements BatchTransport {}

void main() {
  group('Flutter Error Integration', () {
    late MockBatchTransport mockBatchTransport;
    late FlutterErrorDetails flutterErrorDetails;
    late MockFunctions mockFunctions;

    setUpAll(() {
      registerFallbackValue(
          FlutterErrorDetails(exception: FlutterError('Fallback Error')));
      registerFallbackValue(FaroException('exception', 'test exception', {}));
    });

    setUp(() {
      mockBatchTransport = MockBatchTransport();
      mockFunctions = MockFunctions();
      Faro().batchTransport = mockBatchTransport;
      when(() => mockBatchTransport.addExceptions(any()))
          .thenAnswer((_) async {});
      flutterErrorDetails = FlutterErrorDetails(
          exception: FlutterError('Test Error'),
          stack: StackTrace.fromString('Test Stack Trace'));
    });

    tearDown(() {});

    test('call method should push errors to faro when error occurs ', () {
      FlutterError.onError = null;
      FlutterErrorIntegration().call();
      FlutterError.onError?.call(flutterErrorDetails);
      verify(() => mockBatchTransport.addExceptions(any())).called(1);
    });

    test('Default error handler executes after Pushing Errors', () {
      FlutterError.onError = mockFunctions.defaultOnError;
      FlutterErrorIntegration().call();

      FlutterError.onError?.call(flutterErrorDetails);
      verify(() => mockBatchTransport.addExceptions(any())).called(1);
      verify(() => mockFunctions.defaultOnError(flutterErrorDetails)).called(1);
    });

    test(
        'Closing Flutter Error Integration sets back the default error handler',
        () {
      final flutterErrorIntegration = FlutterErrorIntegration();
      FlutterError.onError = mockFunctions.defaultOnError;
      flutterErrorIntegration.call();
      flutterErrorIntegration.close();
      expect(FlutterError.onError, mockFunctions.defaultOnError);
    });
  });
}
