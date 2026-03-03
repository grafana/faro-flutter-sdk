import 'package:faro/src/models/user_action_context.dart';

class Event {
  Event(this.name, {this.attributes, this.trace});

  Event.fromJson(dynamic json) {
    name = json['name'];
    domain = json['domain'];
    attributes = json['attributes'];
    timestamp = json['timestamp'];
    trace = json['trace'];
    if (json['action'] != null) {
      action = UserActionContext.fromJson(json['action']);
    }
  }
  String name = '';
  String domain = 'flutter';
  Map<String, dynamic>? attributes = {};
  Map<String, dynamic>? trace = {};
  UserActionContext? action;
  String timestamp = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;
    map['domain'] = domain;
    map['timestamp'] = timestamp;
    map['attributes'] = attributes;

    if (trace != null) {
      map['trace'] = trace;
    }

    if (action != null) {
      map['action'] = action!.toJson();
    }

    return map;
  }
}
