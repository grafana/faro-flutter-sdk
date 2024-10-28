import 'dart:async';

abstract class BaseTransport {
  Future<void> send(Map<String,dynamic> payload) async{}
}
