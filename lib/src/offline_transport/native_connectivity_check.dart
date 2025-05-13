import 'dart:async';
import 'dart:io';

Future<bool> performNativeInternetCheck(String host) async {
  try {
    final result = await InternetAddress.lookup(host);
    return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
  } on SocketException catch (_) {
    return false;
  } catch (_) {
    return false;
  }
}
