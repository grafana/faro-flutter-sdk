// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:faro/src/faro.dart';
import 'package:faro/src/models/models.dart';
import 'package:faro/src/offline_transport/internet_connectivity_service.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/util/payload_extension.dart';
import 'package:path_provider/path_provider.dart';

class OfflineTransport extends BaseTransport {
  OfflineTransport({
    Duration? maxCacheDuration,
    String? internetConnectionCheckerUrl,
    InternetConnectivityService? internetConnectivityService,
  }) : _connectivityService =
           internetConnectivityService ??
           InternetConnectivityServiceFactory().create(
             internetConnectionCheckerUrl: internetConnectionCheckerUrl,
           ),
       _maxCacheDuration = maxCacheDuration {
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

  final Duration? _maxCacheDuration;
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

  /// Writes the payload to the cache file.
  ///
  /// Failure policy: payloads that cannot be JSON-encoded (for example a
  /// user-supplied attribute containing a [DateTime], a custom object, or a
  /// non-finite double) are dropped. A payload that cannot be encoded for
  /// the cache could not be encoded for upload to the collector later
  /// either, so dropping it keeps the cache consistent with what online
  /// delivery accepts.
  Future<void> _writeToFile(Payload payload) async {
    await _withFileLock(() async {
      final logJson = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'payload': payload.toJson(),
      };
      final encodedLogJson = _encodeJsonSafely(logJson);
      if (encodedLogJson == null) {
        return;
      }
      final file = await _getCacheFile();
      await file.writeAsString(
        '$encodedLogJson\n',
        mode: FileMode.append,
        flush: true,
      );
    });
  }

  /// Encodes [json] to a JSON string, or returns null if encoding fails.
  ///
  /// Diagnostics only mention value/error types, never the values
  /// themselves, to avoid leaking potentially sensitive payload data.
  String? _encodeJsonSafely(Map<String, dynamic> json) {
    try {
      return jsonEncode(json);
    } catch (error) {
      var details = error.runtimeType.toString();
      if (error is JsonUnsupportedObjectError) {
        details =
            'unsupported value of type '
            '${error.unsupportedObject.runtimeType}';
      }
      log(
        'OfflineTransport: Failed to JSON-encode payload ($details). '
        'Dropping this payload.',
      );
      return null;
    }
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

      await for (final line
          in file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;

        final logJson = _parseJsonSafely(line);
        if (logJson == null) {
          log(
            'OfflineTransport: Failed to parse cached data to json. Skipping this payload.',
          );
          continue;
        }

        final timestamp = logJson['timestamp'];
        if (timestamp is! int) {
          log(
            'OfflineTransport: Failed to parse timestamp in payload. Skipping this payload.',
          );
          continue;
        }

        final payload = _parsePayloadSafely(logJson['payload']);
        if (payload == null) {
          log(
            'OfflineTransport: Failed to parse cached payload. Skipping this payload.',
          );
          continue;
        }

        if (_maxCacheDuration != null &&
            currentTime - timestamp > _maxCacheDuration.inMilliseconds) {
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

  /// Parses a cached payload, or returns null if parsing fails.
  ///
  /// Corrupt cache entries must not break processing of the remaining
  /// entries, so failures are swallowed and the entry is dropped.
  Payload? _parsePayloadSafely(dynamic payloadJson) {
    try {
      return Payload.fromJson(payloadJson);
    } catch (error) {
      // Return null if parsing fails.
      return null;
    }
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
      for (final transport in Faro().transports) {
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
