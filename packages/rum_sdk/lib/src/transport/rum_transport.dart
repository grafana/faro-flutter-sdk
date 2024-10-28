import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;
import 'package:rum_sdk/src/data_collection_policy.dart';
import 'package:rum_sdk/src/transport/rum_base_transport.dart';
import 'package:rum_sdk/src/transport/task_buffer.dart';

class RUMTransport extends BaseTransport {
  RUMTransport({
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
        body: jsonEncode(payloadJson),
      );
    });
    if (response != null && response?.statusCode ~/ 100 != 2) {
      log(
        // ignore: lines_longer_than_80_chars
        'Error sending payload: ${response?.statusCode}, body: ${response?.body}',
      );
    }
  }
}
