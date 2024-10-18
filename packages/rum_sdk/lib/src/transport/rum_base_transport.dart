import 'dart:async';
import 'package:rum_sdk/src/models/models.dart';

abstract class BaseTransport {
  Future<void> send(Map<String,dynamic> payload) async{}
}
