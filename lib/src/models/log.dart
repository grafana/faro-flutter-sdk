import 'package:faro/src/models/user_action_context.dart';

class FaroLog {
  FaroLog(this.message, {this.level, this.context, this.trace});

  FaroLog.fromJson(dynamic json) {
    message = json['message'];
    level = json['level'];
    context = json['context'];
    timestamp = json['timestamp'];
    trace = json['trace'];
    if (json['action'] != null) {
      action = UserActionContext.fromJson(json['action']);
    }
  }
  String message = '';
  String? level = '';
  Map<String, dynamic>? context = {};
  Map<String, dynamic>? trace = {};
  UserActionContext? action;
  String timestamp = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['message'] = message;
    map['level'] = level;
    map['timestamp'] = timestamp;
    map['context'] = context;
    map['trace'] = trace;

    if (action != null) {
      map['action'] = action!.toJson();
    }

    return map;
  }
}
