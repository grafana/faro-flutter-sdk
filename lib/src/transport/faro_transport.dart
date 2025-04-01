import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:faro/src/data_collection_policy.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/task_buffer.dart';
import 'package:http/http.dart' as http;

class FaroTransport extends BaseTransport {
  FaroTransport({
    required this.collectorUrl,
    required this.apiKey,
    this.sessionId,
    int? maxBufferLimit,
  }) {
    _taskBuffer = TaskBuffer(maxBufferLimit ?? 30);
  }
  final String collectorUrl;
  final String apiKey;
  final String? sessionId;
  TaskBuffer<dynamic>? _taskBuffer;

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    if (DataCollectionPolicy().isEnabled == false) {
      log('Data collection is disabled. Skipping sending data.');
      return;
    }

    try {
      // Try to encode the payload to check for any JSON encoding issues
      final encodedPayload = jsonEncode(payloadJson);

      final sessionId = this.sessionId;

      final headers = {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        if (sessionId != null) 'x-faro-session-id': sessionId,
      };
      final response = await _taskBuffer?.add(() {
        return http.post(
          Uri.parse(collectorUrl),
          headers: headers,
          body: encodedPayload,
        );
      });
      if (response != null && response?.statusCode ~/ 100 != 2) {
        log(
          // ignore: lines_longer_than_80_chars
          'Error sending payload: ${response?.statusCode}, body: ${response?.body} payload:$encodedPayload',
        );
      }
    } catch (error) {
      log('Error encoding payload: $error');
    }
  }
}
