import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:faro/src/faro.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/task_buffer.dart';
import 'package:http/http.dart' as http;

/// Resolves the current session id to send in the `x-faro-session-id` header.
typedef SessionIdResolver = String Function();

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
  TaskBuffer<dynamic>? _taskBuffer;
  final Map<String, String>? headers;

  /// Optional HTTP client seam for tests. When null, the top-level
  /// [http.post] is used so production behavior is unchanged.
  final http.Client? _httpClient;

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    if (Faro().enableDataCollection == false) {
      log('Data collection is disabled. Skipping sending data.');
      return;
    }

    try {
      final encodedPayload = jsonEncode(payloadJson);

      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'x-faro-session-id': _sessionIdResolver(),
        ...?this.headers,
      };

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
    } catch (error) {
      log('Error encoding payload: $error');
    }
  }
}
