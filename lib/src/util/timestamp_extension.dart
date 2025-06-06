// ignore_for_file: lines_longer_than_80_chars

extension TimestampExtension on String {
  /// Converts a Unix epoch timestamp (in milliseconds) to a human-readable UTC ISO 8601 string.
  ///
  /// Returns the ISO 8601 formatted string if successful, or an error message if parsing fails.
  ///
  /// Example:
  /// ```dart
  /// final timestamp = "1749080960296";
  /// final readable = timestamp.toHumanReadableTimestamp();
  /// // Returns: "2025-06-06T14:42:40.296Z"
  /// ```
  String toHumanReadableTimestamp() {
    if (this == 'No timestamp') {
      return 'No readable timestamp';
    }

    try {
      final timestampMs = int.parse(this);
      final dateTime =
          DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
      return dateTime.toIso8601String();
    } catch (error) {
      return 'Invalid timestamp format';
    }
  }
}
