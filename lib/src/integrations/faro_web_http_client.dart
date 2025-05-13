//import 'dart:html' if (dart.library.io) 'stub_io.dart' as html;

import 'package:faro/faro.dart';
import 'package:faro/src/configurations/faro_config.dart';
import 'package:faro/src/models/meta.dart';
import 'package:faro/src/tracing/span.dart';
import 'package:faro/src/tracing/tracer.dart';
import 'package:flutter/foundation.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart';

/// An http.Client that automatically creates Faro tracing spans
/// for web requests.
/// Use this client when making HTTP requests in a Flutter Web application
/// instrumented with the Faro Flutter SDK.
///
/// Obtain an instance via `Faro().createHttpClient()`. TODO: double check if still true
///
/// Note: The server being called must accept the 'traceparent' header via CORS
/// configuration (`Access-Control-Allow-Headers`).

Client createFaroWebHttpClient() => FaroWebHttpClient();

class FaroWebHttpClient extends BaseClient {
  FaroWebHttpClient()
      : _inner = BrowserClient(),
        _tracer = kIsWeb ? Faro().getTracer() : null,
        _faroConfig = kIsWeb ? Faro().config : null,
        _faroMeta = kIsWeb ? Faro().meta : null {
    if (!_isWeb) {
      throw UnsupportedError(
          'FaroWebHttpClient is only supported on the web platform.');
    }
  }

  final BrowserClient _inner;
  final Tracer? _tracer;
  final FaroConfig? _faroConfig;
  final Meta? _faroMeta;
  final bool _isWeb = kIsWeb;

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (!_isWeb ||
        _tracer == null ||
        _faroConfig == null ||
        _faroMeta == null) {
      return _inner.send(request);
    }

    final urlString = request.url.toString();

    final isCollectorUrl = urlString == _faroConfig!.collectorUrl;
    final ignoreUrls = [
      ...?_faroConfig!.ignoreUrls,
      if (isCollectorUrl && _faroConfig!.collectorUrl != null)
        RegExp(RegExp.escape(_faroConfig!.collectorUrl!))
    ];
    final isIgnored = ignoreUrls.any((regex) => regex.hasMatch(urlString));

    if (isIgnored) {
      return _inner.send(request);
    }

    //final String userAgent = kIsWeb ? (html.window.navigator.userAgent) : 'unknown';
    final String userAgent = "unknwon";

    final span = _tracer!.startSpan(
      'HTTP ${request.method}',
      attributes: {
        'http.method': request.method,
        'http.scheme': request.url.scheme,
        'http.url': request.url.toString(),
        'http.host': request.url.host,
        'http.user_agent': userAgent,
      },
    );

    final internalSpan = (span is InternalSpan) ? span : null;

    try {
      if (internalSpan != null) {
        final traceParent = internalSpan.toHttpTraceparent();
        request.headers['traceparent'] = traceParent;
      }

      final response = await _inner.send(request);

      span.setAttributes({
        'http.status_code': '${response.statusCode}',
        'http.response_content_length': '${response.contentLength ?? '0'}',
      });

      // FaroTrackingHttpClient does not do this
      if (response.statusCode >= 500) {
        span.setStatus(SpanStatusCode.error,
            message: 'HTTP Server Error: ${response.statusCode}');
      } else if (response.statusCode >= 400) {
        span.setStatus(SpanStatusCode.error,
            message: 'HTTP Client Error: ${response.statusCode}');
      } else {
        span.setStatus(SpanStatusCode.ok);
      }

      span.end();

      return response;
    } catch (e, s) {
      span.setStatus(SpanStatusCode.error, message: e.toString());
      span.setAttributes({
        'error': e.toString(),
        'exception.stacktrace': s.toString()
      }); // FaroTrackingHttpClient does not do this
      span.end();

      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
