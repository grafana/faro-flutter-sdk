import 'package:intl/intl.dart';

class Measurement {
  Map<String, dynamic>? values;
  String type = "";
  String timestamp = DateFormat('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'')
      .format(DateTime.now().toUtc());

  Measurement(this.values, this.type);

  Measurement.fromJson(dynamic json) {
    values = json['values'];
    type = json['type'];
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['values'] = values;
    map['type'] = type;
    map['timestamp'] = timestamp;
    return map;
  }
}
