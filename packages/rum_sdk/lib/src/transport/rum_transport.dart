import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:rum_sdk/src/data_collection_policy.dart';
import 'package:rum_sdk/src/transport/rum_base_transport.dart';
import 'package:rum_sdk/src/transport/task_buffer.dart';
import 'package:rum_sdk/src/models/payload.dart';

class RUMTransport extends BaseTransport {
  final String collectorUrl;
  final String apiKey;
  final String? sessionId;
  TaskBuffer<dynamic>? _taskBuffer;

  RUMTransport({
    required this.collectorUrl,
    required this.apiKey,
    this.sessionId,
    maxBufferLimit = 30,
  }) {
    _taskBuffer = TaskBuffer(maxBufferLimit);
  }

  @override
  Future<void> send(Map<String, dynamic> payload) async {
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
        body: jsonEncode(payload),
      );
    });
    if (response != null && response?.statusCode ~/ 100 != 2) {
      log(
        'Error sending payload: ${response?.statusCode}, body: ${response?.body}',
      );
    }
  }
}
