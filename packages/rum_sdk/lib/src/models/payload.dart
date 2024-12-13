import 'package:rum_sdk/rum_sdk.dart';
import 'package:rum_sdk/src/models/models.dart';

class Payload {
  Payload(this.meta) {
    events = [];
  }

  Payload.fromJson(dynamic json) {
    if (json['events'] != null) {
      events = [];
      json['events'].forEach((dynamic v) {
        events.add(Event.fromJson(v));
      });
    }
    if (json['measurements'] != null) {
      measurements = [];
      json['measurements'].forEach((dynamic v) {
        measurements.add(Measurement.fromJson(v));
      });
    }
    if (json['logs'] != null) {
      logs = [];
      json['logs'].forEach((dynamic v) {
        logs.add(RumLog.fromJson(v));
      });
    }
    if (json['exceptions'] != null) {
      exceptions = [];
      json['exceptions'].forEach((dynamic v) {
        exceptions.add(RumException.fromJson(v));
      });
    }
    if (json['traces'] != null) {
      traces = Traces.fromJson(json['traces']);
    }
    meta = json['meta'] != null ? Meta.fromJson(json['meta']) : null;
  }
  List<Event> events = [];
  List<Measurement> measurements = [];
  List<RumLog> logs = [];
  List<RumException> exceptions = [];
  Traces traces = Traces();
  Meta? meta;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    if (events.isNotEmpty) {
      map['events'] = events.map((v) => v.toJson()).toList();
    }

    if (measurements.isNotEmpty) {
      map['measurements'] = measurements.map((v) => v.toJson()).toList();
    }

    if (logs.isNotEmpty) {
      map['logs'] = logs.map((v) => v.toJson()).toList();
    }

    if (exceptions.isNotEmpty) {
      map['exceptions'] = exceptions.map((v) => v.toJson()).toList();
    }

    if (traces.hasTraces()) {
      map['traces'] = traces.toJson();
    }

    if (meta != null) {
      map['meta'] = meta!.toJson();
    }
    return map;
  }
}
