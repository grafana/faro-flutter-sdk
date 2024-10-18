import 'package:intl/intl.dart';

class Event {
  String name = "";
  String domain = "flutter";
  Map<String, dynamic>? attributes = {};
  String timestamp = DateFormat('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'').format(DateTime.now().toUtc());

  Event(this.name, {this.attributes});

  Event.fromJson(dynamic json) {
    name = json['name'];
    domain = json['domain'];
    attributes = json['attributes'];
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['name'] = name;
    map['domain'] = domain;
    map['timestamp'] = timestamp;
    map['attributes'] = attributes;
    return map;
  }
}
