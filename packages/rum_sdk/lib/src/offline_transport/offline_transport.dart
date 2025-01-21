// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/offline_transport/internet_connectivity_service.dart';
import 'package:rum_sdk/src/util/payload_extension.dart';

class OfflineTransport extends BaseTransport {
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) : _connectivityService = internetConnectivityService ??
            InternetConnectivityServiceFactory().create(
                internetConnectionCheckerUrl: internetConnectionCheckerUrl) {
    _maxCacheDuration = maxCacheDuration;

    _connectivityService.onConnectivityChanged.listen((isOnline) {
      if (isOnline) {
        try {
          _readFromFile();
        } catch (error, stackTrace) {
          log(
            'OfflineTransport: Failed to read cached data from file.',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    });
  }

  Duration? _maxCacheDuration;
  final InternetConnectivityService _connectivityService;

  // File operation lock to prevent concurrent access
  Completer<void> _fileLock = Completer<void>()..complete();

  Future<T> _withFileLock<T>(Future<T> Function() operation) async {
    final currentLock = _fileLock;
    _fileLock = Completer<void>();
    try {
      await currentLock.future;
      final result = await operation();
      _fileLock.complete();
      return result;
    } catch (e) {
      _fileLock.complete();
      rethrow;
    }
  }

  @override
  Future<void> send(Map<String, dynamic> payloadJson) async {
    final payload = Payload.fromJson(payloadJson);
    if (!_connectivityService.isOnline) {
      if (payload.isEmpty()) {
        return;
      }
      try {
        await _writeToFile(payload);
      } catch (error, stackTrace) {
        log(
          'OfflineTransport: Failed to write payload to file.',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }

  Future<void> _writeToFile(Payload payload) async {
    await _withFileLock(() async {
      final file = await _getCacheFile();
      final logJson = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload.toJson()
      };
      await file.writeAsString('${jsonEncode(logJson)}\n',
          mode: FileMode.append, flush: true);
    });
  }

  Future<void> _readFromFile() async {
    await _withFileLock(() async {
      final file = await _getCacheFile();
      // ignore: avoid_slow_async_io
      if (!await file.exists() || await file.length() == 0) {
        return;
      }

      final failedLines = <String>[];
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      await for (final line in file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;

        final logJson = _parseJsonSafely(line);
        if (logJson == null) {
          log('OfflineTransport: Failed to parse cached data to json. Skipping this payload.');
          continue;
        }

        final timestamp = logJson['timestamp'] as int?;
        final payload = Payload.fromJson(logJson['payload']);

        if (timestamp == null) {
          log('OfflineTransport: Failed to parse timestamp in payload. Skipping this payload.');
          continue;
        }

        if (_maxCacheDuration != null &&
            currentTime - timestamp > _maxCacheDuration!.inMilliseconds) {
          continue;
        }
        final sendSuccess = await _sendCachedData(payload);
        if (!sendSuccess) {
          failedLines.add(line);
        }
      }

      // Updated cached log files on disk. Remove all successfully sent logs.
      // And put back only the failed logs.
      var updatedFileContent = '';
      if (failedLines.isNotEmpty) {
        updatedFileContent = '${failedLines.join('\n')}\n';
      }
      await file.writeAsString(updatedFileContent, flush: true);
    });
  }

  Map<String, dynamic>? _parseJsonSafely(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (error) {
      // Return null if parsing fails
      return null;
    }
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filepath = '${directory.path}/rum_log.json';
    // ignore: avoid_slow_async_io
    if (!await File(filepath).exists()) {
      return File(filepath).create(recursive: true);
    }
    return File(filepath);
  }

  Future<bool> _sendCachedData(Payload payload) async {
    try {
      for (final transport in RumFlutter().transports) {
        if (this != transport) {
          await transport.send(payload.toJson());
        }
      }
      return true;
    } catch (error, stackTrace) {
      log(
        'OfflineTransport: Failed to send cached payload: $payload.',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  }
}
