import 'dart:math';

/// Charset excluding visually ambiguous characters (l, I, O).
///
/// Matches the Faro Web SDK `genShortID` utility.
const _alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789';

final _random = Random();

/// Generates a short random ID string.
///
/// Defaults to 10 characters, matching the Faro Web SDK.
/// Used for user action IDs, session IDs, and HTTP request IDs.
String generateShortId([int length = 10]) {
  return String.fromCharCodes(
    Iterable.generate(
      length,
      (_) => _alphabet.codeUnitAt(_random.nextInt(_alphabet.length)),
    ),
  );
}
