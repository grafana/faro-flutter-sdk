// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';
import 'dart:developer';

import 'package:intl/intl.dart';

class Measurement {
  Measurement(Map<String, dynamic>? inputValues, this.type) {
    values = _sanitizeValues(inputValues);
  }

  Measurement.fromJson(dynamic json) {
    values = _sanitizeValues(json['values']);
    type = json['type'];
    timestamp = json['timestamp'];
  }

  /// Sanitizes the input values to ensure they're JSON-encodable
  /// Tests each value with jsonEncode and replaces any non-encodable values
  Map<String, dynamic> _sanitizeValues(Map<String, dynamic>? inputValues) {
    if (inputValues == null) return {};

    final sanitizedValues = <String, dynamic>{};
    inputValues.forEach((key, value) {
      try {
        // Try to encode the value to verify it's JSON-compatible
        jsonEncode(value);
        sanitizedValues[key] = value;
      } catch (_) {
        // If encoding fails, handle based on value type
        if (value is double) {
          if (value.isNaN || value.isInfinite) {
            // Skip NaN and infinity values instead of replacing them
            log('Skipping non-encodable double value for key "$key": $value');
            // Don't add this key to sanitizedValues
          } else {
            // This shouldn't happen for regular doubles, but just in case
            log('Sanitizing unexpected non-encodable double for key "$key": $value');
            sanitizedValues[key] = 0.0;
          }
        } else {
          // For non-numeric types that can't be encoded, convert to string representation
          log('Converting non-encodable value for key "$key" of type ${value.runtimeType} to string');
          sanitizedValues[key] = value.toString();
        }
      }
    });
    return sanitizedValues;
  }

  Map<String, dynamic>? values;
  String type = '';
  String timestamp =
      DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").format(DateTime.now().toUtc());

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['values'] = values;
    map['type'] = type;
    map['timestamp'] = timestamp;
    return map;
  }
}
