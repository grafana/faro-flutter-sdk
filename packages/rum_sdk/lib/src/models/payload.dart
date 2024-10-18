import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/models/models.dart';
class Payload {
  List<Event> events = [];
  List<Measurement> measurements = [];
  List<RumLog> logs = [];
  List<RumException> exceptions = [];
  Meta? meta;

  Payload(this.meta) {
    events = [];
  }

  Payload.fromJson(dynamic json) {
    if (json['events'] != null) {
      events = [];
      json['events'].forEach((v) {
        events.add(Event.fromJson(v));
      });
    }
    if (json['measurements'] != null) {
      measurements = [];
      json['measurements'].forEach((v) {
        measurements.add(Measurement.fromJson(v));
      });
    }
    if (json['logs'] != null) {
      logs = [];
      json['logs'].forEach((v) {
        logs.add(RumLog.fromJson(v));
      });
    }
    if (json['exceptions'] != null) {
      exceptions = [];
      json['exceptions'].forEach((v) {
        exceptions.add(RumException.fromJson(v));
      });
    }
    meta = json['meta'] != null ? Meta.fromJson(json['meta']) : null;
  }



  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['events'] = events.map((v) => v.toJson()).toList();
    map['measurements'] = measurements.map((v) => v.toJson()).toList();
    map['logs'] = logs.map((v) => v.toJson()).toList();
    map['exceptions'] = exceptions.map((v) => v.toJson()).toList();

    if (meta != null) {
      map['meta'] = meta!.toJson();
    }
    return map;
  }

}