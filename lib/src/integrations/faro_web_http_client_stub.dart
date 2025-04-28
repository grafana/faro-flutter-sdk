import 'package:http/http.dart';

class FaroWebHttpClient extends BaseClient {
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    throw UnsupportedError(
        'FaroWebHttpClient stub should not be used on this platform.');
  }

  @override
  void close() {
    // No-op
  }
}

Client createFaroWebHttpClient() => FaroWebHttpClient();
