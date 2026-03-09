import 'dart:async';
import 'dart:io';

import 'package:faro/src/integrations/http_tracking_client.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements HttpClient {}

class MockHttpClientRequest extends Mock implements HttpClientRequest {}

class MockHttpClientResponse extends Mock implements HttpClientResponse {}

class MockHttpHeaders extends Mock implements HttpHeaders {}

class MockSpan extends Mock implements Span {}

void main() {
  group('FaroHttpTrackingClient:', () {
    late MockHttpClient mockHttpClient;
    late HttpTrackingFilter trackingFilter;
    late FaroHttpTrackingClient client;
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpHeaders mockRequestHeaders;

    setUp(() {
      mockHttpClient = MockHttpClient();
      trackingFilter = HttpTrackingFilter();
      mockHttpClientRequest = MockHttpClientRequest();
      mockRequestHeaders = MockHttpHeaders();

      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockRequestHeaders.add(any(), any())).thenReturn(null);

      client = FaroHttpTrackingClient(
        mockHttpClient,
        trackingFilter: trackingFilter,
      );
    });

    test('should bypass tracking when filter rejects URL', () async {
      trackingFilter.configure(
        collectorUrl: 'http://example.com/path',
        ignoreUrls: null,
      );

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);

      expect(request, same(mockHttpClientRequest));
      verify(() => mockHttpClient.openUrl('GET', url)).called(1);
    });

    test('should wrap request when tracked', () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenAnswer((_) async => mockHttpClientRequest);

      final request = await client.openUrl('GET', url);
      await Future<void>.delayed(Duration.zero);

      expect(request, isA<FaroTrackingHttpClientRequest>());
    });

    test('should rethrow when opening tracked request throws', () async {
      trackingFilter.configure(collectorUrl: null, ignoreUrls: null);

      final url = Uri.parse('http://example.com/path');
      when(() => mockHttpClient.openUrl('GET', url))
          .thenThrow(const SocketException('boom'));

      await expectLater(
        () => client.openUrl('GET', url),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('FaroTrackingHttpClientRequest:', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpClientResponse mockHttpClientResponse;
    late MockHttpHeaders mockRequestHeaders;
    late MockHttpHeaders mockResponseHeaders;
    late FaroTrackingHttpClientRequest trackedRequest;
    late MockSpan mockSpan;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpClientResponse = MockHttpClientResponse();
      mockRequestHeaders = MockHttpHeaders();
      mockResponseHeaders = MockHttpHeaders();
      mockSpan = MockSpan();

      when(() => mockSpan.traceId).thenReturn('trace-id');
      when(() => mockSpan.spanId).thenReturn('span-id');
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockHttpClientRequest.contentLength).thenReturn(42);
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);

      trackedRequest = FaroTrackingHttpClientRequest(
        mockHttpClientRequest,
        httpSpan: mockSpan,
      );
    });

    test('close should end span on success when response completes', () async {
      when(() => mockHttpClientRequest.close())
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);
      when(() => mockHttpClientResponse.headers)
          .thenReturn(mockResponseHeaders);
      when(() => mockResponseHeaders.contentLength).thenReturn(128);
      when(() => mockResponseHeaders.contentType).thenReturn(null);
      when(
        () => mockHttpClientResponse.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
          cancelOnError: any(named: 'cancelOnError'),
        ),
      ).thenAnswer((invocation) {
        final onDone = invocation.namedArguments[#onDone] as void Function()?;
        onDone?.call();
        return const Stream<List<int>>.empty().listen(null);
      });

      final response = await trackedRequest.close();
      verifyNever(() => mockSpan.end());
      response.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      expect(response, isA<HttpClientResponse>());
      verify(() => mockSpan.setStatus(SpanStatusCode.ok)).called(1);
      verify(() => mockSpan.end()).called(1);
    });

    test('close should end span on error', () async {
      when(() => mockHttpClientRequest.close())
          .thenThrow(const SocketException('close failed'));

      await expectLater(
        trackedRequest.close,
        throwsA(isA<Exception>()),
      );
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockSpan.setStatus(
          SpanStatusCode.error,
          message: any(named: 'message'),
        ),
      ).called(1);
      verify(() => mockSpan.end()).called(1);
    });

    test('done should wrap response and end span on completion', () async {
      when(() => mockHttpClientRequest.done)
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);
      when(() => mockHttpClientResponse.headers)
          .thenReturn(mockResponseHeaders);
      when(() => mockResponseHeaders.contentLength).thenReturn(128);
      when(() => mockResponseHeaders.contentType).thenReturn(null);
      when(
        () => mockHttpClientResponse.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
          cancelOnError: any(named: 'cancelOnError'),
        ),
      ).thenAnswer((invocation) {
        final onDone = invocation.namedArguments[#onDone] as void Function()?;
        onDone?.call();
        return const Stream<List<int>>.empty().listen(null);
      });

      final response = await trackedRequest.done;

      expect(response, isA<FaroTrackingHttpResponse>());
      verifyNever(() => mockSpan.end());

      response.listen((_) {});
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.setStatus(SpanStatusCode.ok)).called(1);
      verify(() => mockSpan.end()).called(1);
    });

    test('abort should finish the span and forward the error', () {
      final error = StateError('aborted');
      final stackTrace = StackTrace.current;

      trackedRequest.abort(error, stackTrace);

      verify(() => mockHttpClientRequest.abort(error, stackTrace)).called(1);
      verify(
        () => mockSpan.setStatus(
          SpanStatusCode.error,
          message: any(named: 'message'),
        ),
      ).called(1);
      verify(() => mockSpan.recordException(error, stackTrace: stackTrace))
          .called(1);
      verify(() => mockSpan.end()).called(1);
    });
  });

  group('FaroTrackingHttpResponse subscription handlers:', () {
    late MockHttpClientRequest mockHttpClientRequest;
    late MockHttpClientResponse mockHttpClientResponse;
    late MockHttpHeaders mockRequestHeaders;
    late MockHttpHeaders mockResponseHeaders;
    late FaroTrackingHttpClientRequest trackedRequest;
    late MockSpan mockSpan;
    late StreamController<List<int>> responseStreamController;

    setUp(() {
      mockHttpClientRequest = MockHttpClientRequest();
      mockHttpClientResponse = MockHttpClientResponse();
      mockRequestHeaders = MockHttpHeaders();
      mockResponseHeaders = MockHttpHeaders();
      mockSpan = MockSpan();
      responseStreamController = StreamController<List<int>>();

      when(() => mockSpan.traceId).thenReturn('trace-id');
      when(() => mockSpan.spanId).thenReturn('span-id');
      when(() => mockHttpClientRequest.method).thenReturn('GET');
      when(() => mockHttpClientRequest.uri)
          .thenReturn(Uri.parse('http://example.com/path'));
      when(() => mockHttpClientRequest.contentLength).thenReturn(42);
      when(() => mockHttpClientRequest.headers).thenReturn(mockRequestHeaders);
      when(() => mockHttpClientRequest.close())
          .thenAnswer((_) async => mockHttpClientResponse);
      when(() => mockHttpClientResponse.statusCode).thenReturn(200);
      when(() => mockHttpClientResponse.headers)
          .thenReturn(mockResponseHeaders);
      when(() => mockResponseHeaders.contentLength).thenReturn(128);
      when(() => mockResponseHeaders.contentType).thenReturn(null);
      when(
        () => mockHttpClientResponse.listen(
          any(),
          onError: any(named: 'onError'),
          onDone: any(named: 'onDone'),
          cancelOnError: any(named: 'cancelOnError'),
        ),
      ).thenAnswer((invocation) {
        final onData =
            invocation.positionalArguments[0] as void Function(List<int>)?;
        final onError = invocation.namedArguments[#onError] as Function?;
        final onDone = invocation.namedArguments[#onDone] as void Function()?;
        final cancelOnError =
            invocation.namedArguments[#cancelOnError] as bool?;
        return responseStreamController.stream.listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError,
        );
      });

      trackedRequest = FaroTrackingHttpClientRequest(
        mockHttpClientRequest,
        httpSpan: mockSpan,
      );
    });

    tearDown(() {
      if (!responseStreamController.isClosed) {
        responseStreamController.close();
      }
    });

    test('replacing onDone via setter should still end span', () async {
      final response = await trackedRequest.close();
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      subscription.onDone(() {});

      responseStreamController.close();
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.end()).called(1);
    });

    test('replacing onError via setter should still end span', () async {
      final response = await trackedRequest.close();
      final errors = <Object>[];
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      subscription.onError(errors.add);

      responseStreamController.addError(
        StateError('boom'),
        StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.setStatus(
            SpanStatusCode.error,
            message: any(named: 'message'),
          )).called(1);
      verify(() => mockSpan.end()).called(1);
      expect(errors, hasLength(1));
    });

    test('replacing onError with two-arg handler should forward both args',
        () async {
      final response = await trackedRequest.close();
      final errors = <Object>[];
      final traces = <StackTrace>[];
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      subscription.onError((Object e, StackTrace st) {
        errors.add(e);
        traces.add(st);
      });

      final testTrace = StackTrace.current;
      responseStreamController.addError(StateError('boom'), testTrace);
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.end()).called(1);
      expect(errors, hasLength(1));
      expect(traces, hasLength(1));
    });

    test('replacing onDone with null should still end span', () async {
      final response = await trackedRequest.close();
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      subscription.onDone(null);

      responseStreamController.close();
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.end()).called(1);
    });

    test('replacing onError with null should still end span', () async {
      final response = await trackedRequest.close();
      // ignore: cancel_subscriptions
      final subscription = response.listen(
        (_) {},
        onError: (Object e) {},
      );

      subscription.onError(null);

      responseStreamController.addError(
        StateError('boom'),
        StackTrace.current,
      );
      await Future<void>.delayed(Duration.zero);

      verify(() => mockSpan.end()).called(1);
    });

    test('asFuture should end span when stream completes normally', () async {
      final response = await trackedRequest.close();
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      final future = subscription.asFuture<void>();

      responseStreamController.close();
      await future;

      verify(() => mockSpan.end()).called(1);
    });

    test('asFuture should end span when stream emits error', () async {
      final response = await trackedRequest.close();
      // ignore: cancel_subscriptions
      final subscription = response.listen((_) {});

      final future = subscription.asFuture<void>();

      responseStreamController.addError(
        StateError('boom'),
        StackTrace.current,
      );

      await expectLater(future, throwsA(isA<StateError>()));
      verify(() => mockSpan.setStatus(
            SpanStatusCode.error,
            message: any(named: 'message'),
          )).called(1);
      verify(() => mockSpan.end()).called(1);
    });
  });
}
