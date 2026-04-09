import 'package:dartypod/dartypod.dart';

/// Determines whether an HTTP request should be instrumented.
///
/// Before [configure] is called (i.e. before Faro initialization),
/// all URLs are tracked by default. During Faro initialization this
/// is configured with the collector URL and any user-defined ignore
/// patterns from [FaroConfig.ignoreUrls].
class HttpTrackingFilter {
  String? _collectorUrl;
  List<RegExp> _ignorePatterns = const [];

  /// Configures the filter with the resolved Faro configuration.
  ///
  /// Called once during Faro initialization.
  void configure({
    required String? collectorUrl,
    required List<RegExp>? ignoreUrls,
  }) {
    _collectorUrl = collectorUrl;
    _ignorePatterns = ignoreUrls ?? const [];
  }

  /// Returns `true` if the given [url] should be instrumented
  /// (OTel span, user action signals, Faro measurement).
  bool shouldTrack(Uri url) {
    final urlString = url.toString();
    if (_collectorUrl != null && urlString == _collectorUrl) {
      return false;
    }
    if (_ignorePatterns.any((pattern) => pattern.hasMatch(urlString))) {
      return false;
    }
    return true;
  }
}

final httpTrackingFilterProvider = Provider<HttpTrackingFilter>(
  (_) => HttpTrackingFilter(),
);
