import 'dart:convert';
import 'dart:core';
import 'package:intl/intl.dart';

class StackFrames {
  int colno = 0;
  int lineno = 0;
  String filename = "";
  String function = "";
  StackFrames(this.filename, this.function, this.lineno, this.colno);
  StackFrames.fromJson(dynamic json) {
    colno = json['colno'];
    lineno = json['lineno'];
    filename = json['filename'];
    function = json['function'];
  }
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['colno'] = colno;
    map['lineno'] = lineno;
    map['filename'] = filename;
    map['function'] = function;
    return map;
  }
}

class RumException {
  String type = "";
  String value = "";
  Map<String, dynamic> stacktrace = {};
  String trace = "";
  Map<String, String>? context = {};
  String timestamp = DateFormat('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
      .format(DateTime.now().toUtc());

  RumException(this.type, this.value, this.stacktrace, {this.context});

  RumException.fromJson(dynamic json) {
    type = json['type'];
    value = json['value'];
    stacktrace = json['stacktrace'];
    timestamp = json['timestamp'];
    context = json['context'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['type'] = type;
    map['value'] = value;
    map['stacktrace'] = stacktrace;
    map['timestamp'] = timestamp;
    map['context'] = context;
    return map;
  }

  static List<Map<String, dynamic>> stackTraceParse(StackTrace stacktrace) {
    LineSplitter ls = LineSplitter();
    List<String> stackFrames = ls.convert(stacktrace.toString());
    List<Map<String, dynamic>> parsedStackFrames = [];
    for (final stackFrame in stackFrames) {
      List<String> sf = stackFrame.split(" ");
      const pattern =
          ".*((?<module>[a-zA-Z]*):(?<filename>[a-zA-Z-_/.]*):(?<lineno>[0-9]*):(?<colno>[0-9]*)).*";
      final regExp = RegExp(pattern);
      RegExpMatch? regExpMatch = regExp.firstMatch(sf[sf.length - 1]);
      final filename =
          "${regExpMatch?.namedGroup("module")}:${regExpMatch?.namedGroup("filename")}";
      final lineno = regExpMatch?.namedGroup("lineno");
      final colno = regExpMatch?.namedGroup("colno");
      parsedStackFrames.add(StackFrames(filename, sf[sf.length - 2],
              int.parse(lineno ?? "0"), int.parse(colno ?? "0"))
          .toJson());
    }
    return parsedStackFrames;
  }
}
