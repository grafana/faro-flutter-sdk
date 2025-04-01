// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'package:intl/intl.dart';

class StackFrames {
  StackFrames(this.filename, this.function, this.lineno, this.colno);
  StackFrames.fromJson(dynamic json) {
    colno = json['colno'];
    lineno = json['lineno'];
    filename = json['filename'];
    function = json['function'];
  }
  int colno = 0;
  int lineno = 0;
  String filename = '';
  String function = '';
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['colno'] = colno;
    map['lineno'] = lineno;
    map['filename'] = filename;
    map['function'] = function;
    return map;
  }
}

class FaroException {
  /// Create a FaroException with specified type, value, and optional stacktrace and context
  FaroException(this.type, this.value, this.stacktrace, {this.context});

  FaroException.fromJson(dynamic json) {
    type = json['type'];
    value = json['value'];
    timestamp = json['timestamp'];

    // Safely handle stacktrace - maintain as Map<String, dynamic>
    if (json['stacktrace'] != null && json['stacktrace'] is Map) {
      final Map<String, dynamic> rawStacktrace = json['stacktrace'];
      final parsedStacktrace = <String, dynamic>{};
      rawStacktrace.forEach((key, value) {
        parsedStacktrace[key] = value?.toString() ?? '';
      });
      stacktrace = parsedStacktrace;
    } else {
      stacktrace = null;
    }

    // Safely handle context to ensure it's Map<String, String>
    if (json['context'] != null && json['context'] is Map) {
      final Map<String, dynamic> rawContext = json['context'];
      final parsedContext = <String, String>{};
      rawContext.forEach((key, value) {
        parsedContext[key] = value?.toString() ?? '';
      });
      context = parsedContext;
    } else {
      context = null;
    }
  }

  /// Creates a FaroException from JSON, but returns null if required fields are missing
  /// or if there's a type mismatch in critical fields
  static FaroException? fromJsonOrNull(dynamic json) {
    // Check if required fields exist and build a list of missing fields
    final missingFields = <String>[];
    if (json['type'] == null) {
      missingFields.add('type');
    }
    if (json['value'] == null) {
      missingFields.add('value');
    }
    if (json['timestamp'] == null) {
      missingFields.add('timestamp');
    }
    if (missingFields.isNotEmpty) {
      log('Dropping exception with missing required fields: ${missingFields.join(', ')}');
      return null;
    }

    try {
      return FaroException.fromJson(json);
    } catch (e) {
      log('Error parsing FaroException from JSON: $e');
      return null;
    }
  }

  String type = '';
  String value = '';
  Map<String, dynamic>? stacktrace;
  String trace = '';
  Map<String, String>? context;
  String timestamp =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['type'] = type;
    map['value'] = value;
    map['timestamp'] = timestamp;
    if (stacktrace != null) {
      map['stacktrace'] = stacktrace;
    }
    if (context != null) {
      map['context'] = context;
    }
    return map;
  }

  static List<Map<String, dynamic>> stackTraceParse(StackTrace stacktrace) {
    const ls = LineSplitter();
    final stackFrames = ls.convert(stacktrace.toString());
    final parsedStackFrames = <Map<String, dynamic>>[];
    for (final stackFrame in stackFrames) {
      final sf = stackFrame.split(' ');
      const pattern =
          '.*((?<module>[a-zA-Z]*):(?<filename>[a-zA-Z-_/.]*):(?<lineno>[0-9]*):(?<colno>[0-9]*)).*';
      final regExp = RegExp(pattern);
      final regExpMatch = regExp.firstMatch(sf[sf.length - 1]);
      final filename =
          "${regExpMatch?.namedGroup("module")}:${regExpMatch?.namedGroup("filename")}";
      final lineno = regExpMatch?.namedGroup('lineno');
      final colno = regExpMatch?.namedGroup('colno');
      parsedStackFrames.add(StackFrames(filename, sf[sf.length - 2],
              int.parse(lineno ?? '0'), int.parse(colno ?? '0'))
          .toJson());
    }
    return parsedStackFrames;
  }
}
