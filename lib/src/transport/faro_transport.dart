import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:faro/src/faro.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/task_buffer.dart';
import 'package:http/http.dart' as http;

/// Resolves the current session id to send in the `x-faro-session-id` header.
typedef SessionIdResolver = String Function();

/// Called when the receiver reports that a submitted session is invalid.
typedef SessionInvalidatedHandler = void Function(String sessionId);

class FaroTransport extends BaseTransport {
  FaroTransport({
    required this.collectorUrl,
    required this.apiKey,
    required SessionIdResolver sessionIdResolver,
    int? maxBufferLimit,
    this.headers,
    http.Client? httpClient,
  }) : _sessionIdResolver = sessionIdResolver,
       _httpClient = httpClient {
    _taskBuffer = TaskBuffer(maxBufferLimit ?? 30);
  }

  static const _accepted = 202;
  static const _sessionIdHeader = 'x-faro-session-id';
  static const _sessionStatusHeader = 'x-faro-session-status';
  static const _invalidSessionStatus = 'invalid';

  final String collectorUrl;
  final String apiKey;

  /// Resolves the current session id at send time.
  ///
  /// The `x-faro-session-id` header identifies the session the client
  /// currently considers active — the receiver uses it for server-side
  /// session validation and accounting, independently of the session id
  /// carried in the payload body. Resolving it live keeps the header on the
  /// active session even when a rotation happened after this transport was
  /// created, or when an older cached payload is replayed offline.
  final SessionIdResolver _sessionIdResolver;
  SessionInvalidatedHandler? _onSessionInvalidated;
  TaskBuffer<dynamic>? _taskBuffer;
  final Map<String, String>? headers;

  /// Optional HTTP client seam for tests. When null, the top-level
  /// [http.post] is used so production behavior is unchanged.
  final http.Client? _httpClient;

  /// Connects receiver invalidation responses to the SDK session manager.
  set sessionInvalidatedHandler(SessionInvalidatedHandler handler) {
    _onSessionInvalidated = handler;
  }

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    await _send(payloadJson, processSessionInvalidation: true);
  }

  /// Sends historical telemetry without applying receiver session
  /// invalidation to the live session.
  Future<void> sendHistorical(Map<String, dynamic> payloadJson) async {
    await _send(payloadJson, processSessionInvalidation: false);
  }

  Future<void> _send(
    Map<String, dynamic> payloadJson, {
    required bool processSessionInvalidation,
  }) async {
    if (Faro().enableDataCollection == false) {
      log('Data collection is disabled. Skipping sending data.');
      return;
    }

    try {
      final encodedPayload = jsonEncode(payloadJson);

      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        _sessionIdHeader: _sessionIdResolver(),
        ...?this.headers,
      };
      // Capture the effective request value before awaiting the response.
      // Custom headers may override the resolver value using different casing.
      final sentSessionId = _headerValue(headers, _sessionIdHeader);

      final post = _httpClient?.post ?? http.post;
      final response = await _taskBuffer?.add(() {
        return post(
          Uri.parse(collectorUrl),
          headers: headers,
          body: encodedPayload,
        );
      });

      if (response != null && response.statusCode ~/ 100 != 2) {
        log(
          'Error sending payload: ${response.statusCode}, '
          'body: ${response.body} payload:$encodedPayload',
        );
      }

      if (response != null &&
          processSessionInvalidation &&
          sentSessionId != null &&
          response.statusCode == _accepted &&
          _headerValue(response.headers, _sessionStatusHeader) ==
              _invalidSessionStatus) {
        log('Faro: Receiver reported the submitted session as invalid.');
        _onSessionInvalidated?.call(sentSessionId);
      }
    } catch (error) {
      log('Error sending payload: $error');
    }
  }

  static String? _headerValue(Map<String, String> headers, String name) {
    String? value;
    // Custom headers are merged last, so the last case-insensitive match is
    // the effective value sent by the HTTP client.
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name) {
        value = entry.value;
      }
    }
    return value;
  }
}
