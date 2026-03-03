import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/integrations/http_tracking_filter.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/util/short_id.dart';
import 'package:uuid/uuid.dart';

class FaroHttpOverrides extends HttpOverrides {
  FaroHttpOverrides(this.existingOverrides);
  final HttpOverrides? existingOverrides;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final innerClient = existingOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return FaroHttpTrackingClient(
      innerClient,
      trackingFilter: pod.resolve(httpTrackingFilterProvider),
      lifecycleSignalChannel:
          pod.resolve(userActionLifecycleSignalChannelProvider),
    );
  }
}

class FaroHttpTrackingClient implements HttpClient {
  FaroHttpTrackingClient(
    this.innerClient, {
    required HttpTrackingFilter trackingFilter,
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  })  : _trackingFilter = trackingFilter,
        _lifecycleSignalChannel = lifecycleSignalChannel;
  final HttpClient innerClient;
  final HttpTrackingFilter _trackingFilter;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;

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

  Future<HttpClientRequest> _openUrl(String method, Uri url) async {
    if (!_trackingFilter.shouldTrack(url)) {
      return innerClient.openUrl(method, url);
    }

    final requestId = generateShortId();

    _lifecycleSignalChannel.emitPendingStart(
      source: 'http',
      operationId: requestId,
    );

    final httpSpan = Faro().startSpanManual(
      'HTTP $method',
      attributes: {
        'http.method': method,
        'http.scheme': url.scheme,
        'http.url': url.toString(),
        'http.host': url.host,
        'http.user_agent': innerClient.userAgent ?? '',
      },
    );

    try {
      // ignore: close_sinks
      final request = await innerClient.openUrl(method, url);
      final key = const Uuid().v1();
      Faro().markEventStart(key, 'http_request');
      return FaroTrackingHttpClientRequest(
        key,
        request,
        httpSpan: httpSpan,
        requestId: requestId,
        lifecycleSignalChannel: _lifecycleSignalChannel,
      );
    } catch (error, stackTrace) {
      httpSpan.setStatus(
        SpanStatusCode.error,
        message: error.toString(),
      );
      httpSpan.recordException(error, stackTrace: stackTrace);
      httpSpan.end();
      _lifecycleSignalChannel.emitPendingEnd(
        source: 'http',
        operationId: requestId,
      );
      rethrow;
    }
  }

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      innerClient.connectionFactory = f;

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
      Uri url, String realm, HttpClientCredentials credentials) {
    innerClient.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
      String host, int port, String realm, HttpClientCredentials credentials) {
    innerClient.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      innerClient.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      innerClient.authenticateProxy = f;

  @override
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      innerClient.badCertificateCallback = callback;

  @override
  void close({bool force = false}) {
    innerClient.close(force: force);
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return innerClient.delete(host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _openUrl('delete', url);

  @override
  set findProxy(String Function(Uri url)? f) => innerClient.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('get', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _openUrl('get', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('head', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _openUrl('head', url);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) =>
      _openUrl(method, url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('patch', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _openUrl('patch', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('post', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _openUrl('post', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('post', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _openUrl('put', url);
}

class FaroTrackingHttpClientRequest implements HttpClientRequest {
  FaroTrackingHttpClientRequest(
    this.key,
    this.innerContext, {
    required Span httpSpan,
    required String requestId,
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  })  : _httpSpan = httpSpan,
        _requestId = requestId,
        _lifecycleSignalChannel = lifecycleSignalChannel {
    if (_httpSpan is InternalSpan) {
      innerContext.headers
          .add('traceparent', (_httpSpan as InternalSpan).toHttpTraceparent());
    }
  }

  final HttpClientRequest innerContext;
  String key;
  final Span _httpSpan;
  final String _requestId;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;

  @override
  Future<HttpClientResponse> get done {
    final innerFuture = innerContext.done;
    return innerFuture.then((value) {
      return value;
    }, onError: (Object error, StackTrace? stackTrace) {
      throw Exception('Error: $error, StackTrace: $stackTrace');
    });
  }

  @override
  Future<HttpClientResponse> close() async {
    try {
      final value = await innerContext.close();

      _httpSpan.setAttributes({
        'http.status_code': value.statusCode,
        'http.request_size': innerContext.contentLength,
        'http.response_size': value.headers.contentLength,
        'http.content_type': '${value.headers.contentType}',
      });
      _httpSpan.setStatus(SpanStatusCode.ok);

      return FaroTrackingHttpResponse(key, value, {
        'response_size': '${value.headers.contentLength}',
        'content_type': '${value.headers.contentType}',
        'status_code': '${value.statusCode}',
        'method': innerContext.method,
        'request_size': '${innerContext.contentLength}',
        'url': innerContext.uri.toString(),
        'trace_id': _httpSpan.traceId,
        'span_id': _httpSpan.spanId,
      });
    } catch (error, stackTrace) {
      _httpSpan.setStatus(
        SpanStatusCode.error,
        message: error.toString(),
      );
      _httpSpan.recordException(error, stackTrace: stackTrace);
      throw Exception('Error: $error, StackTrace: $stackTrace');
    } finally {
      _httpSpan.end();
      _lifecycleSignalChannel.emitPendingEnd(
        source: 'http',
        operationId: _requestId,
      );
    }
  }

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
  void abort([Object? exception, StackTrace? stackTrace]) =>
      innerContext.abort(exception, stackTrace);

  @override
  void add(List<int> data) => innerContext.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      innerContext.addError(error, stackTrace);

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) {
    return innerContext.addStream(stream);
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
    this.key,
    this.innerResponse,
    this.userAttributes,
  );
  final HttpClientResponse innerResponse;
  final Map<String, Object?> userAttributes;
  Object? lastError;
  String key;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return innerResponse.listen(
      onData,
      cancelOnError: cancelOnError,
      onError: (Object e, StackTrace st) {
        if (onError == null) {
          return;
        }
        if (onError is void Function(Object, StackTrace)) {
          onError(e, st);
        } else if (onError is void Function(Object)) {
          onError(e);
        } else {
          Faro().pushLog(
            // ignore: lines_longer_than_80_chars
            "network_error on : ${userAttributes["method"]} : ${userAttributes["url"]}",
            level: LogLevel.error,
          );
        }
      },
      onDone: () {
        _onFinish();
        if (onDone != null) {
          onDone();
        }
      },
    );
  }

  void _onFinish() {
    Faro().markEventEnd(key, 'http_request', attributes: userAttributes);
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
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    return innerResponse.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => innerResponse.redirects;

  @override
  int get statusCode => innerResponse.statusCode;
}
