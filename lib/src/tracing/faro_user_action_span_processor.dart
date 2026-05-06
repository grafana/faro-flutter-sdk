import 'package:dartypod/dartypod.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';
import 'package:opentelemetry/api.dart' as otel_api;
import 'package:opentelemetry/sdk.dart' as otel_sdk;

/// Resolves the currently active user action, if any.
typedef ActiveUserActionResolver = UserActionHandle? Function();

/// Span processor that enriches spans with user action context.
///
/// Wraps a delegate [otel_sdk.SpanProcessor] and, in [onStart], checks
/// whether a user action is active and in [UserActionState.started] state.
/// If so, sets `faro.action.user.name` and `faro.action.user.parentId`
/// on the span.
///
/// It also emits pending operation lifecycle signals for spans that have
/// [UserActionConstants.pendingOperationKey] set to `true`, using span ID as
/// operation ID.
class FaroUserActionSpanProcessor implements otel_sdk.SpanProcessor {
  FaroUserActionSpanProcessor({
    required otel_sdk.SpanProcessor delegate,
    required ActiveUserActionResolver activeUserActionResolver,
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  }) : _delegate = delegate,
       _activeUserActionResolver = activeUserActionResolver,
       _lifecycleSignalChannel = lifecycleSignalChannel;

  final otel_sdk.SpanProcessor _delegate;
  final ActiveUserActionResolver _activeUserActionResolver;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final Set<String> _pendingOperationSpanIds = <String>{};

  bool _isPendingOperationMarkerEnabled(dynamic value) => value == true;

  @override
  void onStart(otel_sdk.ReadWriteSpan span, otel_api.Context parentContext) {
    final pendingMarkerValue = span.attributes.get(
      UserActionConstants.pendingOperationKey,
    );
    if (_isPendingOperationMarkerEnabled(pendingMarkerValue)) {
      final operationId = span.spanContext.spanId.toString();
      _pendingOperationSpanIds.add(operationId);
      _lifecycleSignalChannel.emitPendingStart(
        source: 'span',
        operationId: operationId,
      );
    }

    final activeAction = _activeUserActionResolver();

    if (activeAction != null &&
        activeAction.getState() == UserActionState.started) {
      span.setAttribute(
        otel_api.Attribute.fromString(
          UserActionConstants.actionNameKey,
          activeAction.name,
        ),
      );
      span.setAttribute(
        otel_api.Attribute.fromString(
          UserActionConstants.actionParentIdKey,
          activeAction.id,
        ),
      );
    }

    _delegate.onStart(span, parentContext);
  }

  @override
  void onEnd(otel_sdk.ReadOnlySpan span) {
    final operationId = span.spanContext.spanId.toString();
    if (_pendingOperationSpanIds.remove(operationId)) {
      _lifecycleSignalChannel.emitPendingEnd(
        source: 'span',
        operationId: operationId,
      );
    }
    _delegate.onEnd(span);
  }

  @override
  void shutdown() {
    try {
      _delegate.shutdown();
    } finally {
      _pendingOperationSpanIds.clear();
    }
  }

  @override
  void forceFlush() => _delegate.forceFlush();
}

/// Provides a [FaroUserActionSpanProcessor] that wraps a
/// [otel_sdk.SimpleSpanProcessor] and enriches spans with user action context.
final faroSpanProcessorProvider = Provider<otel_sdk.SpanProcessor>((pod) {
  final exporter = FaroExporterFactory().create();
  final userActionsService = pod.resolve(userActionsServiceProvider);
  final lifecycleSignalChannel = pod.resolve(
    userActionLifecycleSignalChannelProvider,
  );
  return FaroUserActionSpanProcessor(
    delegate: otel_sdk.SimpleSpanProcessor(exporter),
    activeUserActionResolver: userActionsService.getActiveUserAction,
    lifecycleSignalChannel: lifecycleSignalChannel,
  );
});
