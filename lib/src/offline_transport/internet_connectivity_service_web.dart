/// Web stub for [InternetConnectivityService].
///
/// This file is selected via conditional import in
/// `internet_connectivity_service.dart` on web targets. Since
/// [OfflineTransport] is unsupported on web (throws in its constructor),
/// these classes are never instantiated at runtime — they exist only to
/// satisfy the type system.
class InternetConnectivityService {
  InternetConnectivityService({
    required Object connectivity,
    required String internetConnectionCheckerUrl,
  }) {
    throw UnsupportedError(
      'InternetConnectivityService is not supported on Flutter web.',
    );
  }

  bool get isOnline => true;

  Stream<bool> get onConnectivityChanged => const Stream.empty();

  void dispose() {}
}

class InternetConnectivityServiceFactory {
  InternetConnectivityService create({
    String? internetConnectionCheckerUrl,
  }) {
    throw UnsupportedError(
      'InternetConnectivityServiceFactory is not supported on Flutter web.',
    );
  }
}
