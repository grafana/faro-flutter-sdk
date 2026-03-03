import 'package:dartypod/dartypod.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/telemetry_item_dispatcher.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';

/// Routes telemetry to either active user-action buffer or transport.
class TelemetryRouter {
  TelemetryRouter({
    required BatchTransportResolver transportResolver,
    required UserActionsService userActionsService,
  })  : _transportResolver = transportResolver,
        _userActionsService = userActionsService;

  final BatchTransportResolver _transportResolver;
  final UserActionsService _userActionsService;

  /// Ingests a telemetry item and dispatches it according to routing
  /// rules.
  ///
  /// If [skipBuffer] is `false`, a bufferable item can be handed off
  /// to the active user action buffer. The action will enrich and
  /// flush it when the action ends.
  ///
  /// If [skipBuffer] is `true`, the item bypasses user action buffering
  /// and is dispatched to transport immediately.
  void ingest(TelemetryItem item, {bool skipBuffer = false}) {
    if (!skipBuffer &&
        _shouldBuffer(item.type) &&
        _userActionsService.tryBuffer(item)) {
      return;
    }

    final transport = _transportResolver();
    if (transport == null) {
      return;
    }

    TelemetryItemDispatcher.dispatch(item, transport);
  }

  bool _shouldBuffer(TelemetryItemType type) {
    return type == TelemetryItemType.event ||
        type == TelemetryItemType.log ||
        type == TelemetryItemType.exception;
  }
}

final telemetryRouterProvider = Provider((pod) {
  return TelemetryRouter(
    transportResolver: pod.resolve(batchTransportResolverProvider),
    userActionsService: pod.resolve(userActionsServiceProvider),
  );
});
