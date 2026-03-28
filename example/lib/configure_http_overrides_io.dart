import 'dart:io';

import 'package:faro/faro.dart';

/// Sets [FaroHttpOverrides] as the global HTTP override on mobile.
///
/// IMPORTANT: Call this BEFORE creating any `http.Client` instances.
/// The http package uses IOClient on mobile, which creates an HttpClient at
/// construction time. If HttpOverrides is set after the client is created,
/// Faro won't intercept those HTTP requests.
void configureHttpOverrides() {
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);
}
