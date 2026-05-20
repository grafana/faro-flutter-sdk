import 'dart:convert';

import 'package:faro_example/shared/models/demo_log_entry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

typedef NetworkRequestLogCallback =
    void Function(String message, {DemoLogTone tone});

final networkRequestsDemoServiceProvider = Provider<NetworkRequestsDemoService>(
  (ref) => const NetworkRequestsDemoService(),
);

/// Runs the network request demos shown in the example app.
class NetworkRequestsDemoService {
  const NetworkRequestsDemoService();

  Future<void> sendPostSuccess(NetworkRequestLogCallback log) async {
    await _runRequest(
      label: 'POST /post',
      expectedFailure: false,
      request: () {
        return http.post(
          Uri.parse('https://httpbin.io/post'),
          body: jsonEncode(<String, String>{'title': 'This is a title'}),
        );
      },
      log: log,
    );
  }

  Future<void> sendPostFailure(NetworkRequestLogCallback log) async {
    await _runRequest(
      label: 'POST /unstable',
      expectedFailure: true,
      request: () {
        return http.post(
          Uri.parse('https://httpbin.io/unstable'),
          body: jsonEncode(<String, String>{'title': 'This is a title'}),
        );
      },
      log: log,
    );
  }

  Future<void> sendGetSuccess(NetworkRequestLogCallback log) async {
    await _runRequest(
      label: 'GET /get?foo=bar',
      expectedFailure: false,
      request: () => http.get(Uri.parse('https://httpbin.io/get?foo=bar')),
      log: log,
    );
  }

  Future<void> sendGetFailure(NetworkRequestLogCallback log) async {
    await _runRequest(
      label: 'GET /unstable',
      expectedFailure: true,
      request: () => http.get(Uri.parse('https://httpbin.io/unstable')),
      log: log,
    );
  }

  Future<void> _runRequest({
    required String label,
    required bool expectedFailure,
    required Future<http.Response> Function() request,
    required NetworkRequestLogCallback log,
  }) async {
    log('$label -> sending request', tone: DemoLogTone.info);

    try {
      final response = await request();
      final isFailure = response.statusCode >= 400;
      final matchedExpectation = isFailure == expectedFailure;
      final tone = matchedExpectation
          ? DemoLogTone.success
          : DemoLogTone.warning;
      final expectationLabel = expectedFailure
          ? 'expected failure'
          : 'expected success';

      log(
        '$label -> status ${response.statusCode} ($expectationLabel)',
        tone: tone,
      );
    } catch (error) {
      log('$label -> threw $error', tone: DemoLogTone.error);
    }
  }
}
