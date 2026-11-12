import 'package:faro/src/offline_transport/offline_transport.dart';
import 'package:faro/src/transport/faro_base_transport.dart';
import 'package:faro/src/transport/faro_transport.dart';

/// Routes the primary collector through its outbox, preserving other sinks.
///
/// Only one outbox owns a batch. The collector must not also receive the same
/// batch directly, regardless of the ordering of configured transports.
List<BaseTransport> deliveryTransports(List<BaseTransport> transports) {
  final outbox = transports.whereType<OfflineTransport>().firstOrNull;
  if (outbox == null) return List<BaseTransport>.of(transports);
  final collector = transports.whereType<FaroTransport>().firstOrNull;
  return [
    outbox,
    for (final transport in transports)
      if (transport is! OfflineTransport && !identical(transport, collector))
        transport,
  ];
}
