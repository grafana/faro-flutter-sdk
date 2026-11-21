/// Configures the persistent outbox in front of the primary collector.
///
/// When [enabled], the primary collector saves each completed batch on disk
/// before sending it, and retries temporary failures across restarts. The
/// primary collector is the `FaroTransport` created from
/// `FaroConfig.collectorUrl`, or the first one in `FaroConfig.transports`.
/// Other transports keep receiving live batches only.
///
/// The option is ignored on web, which sends directly.
class OfflineStorageConfig {
  /// Creates an offline storage configuration. Every limit must be positive;
  /// `Faro().init` throws an [ArgumentError] otherwise.
  const OfflineStorageConfig({
    this.enabled = false,
    this.maxAge = const Duration(days: 3),
    this.maxCount = 1000,
    this.maxBytes = 10 * 1024 * 1024,
  }) : assert(maxCount > 0, 'maxCount must be positive'),
       assert(maxBytes > 0, 'maxBytes must be positive');

  /// Whether batches are saved before delivery. Off by default.
  final bool enabled;

  /// How long a saved batch is kept, measured from when it was saved.
  final Duration maxAge;

  /// The maximum number of saved batches. The oldest are evicted first.
  final int maxCount;

  /// The maximum total size of saved batches in bytes, including each
  /// batch's small storage envelope. The oldest are evicted first.
  final int maxBytes;
}
