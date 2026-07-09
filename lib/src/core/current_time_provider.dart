import 'package:dartypod/dartypod.dart';

/// Provides the current time.
typedef CurrentTimeProvider = DateTime Function();

/// Shared source of the current time, overridable in tests.
final currentTimeProvider = Provider<CurrentTimeProvider>((_) => DateTime.now);
