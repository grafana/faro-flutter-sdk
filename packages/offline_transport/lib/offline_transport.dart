import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rum_sdk/rum_sdk.dart';

class OfflineTransport extends BaseTransport {
  OfflineTransport({Duration? maxCacheDuration, required this.collectorUrl}) {
    _maxCacheDuration = maxCacheDuration;
    checkConnectivity();
    monitorConnectivity();
  }
  bool isOnline = true;
  Duration? _maxCacheDuration;
  String collectorUrl;
  @override
  Future<void> send(Map<String,dynamic> data) async {
    final payload = Payload.fromJson(data);
    if (!isOnline) {
      if (isPayloadEmpty(payload)) {
        return;
      }
      await writeToFile(payload);
    }
  }

  Future<void> checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    _handleConnectivity(connectivityResult);
  }
    Future<void> _handleConnectivity(List<ConnectivityResult> connectivityResult) async {
    if (connectivityResult.firstOrNull == ConnectivityResult.none) {
        isOnline = false;
    } else {
        isOnline = await _isConnectedToInternet();
     }
     
    if (isOnline) {
        await readFromFile();
    }
}
  Future<void>? monitorConnectivity() {
    Connectivity()
        .onConnectivityChanged
        .listen((result) async {
          _handleConnectivity(result);
    });
    return null;
  }

  Future<bool> _isConnectedToInternet() async {
    try {
      final result = await InternetAddress.lookup(collectorUrl);
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  bool isPayloadEmpty(Payload payload) {
    return payload.events.isEmpty &&
        payload.measurements.isEmpty &&
        payload.logs.isEmpty &&
        payload.exceptions.isEmpty;
  }

  Future<void> writeToFile(Payload payload) async {
    final file = await _getCacheFile();
    final logJson = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'payload': payload.toJson()
    };
    await file.writeAsString('${jsonEncode(logJson)}\n', mode: FileMode.append);
  }

  Future<void> readFromFile() async {
    final file = await _getCacheFile();
    if (!await file.exists()) {
      return;
    }
    if (await file.length() == 0) {
      return;
    }

    final lines = file
        .openRead()
        .transform(utf8.decoder) // Decode bytes to UTF-8.
        .transform(const LineSplitter()); // Convert stream to individual lines.

    final currentTime = DateTime.now().millisecondsSinceEpoch;

    await for (final line in lines) {
      if (line.trim().isEmpty) continue;

      int? timestamp;
      Payload? payload;
      try {
        final logJson = jsonDecode(line);
        timestamp = logJson['timestamp'];
        payload = Payload.fromJson(logJson['payload']);
      } catch (error) {
        log('Failed to parse log: $line\nWith error: $error');
      }

      if (timestamp == null || payload == null) {
        continue;
      }

      if (_maxCacheDuration != null &&
          currentTime - timestamp > _maxCacheDuration!.inMilliseconds) {
        continue;
      } else {
        await sendCachedData(payload);
      }
    }

  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final filepath = '${directory.path}/rum_log.json';
    if (!await File(filepath).exists()) {
      return File(filepath).create(recursive: true);
    }
    return File(filepath);
  }

  bool cachedDataExists() {
    return false;
  }

  Future<void> sendCachedData(Payload payload) async {
    for (final transport in RumFlutter().transports) {
      if (this != transport) {
        transport.send(payload.toJson());
      }
    }
  }
}
