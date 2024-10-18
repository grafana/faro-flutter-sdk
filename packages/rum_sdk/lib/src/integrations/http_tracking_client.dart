import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:uuid/uuid.dart';

import '../../rum_flutter.dart';


class RumHttpOverrides extends HttpOverrides {
  final HttpOverrides? existingOverrides;

  RumHttpOverrides(this.existingOverrides);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var innerClient = existingOverrides?.createHttpClient(context) ??
        super.createHttpClient(context);
    return RumHttpTrackingClient(innerClient);
  }
}

class RumHttpTrackingClient implements HttpClient {
  final HttpClient innerClient;

  RumHttpTrackingClient(
      this.innerClient,
      );

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    const int hashMark = 0x23;
    const int questionMark = 0x3f;
    int fragmentStart = path.length;
    int queryStart = path.length;
    for (int i = path.length - 1; i >= 0; i--) {
      var char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      path = path.substring(0, queryStart);
    }
    Uri uri =
    Uri(scheme: 'http', host: host, port: port, path: path, query: query);
    return _openUrl(method, uri);
  }

  Future<HttpClientRequest> _openUrl(String method, Uri url) async {

    HttpClientRequest request;
    Map<String, Object?> userAttributes = {};
    try {
      request = await innerClient.openUrl(method, url);
      if(url.toString()!= RumFlutter().config?.collectorUrl) {
        String key = const Uuid().v1();
        RumFlutter().markEventStart(key, "http_request");
        request = RumTrackingHttpClientRequest(key, request, userAttributes);
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
  set keyLog(Function(String line)? callback) => innerClient.keyLog = callback;

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

class RumTrackingHttpClientRequest implements HttpClientRequest {
  final HttpClientRequest innerContext;
  final Map<String, Object?> userAttributes;
  String key;


  RumTrackingHttpClientRequest(
      this.key,
      this.innerContext,
      this.userAttributes,
      ) {
  }

  @override
  Future<HttpClientResponse> get done {
    final innerFuture = innerContext.done;
    return innerFuture.then((value) {
      return value;
    }, onError: (Object e, StackTrace? st) {
      throw e;
    });
  }

  @override
  Future<HttpClientResponse> close() {

    return innerContext.close().then((value) {
      return RumTrackingHttpResponse(key,value,{
        "response_size": "${value.headers.contentLength}",
        "content_type": "${value.headers.contentType}",
        "status_code": "${value.statusCode}",
        "method": innerContext.method,
        "request_size": "${innerContext.contentLength}",
        "url": innerContext.uri.toString(),
      });
    }, onError: (Object e, StackTrace? st) {
      throw e;
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

class RumTrackingHttpResponse extends Stream<List<int>>
    implements HttpClientResponse {
  final HttpClientResponse innerResponse;
  final Map<String, Object?> userAttributes;
  Object? lastError;
  String key;

  RumTrackingHttpResponse(
      this.key,
      this.innerResponse,
      this.userAttributes,
      );

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
          RumFlutter().pushLog("network_error on : ${userAttributes["method"]} : ${userAttributes["url"]}", level:"error");
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
    RumFlutter().markEventEnd(key, "http_request", attributes: userAttributes);
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
