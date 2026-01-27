/// Represents a key-value attribute for OpenTelemetry traces.
///
/// Each attribute has a key and a typed value that can be a string, int,
/// double, or bool. This follows the OTLP specification for attribute values.
class TraceAttribute {
  TraceAttribute({
    required String key,
    required TraceAttributeValue value,
  })  : _key = key,
        _value = value;

  TraceAttribute.fromJson(dynamic json) {
    if (json['key'] != null) {
      _key = json['key'];
    }
    if (json['value'] != null) {
      _value = TraceAttributeValue.fromJson(json['value']);
    }
  }

  String? _key;
  TraceAttributeValue? _value;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_key != null && _value != null) {
      map['key'] = _key;
      map['value'] = _value!.toJson();
    }
    return map;
  }
}

/// Represents a typed attribute value following the OTLP specification.
///
/// Supports the following value types:
/// - `stringValue`: String values
/// - `intValue`: Integer values (int64)
/// - `doubleValue`: Double/float values
/// - `boolValue`: Boolean values
///
/// Only one value type should be set per instance. Use the named constructors
/// to create instances with the appropriate type.
class TraceAttributeValue {
  /// Creates a TraceAttributeValue with a string value.
  ///
  /// This is the legacy constructor maintained for backward compatibility.
  TraceAttributeValue({required String stringValue})
      : _stringValue = stringValue,
        _intValue = null,
        _doubleValue = null,
        _boolValue = null;

  /// Creates a TraceAttributeValue with a string value.
  TraceAttributeValue.string(String value)
      : _stringValue = value,
        _intValue = null,
        _doubleValue = null,
        _boolValue = null;

  /// Creates a TraceAttributeValue with an integer value.
  TraceAttributeValue.int(int value)
      : _stringValue = null,
        _intValue = value,
        _doubleValue = null,
        _boolValue = null;

  /// Creates a TraceAttributeValue with a double value.
  TraceAttributeValue.double(double value)
      : _stringValue = null,
        _intValue = null,
        _doubleValue = value,
        _boolValue = null;

  /// Creates a TraceAttributeValue with a boolean value.
  // ignore: avoid_positional_boolean_parameters
  TraceAttributeValue.bool(bool value)
      : _stringValue = null,
        _intValue = null,
        _doubleValue = null,
        _boolValue = value;

  /// Creates a TraceAttributeValue from a dynamic value.
  ///
  /// The type is inferred from the runtime type of [value]:
  /// - String -> stringValue
  /// - int -> intValue
  /// - double -> doubleValue
  /// - bool -> boolValue
  /// - Other types -> converted to string via toString()
  factory TraceAttributeValue.fromDynamic(dynamic value) {
    if (value is String) {
      return TraceAttributeValue.string(value);
    } else if (value is int) {
      return TraceAttributeValue.int(value);
    } else if (value is double) {
      return TraceAttributeValue.double(value);
    } else if (value is bool) {
      return TraceAttributeValue.bool(value);
    } else {
      // Fallback: convert to string for unsupported types
      return TraceAttributeValue.string(value.toString());
    }
  }

  /// Creates a TraceAttributeValue from JSON.
  ///
  /// Supports deserializing any of the typed value fields:
  /// `stringValue`, `intValue`, `doubleValue`, `boolValue`.
  TraceAttributeValue.fromJson(dynamic json)
      : _stringValue = json['stringValue'] as String?,
        _intValue = json['intValue'] as int?,
        _doubleValue = _parseDouble(json['doubleValue']),
        _boolValue = json['boolValue'] as bool?;

  final String? _stringValue;
  final int? _intValue;
  final double? _doubleValue;
  final bool? _boolValue;

  /// The string value, if this attribute holds a string.
  String? get stringValue => _stringValue;

  /// The integer value, if this attribute holds an integer.
  int? get intValue => _intValue;

  /// The double value, if this attribute holds a double.
  double? get doubleValue => _doubleValue;

  /// The boolean value, if this attribute holds a boolean.
  bool? get boolValue => _boolValue;

  /// Serializes this attribute value to JSON.
  ///
  /// Only the non-null value field is included in the output,
  /// following the OTLP specification.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (_stringValue != null) {
      map['stringValue'] = _stringValue;
    } else if (_intValue != null) {
      map['intValue'] = _intValue;
    } else if (_doubleValue != null) {
      map['doubleValue'] = _doubleValue;
    } else if (_boolValue != null) {
      map['boolValue'] = _boolValue;
    }
    return map;
  }

  /// Helper to parse double values that might come as int from JSON.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return null;
  }
}
