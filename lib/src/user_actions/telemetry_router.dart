import 'package:dartypod/dartypod.dart';
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/transport/batch_transport.dart';
import 'package:faro/src/user_actions/telemetry_item_dispatcher.dart';
import 'package:faro/src/user_actions/user_action_types.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';

/// Routes telemetry to either active user-action buffer or transport.
class TelemetryRouter {
  TelemetryRouter({
    required BatchTransportResolver transportResolver,
    required UserActionsService userActionsService,
    required SessionManager sessionManager,
  }) : _transportResolver = transportResolver,
       _userActionsService = userActionsService,
       _sessionManager = sessionManager;

  final BatchTransportResolver _transportResolver;
  final UserActionsService _userActionsService;
  final SessionManager _sessionManager;

  /// Ingests a telemetry item and dispatches it according to routing
  /// rules.
  ///
  /// If [skipBuffer] is `false`, a bufferable item can be handed off
  /// to the active user action buffer. The action will enrich and
  /// flush it when the action ends.
  ///
  /// If [skipBuffer] is `true`, the item bypasses user action buffering
  /// and is dispatched to transport immediately.
  ///
  /// [activity] classifies how this item affects the session inactivity
  /// window (see [SessionActivityKind]).
  void ingest(
    TelemetryItem item, {
    bool skipBuffer = false,
    SessionActivityKind activity = SessionActivityKind.active,
  }) {
    _sessionManager.checkSession(activity: activity);

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

final telemetryRouterProvider = Provider<TelemetryRouter>(
  (pod) => TelemetryRouter(
    userActionsService: pod.resolve(userActionsServiceProvider),
    transportResolver: pod.resolve(batchTransportResolverProvider),
    sessionManager: pod.resolve(sessionManagerProvider),
  ),
  scope: faroInitScope,
);
