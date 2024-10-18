import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';

class Functions {
  void defaultOnError(FlutterErrorDetails details) async {
    return;
  }
}

class MockFunctions extends Mock implements Functions {}
class MockRUMTransport extends Mock implements RUMTransport {}
class MockBatchTransport extends Mock implements BatchTransport {}

void main(){
  group('Flutter Error Integration', (){

    late MockBatchTransport mockBatchTransport;
    late FlutterErrorDetails flutterErrorDetails;
    late MockFunctions mockFunctions;

    setUpAll((){
      registerFallbackValue(FlutterErrorDetails(exception: FlutterError("Fallback Error")));
      registerFallbackValue(RumException("exception", "test exception", {}));
    });
    
    setUp((){
      mockBatchTransport = MockBatchTransport();
      mockFunctions = MockFunctions();
      RumFlutter().batchTransport = mockBatchTransport;
      when(()=> mockBatchTransport.addExceptions(any())).thenAnswer((_) async {});
      flutterErrorDetails = FlutterErrorDetails(exception: FlutterError("Test Error"),stack: StackTrace.fromString("Test Stack Trace"));
    });
    
    tearDown((){});
    
    test("call method should push errors to rum when error occurs ", (){
      FlutterError.onError = null;
      FlutterErrorIntegration().call();
      FlutterError.onError?.call(flutterErrorDetails);
      verify(()=>mockBatchTransport.addExceptions(any())).called(1);
    });

     test('Default error handler executes after Pushing Errors', () {
      FlutterError.onError = mockFunctions.defaultOnError;
      FlutterErrorIntegration().call();

      FlutterError.onError?.call(flutterErrorDetails);
      verify(() => mockBatchTransport.addExceptions(any())).called(1);
      verify(() => mockFunctions.defaultOnError(flutterErrorDetails)).called(1);
    });

    test('Closing Flutter Error Integration sets back the default error handler', () {
      FlutterErrorIntegration flutterErrorIntegration = FlutterErrorIntegration();
      FlutterError.onError = mockFunctions.defaultOnError;
      flutterErrorIntegration.call();
      flutterErrorIntegration.close();
      expect(FlutterError.onError, mockFunctions.defaultOnError);
    });
  });
}
