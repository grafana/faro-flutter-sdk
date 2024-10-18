import 'dart:math';

String generateSessionID(){
  const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final Random rnd = Random();
  const length = 10;

  return String.fromCharCodes(Iterable.generate(
    length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
  ));

}