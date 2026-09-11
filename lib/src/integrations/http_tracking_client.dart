import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/tracing/faro_span_context.dart';
import 'package:faro/src/tracing/faro_tracer.dart';
import 'package:faro/src/tracing/http_event_attributes.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/user_actions/constants.dart';

class FaroHttpOverrides extends HttpOverrides {
  FaroHttpOverrides(this.existingOverrides);
  final HttpOverrides? existingOverrides;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final innerClient =
        existingOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return FaroHttpTrackingClient(
      innerClient,
      trackingFilter: pod.resolve(httpTrackingFilterProvider),
      // Resolve per request: this client can outlive initialization or reset.
      startHttpSpan: (name, {required attributes}) => pod
          .resolve(faroHttpTracerProvider)
          .startSpanManual(name, attributes: attributes),
    );
  }
}

/// Starts a span for an automatically instrumented HTTP request.
typedef StartHttpSpan =
    Span Function(String name, {required Map<String, Object> attributes});

class FaroHttpTrackingClient implements HttpClient {
  FaroHttpTrackingClient(
    this.innerClient, {
    required HttpTrackingFilter trackingFilter,
    required StartHttpSpan startHttpSpan,
  }) : _trackingFilter = trackingFilter,
       _startHttpSpan = startHttpSpan;
  final HttpClient innerClient;
  final HttpTrackingFilter _trackingFilter;
  final StartHttpSpan _startHttpSpan;

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    const hashMark = 0x23;
    const questionMark = 0x3f;
    var fragmentStart = path.length;
    var queryStart = path.length;
    for (var i = path.length - 1; i >= 0; i--) {
      final char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    var parsedPath = path;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      parsedPath = path.substring(0, queryStart);
    }
    final uri = Uri(
      scheme: 'http',
      host: host,
      port: port,
      path: parsedPath,
      query: query,
    );
    return _openUrl(method, uri);
  }

  // Unknown-method handling is separate from known-method normalization.
  static const _knownMethods = {
    'GET',
    'HEAD',
    'POST',
    'PUT',
    'DELETE',
    'CONNECT',
    'OPTIONS',
    'TRACE',
    'PATCH',
    'QUERY',
  };

  Future<HttpClientRequest> _openUrl(String method, Uri url) async {
    if (!_trackingFilter.shouldTrack(url)) {
      return innerClient.openUrl(method, url);
    }

    // Dart's HttpClient uppercases methods before sending the request.
    final upperMethod = method.toUpperCase();
    final isKnownMethod = _knownMethods.contains(upperMethod);
    final recordedMethod = isKnownMethod ? upperMethod : method;
    final httpSpan = _startHttpSpan(
      isKnownMethod ? recordedMethod : 'HTTP $method',
      attributes: {
        'http.request.method': recordedMethod,
        if (isKnownMethod && recordedMethod != method)
          'http.request.method_original': method,
        'url.full': _sanitizeHttpUrl(url),
        'server.address': url.host,
        'server.port': url.port,
        UserActionConstants.pendingOperationKey: true,
      },
    );

    initializeHttpEventAttributes(httpSpan, {
      if (isKnownMethod) 'http.request.method': recordedMethod,
      if (isKnownMethod && recordedMethod != method)
        'http.request.method_original': method,
      'http.method': recordedMethod,
      'http.scheme': url.scheme,
      'http.url': url.toString(),
      'http.host': url.host,
      'http.user_agent': innerClient.userAgent ?? '',
    });

    try {
      // ignore: close_sinks
      final request = await innerClient.openUrl(method, url);
      return FaroTrackingHttpClientRequest(request, httpSpan: httpSpan);
    } catch (error, stackTrace) {
      _recordHttpError(httpSpan, error, stackTrace);
      httpSpan.end();
      rethrow;
    }
  }

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => innerClient.connectionFactory = f;

  @override
  set keyLog(void Function(String line)? callback) =>
      innerClient.keyLog = callback;

  @override
  bool get autoUncompress => innerClient.autoUncompress;
  @override
  set autoUncompress(bool value) => innerClient.autoUncompress = value;

  @override
  Duration? get connectionTimeout => innerClient.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) =>
      innerClient.connectionTimeout = value;

  @override
  Duration get idleTimeout => innerClient.idleTimeout;
  @override
  set idleTimeout(Duration value) => innerClient.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => innerClient.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) =>
      innerClient.maxConnectionsPerHost = value;

  @override
  String? get userAgent => innerClient.userAgent;
  @override
  set userAgent(String? value) => innerClient.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {
    innerClient.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {
    innerClient.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) => innerClient.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String host, int port, String scheme, String? realm)?
    f,
  ) => innerClient.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) => innerClient.badCertificateCallback = callback;

  @override
  void close({bool force = false}) {
    innerClient.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _openUrl('DELETE', url);

  @override
  set findProxy(String Function(Uri url)? f) => innerClient.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _openUrl('GET', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _openUrl(method, url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _openUrl('PUT', url);
}

// Sanitize only the telemetry copy, preserving the actual request and the
// encoding/order of non-sensitive query parameters.
String _sanitizeHttpUrl(Uri url) {
  const sensitiveKeys = {
    'X-Amz-Signature',
    'X-Amz-Credential',
    'X-Amz-Security-Token',
    'sig',
    'X-Goog-Signature',
  };
  final query = url.query
      .split('&')
      .map((part) {
        final separator = part.indexOf('=');
        final key = separator < 0 ? part : part.substring(0, separator);
        try {
          if (sensitiveKeys.contains(Uri.decodeQueryComponent(key))) {
            return '$key=REDACTED';
          }
        } on FormatException {
          // Invalid UTF-8 cannot match a sensitive key. Do not let telemetry
          // sanitization prevent the HTTP client from handling the request.
        }
        return part;
      })
      .join('&');
  return url
      .replace(
        userInfo: url.userInfo.isEmpty ? null : 'REDACTED:REDACTED',
        query: url.hasQuery ? query : null,
      )
      .toString();
}

void _recordHttpError(Span span, Object error, StackTrace? stackTrace) {
  preserveHttpEventErrorType(span);
  if (span is InternalSpan &&
      httpEventAttributes(span.otelSpan)?['http.status_code'] == null) {
    updateHttpEventAttributes(span, {'http.status_code': '0'});
  }
  // Keep the first error, including an HTTP error recorded before a body
  // failure. Exception types carry failure information without inventing a
  // response code or using high-cardinality exception messages as error.type.
  if (span.status != SpanStatusCode.error) {
    span.setAttribute('error.type', error.runtimeType.toString());
    span.setStatus(SpanStatusCode.error, message: error.toString());
  }
  span.recordException(error, stackTrace: stackTrace);
}

class FaroTrackingHttpClientRequest implements HttpClientRequest {
  FaroTrackingHttpClientRequest(this.innerContext, {required Span httpSpan})
    : _httpSpan = httpSpan {
    innerContext.headers.add('traceparent', _httpSpan.traceparent);
  }

  final HttpClientRequest innerContext;
  final Span _httpSpan;
  var _operationFinished = false;

  void _finishOperation() {
    if (_operationFinished) {
      return;
    }
    _operationFinished = true;
    _httpSpan.end();
  }

  void _recordOperationError(Object error, [StackTrace? stackTrace]) {
    _recordHttpError(_httpSpan, error, stackTrace);
  }

  Future<HttpClientResponse> _trackResponseFuture(
    Future<HttpClientResponse> Function() responseFuture,
  ) async {
    try {
      final value = await responseFuture();

      preserveHttpEventErrorType(_httpSpan);
      updateHttpEventAttributes(_httpSpan, {
        'http.status_code': '${value.statusCode}',
        'http.request_size': '${innerContext.contentLength}',
        'http.response_size': '${value.headers.contentLength}',
        'http.content_type': '${value.headers.contentType}',
      });
      _httpSpan.setAttribute('http.response.status_code', value.statusCode);
      // Successful responses leave status unset. Preserve an error already
      // recorded on the span instead of replacing its diagnostic information.
      if (value.statusCode >= 400 && _httpSpan.status != SpanStatusCode.error) {
        updateHttpEventAttributes(_httpSpan, {
          'error.type': value.statusCode.toString(),
        });
        _httpSpan.setAttribute('error.type', value.statusCode.toString());
        _httpSpan.setStatus(SpanStatusCode.error);
      }

      return FaroTrackingHttpResponse(
        value,
        {
          'response_size': '${value.headers.contentLength}',
          'content_type': '${value.headers.contentType}',
          'status_code': '${value.statusCode}',
          'method': innerContext.method,
          'request_size': '${innerContext.contentLength}',
          'url': _sanitizeHttpUrl(innerContext.uri),
        },
        spanContext: _httpSpan.spanContext,
        onFinish: _finishOperation,
        onStreamError: _recordOperationError,
      );
    } catch (error, stackTrace) {
      _recordOperationError(error, stackTrace);
      _finishOperation();
      throw Exception('Error: $error, StackTrace: $stackTrace');
    }
  }

  @override
  Future<HttpClientResponse> get done =>
      _trackResponseFuture(() => innerContext.done);

  @override
  Future<HttpClientResponse> close() =>
      _trackResponseFuture(innerContext.close);

  @override
  bool get bufferOutput => innerContext.bufferOutput;
  @override
  set bufferOutput(bool value) => innerContext.bufferOutput = value;

  @override
  int get contentLength => innerContext.contentLength;
  @override
  set contentLength(int value) => innerContext.contentLength = value;

  @override
  Encoding get encoding => innerContext.encoding;
  @override
  set encoding(Encoding value) => innerContext.encoding = value;

  @override
  bool get followRedirects => innerContext.followRedirects;
  @override
  set followRedirects(bool value) => innerContext.followRedirects = value;

  @override
  int get maxRedirects => innerContext.maxRedirects;
  @override
  set maxRedirects(int value) => innerContext.maxRedirects = value;

  @override
  bool get persistentConnection => innerContext.persistentConnection;

  @override
  set persistentConnection(bool value) =>
      innerContext.persistentConnection = value;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _recordOperationError(
      exception ?? const HttpException('Request has been aborted'),
      stackTrace,
    );
    try {
      innerContext.abort(exception, stackTrace);
    } finally {
      _finishOperation();
    }
  }

  @override
  void add(List<int> data) => innerContext.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      innerContext.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) async {
    try {
      return await innerContext.addStream(stream);
    } catch (error, stackTrace) {
      _recordOperationError(error, stackTrace);
      _finishOperation();
      rethrow;
    }
  }

  @override
  HttpConnectionInfo? get connectionInfo => innerContext.connectionInfo;

  @override
  List<Cookie> get cookies => innerContext.cookies;

  @override
  Future<dynamic> flush() => innerContext.flush();

  @override
  HttpHeaders get headers => innerContext.headers;

  @override
  String get method => innerContext.method;

  @override
  Uri get uri => innerContext.uri;

  @override
  void write(Object? object) {
    innerContext.write(object);
  }

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    innerContext.writeAll(objects, separator);
  }

  @override
  void writeCharCode(int charCode) {
    innerContext.writeCharCode(charCode);
  }

  @override
  void writeln([Object? object = '']) {
    innerContext.writeln(object);
  }
}

class FaroTrackingHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FaroTrackingHttpResponse(
    this.innerResponse,
    this.userAttributes, {
    required FaroSpanContext spanContext,
    required void Function() onFinish,
    required void Function(Object error, StackTrace stackTrace) onStreamError,
  }) : _spanContext = spanContext,
       _onFinish = onFinish,
       _onStreamError = onStreamError;
  final HttpClientResponse innerResponse;
  final Map<String, Object?> userAttributes;
  final FaroSpanContext _spanContext;
  final void Function() _onFinish;
  final void Function(Object error, StackTrace stackTrace) _onStreamError;
  Object? lastError;
  var _finished = false;

  void _finishOnce() {
    if (_finished) {
      return;
    }
    _finished = true;
    _onFinish();
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _FaroResponseSubscription(
      innerResponse.listen(
        onData,
        cancelOnError: cancelOnError,
        onError: (Object error, StackTrace stackTrace) {
          _onStreamError(error, stackTrace);
          _finishOnce();
          if (onError == null) {
            return;
          }
          if (onError is void Function(Object, StackTrace)) {
            onError(error, stackTrace);
          } else if (onError is void Function(Object)) {
            onError(error);
          } else {
            Faro().pushLog(
              // ignore: lines_longer_than_80_chars
              "network_error on : ${userAttributes["method"]} : ${userAttributes["url"]}",
              level: LogLevel.error,
              spanContext: _spanContext,
            );
          }
        },
        onDone: () {
          _finishOnce();
          if (onDone != null) {
            onDone();
          }
        },
      ),
      onCancel: _finishOnce,
      onComplete: _finishOnce,
      onStreamError: _onStreamError,
    );
  }

  @override
  X509Certificate? get certificate => innerResponse.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      innerResponse.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => innerResponse.connectionInfo;

  @override
  int get contentLength => innerResponse.contentLength;

  @override
  List<Cookie> get cookies => innerResponse.cookies;

  @override
  Future<Socket> detachSocket() {
    return innerResponse.detachSocket();
  }

  @override
  HttpHeaders get headers => innerResponse.headers;

  @override
  bool get isRedirect => innerResponse.isRedirect;

  @override
  bool get persistentConnection => innerResponse.persistentConnection;

  @override
  String get reasonPhrase => innerResponse.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    return innerResponse.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => innerResponse.redirects;

  @override
  int get statusCode => innerResponse.statusCode;
}

class _FaroResponseSubscription implements StreamSubscription<List<int>> {
  _FaroResponseSubscription(
    this._inner, {
    required void Function() onCancel,
    required void Function() onComplete,
    required void Function(Object error, StackTrace stackTrace) onStreamError,
  }) : _onCancel = onCancel,
       _onComplete = onComplete,
       _onStreamError = onStreamError;

  final StreamSubscription<List<int>> _inner;
  final void Function() _onCancel;
  final void Function() _onComplete;
  final void Function(Object error, StackTrace stackTrace) _onStreamError;

  @override
  Future<void> cancel() async {
    _onCancel();
    await _inner.cancel();
  }

  @override
  void onData(void Function(List<int> data)? handleData) {
    _inner.onData(handleData);
  }

  @override
  void onDone(void Function()? handleDone) {
    _inner.onDone(() {
      _onComplete();
      handleDone?.call();
    });
  }

  @override
  void onError(Function? handleError) {
    _inner.onError((Object error, StackTrace stackTrace) {
      _onStreamError(error, stackTrace);
      _onCancel();
      if (handleError == null) {
        return;
      }
      if (handleError is void Function(Object, StackTrace)) {
        handleError(error, stackTrace);
      } else if (handleError is void Function(Object)) {
        handleError(error);
      }
    });
  }

  @override
  void pause([Future<void>? resumeSignal]) {
    _inner.pause(resumeSignal);
  }

  @override
  void resume() {
    _inner.resume();
  }

  @override
  bool get isPaused => _inner.isPaused;

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    onDone(() {
      completer.complete(futureValue as E);
    });
    onError((Object error, StackTrace stackTrace) {
      cancel();
      completer.completeError(error, stackTrace);
    });
    return completer.future;
  }
}
