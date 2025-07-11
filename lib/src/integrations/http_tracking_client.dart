import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:faro/src/faro.dart';
import 'package:faro/src/models/log_level.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:uuid/uuid.dart';

class FaroHttpOverrides extends HttpOverrides {
  FaroHttpOverrides(this.existingOverrides);
  final HttpOverrides? existingOverrides;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final innerClient = existingOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return FaroHttpTrackingClient(innerClient);
  }
}

class FaroHttpTrackingClient implements HttpClient {
  FaroHttpTrackingClient(
    this.innerClient,
  );
  final HttpClient innerClient;

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
    HttpClientRequest request;
    final userAttributes = <String, Object?>{};
    try {
      request = await innerClient.openUrl(method, url);
      if (url.toString() != Faro().config?.collectorUrl) {
        final key = const Uuid().v1();
        Faro().markEventStart(key, 'http_request');
        request = FaroTrackingHttpClientRequest(
          key,
          request,
          userAttributes,
          userAgent: innerClient.userAgent,
        );
      }
    } catch (e) {
      rethrow;
    }
    return request;
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
    this.innerContext,
    this.userAttributes, {
    String? userAgent,
  }) {
    _httpSpan = Faro().startSpanManual(
      'HTTP ${innerContext.method}',
      attributes: {
        'http.method': innerContext.method,
        'http.scheme': innerContext.uri.scheme,
        'http.url': innerContext.uri.toString(),
        'http.host': innerContext.uri.host,
        'http.user_agent': userAgent ?? '',
      },
    );
    if (_httpSpan is InternalSpan) {
      innerContext.headers
          .add('traceparent', (_httpSpan as InternalSpan).toHttpTraceparent());
    }
  }

  final HttpClientRequest innerContext;
  final Map<String, Object?> userAttributes;
  String key;
  late final Span _httpSpan;

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
  Future<HttpClientResponse> close() {
    return innerContext.close().then((value) {
      final traceId = _httpSpan.traceId;
      final spanId = _httpSpan.spanId;

      _httpSpan.setAttributes({
        'http.status_code': '${value.statusCode}',
        'http.request_size': '${innerContext.contentLength}',
        'http.response_size': '${value.headers.contentLength}',
        'http.content_type': '${value.headers.contentType}',
      });

      _httpSpan.setStatus(SpanStatusCode.ok);
      _httpSpan.end();
      return FaroTrackingHttpResponse(key, value, {
        'response_size': '${value.headers.contentLength}',
        'content_type': '${value.headers.contentType}',
        'status_code': '${value.statusCode}',
        'method': innerContext.method,
        'request_size': '${innerContext.contentLength}',
        'url': innerContext.uri.toString(),
        'trace_id': traceId,
        'span_id': spanId,
      });
    }, onError: (Object error, StackTrace? stackTrace) {
      _httpSpan.setStatus(SpanStatusCode.error, message: error.toString());
      _httpSpan.recordException(error, stackTrace: stackTrace);
      _httpSpan.end();
      throw Exception('Error: $error, StackTrace: $stackTrace');
    });
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
