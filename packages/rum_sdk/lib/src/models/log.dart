import 'package:intl/intl.dart';

class RumLog{

  RumLog(this.message, {this.level,this.context,this.trace});

  RumLog.fromJson(dynamic json) {
     message = json['message'];
    level = json['level'];
    context = json['context'];
    timestamp = json['timestamp'];
     trace = json['trace'];
  }
  String message = '';
  String? level = '';
  Map<String, dynamic>? context = {};
  Map<String, dynamic>? trace = {};
  String timestamp = DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['message'] = message;
    map['level'] = level;
    map['timestamp'] = timestamp;
    map['context'] = context;
    map['trace'] = trace;
    return map;
  }
}
