import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:rum_sdk/rum_native_methods.dart';
import 'package:rum_sdk/src/transport/batch_transport.dart';

import 'package:rum_sdk/rum_sdk.dart';

class MockRUMTransport extends Mock implements RUMTransport {}
class MockBatchTransport extends Mock implements BatchTransport {}
class MockRumNativeMethods extends Mock implements RumNativeMethods {}


void main(){

  group('RUM Flutter initialization', (){

    late MockRUMTransport mockRUMTransport;
    late MockBatchTransport mockBatchTransport;
    late MockRumNativeMethods mockRumNativeMethods;
    setUp(() {
      registerFallbackValue(RumException("test", "something", {"frames":[]}));
      registerFallbackValue(Event("test", attributes: {"test":"test"}));
      registerFallbackValue(RumLog("This is a message"));
      registerFallbackValue(Measurement({"test":123},"test"));
      registerFallbackValue(Payload(Meta()));
      mockRUMTransport = MockRUMTransport();
      mockBatchTransport = MockBatchTransport();
      mockRumNativeMethods = MockRumNativeMethods();
      RumFlutter().transports = [mockRUMTransport];
      RumFlutter().nativeChannel = mockRumNativeMethods;
      RumFlutter().batchTransport = mockBatchTransport;
      when(()=>mockRumNativeMethods.enableCrashReporter(any())).thenAnswer((_) async {});
      when(()=>mockBatchTransport.addExceptions(any())).thenAnswer((_) async {});
      when(()=>mockBatchTransport.addLog(any())).thenAnswer((_) async {});
      when(()=>mockBatchTransport.addEvent(any())).thenAnswer((_) async {});
      when(()=>mockBatchTransport.addMeasurement(any())).thenAnswer((_) async {});
      when(()=>mockRUMTransport.send(any())).thenAnswer((_) async {});
    });
    tearDown(() {});
    test('init called with no error', () async{
      TestWidgetsFlutterBinding.ensureInitialized();
      var rumConfig = RumConfig(
        appName: "TestApp",
        appVersion: "2.0.3",
        appEnv: "Test",
        apiKey: "TestAPIKey",
        anrTracking: true,
        cpuUsageVitals: false,
        memoryUsageVitals: false,
        refreshRateVitals: false,
        fetchVitalsInterval: const Duration(seconds: 30),
      );

      await RumFlutter().init( optionsConfiguration: rumConfig
      );
      expect(RumFlutter().meta.app?.name, rumConfig.appName);
      expect(RumFlutter().meta.app?.version, rumConfig.appVersion);
      expect(RumFlutter().meta.app?.environment, rumConfig.appEnv);
      verify(()=>mockBatchTransport.addEvent(any())).called(1);
    });


    test("set App Meta data",(){
      RumFlutter().setAppMeta(appName: "TestApp", appEnv: "TestEnv", appVersion: "2.0.3");
      expect(RumFlutter().meta.app?.name, "TestApp");
      expect(RumFlutter().meta.app?.environment, "TestEnv");
      expect(RumFlutter().meta.app?.version, "2.0.3");
    });

    test("set user meta data ",(){
      RumFlutter().setUserMeta(userId: "testuserid",userName:"testusername" ,userEmail: "testusermail@example.com");
      expect(RumFlutter().meta.user?.id, "testuserid");
      expect(RumFlutter().meta.user?.username, "testusername");
      expect(RumFlutter().meta.user?.email, "testusermail@example.com");
    });
    test("set view meta data ",(){
      RumFlutter().setViewMeta(name: 'Testview');
      expect(RumFlutter().meta.view?.name, "Testview");
    });

    test("send custom event",(){
      const eventName = "TestEvent";
      const eventAttributes = {"testkey":"testvalue"};
      RumFlutter().pushEvent(eventName, attributes: eventAttributes);
      verify(()=>mockBatchTransport.addEvent(any())).called(1);
    });
    test("send custom log",(){
      const logMessage = "Log Message";
      const logLevel = "info";
      const logContext = {"testkey":"testvalue"};
      const trace =  {"traceId":"testtraceid","spanId":"testspanid"};
      RumFlutter().pushLog(logMessage, level: logLevel, context: logContext, trace: trace);
      verify(()=>mockBatchTransport.addLog(any())).called(1);
    });
    test("send Error Logs",(){
      var flutterErrorDetails = FlutterErrorDetails(exception: FlutterError("Test Error"));
      const errorType = "flutter_error";
      RumFlutter().pushError(type:errorType, value: flutterErrorDetails.exception.toString(), stacktrace: flutterErrorDetails.stack );
      Map<String,dynamic> parsedStackTrace = {};
      if(flutterErrorDetails.stack != null){
        parsedStackTrace = {"frames":RumException.stackTraceParse(flutterErrorDetails.stack!)};
      }
      verify(()=>mockBatchTransport.addExceptions(any())).called(1);
    });
    test("send custom measurement",(){
      const measurementType = "TestMeasurement";
      const measurementValue = {
        "key1":1233,
        "key2":100
      };
      RumFlutter().pushMeasurement(measurementValue, measurementType);
      verify(()=>mockBatchTransport.addMeasurement(any())).called(1);
    });


  });

}