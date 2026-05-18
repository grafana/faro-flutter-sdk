import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;
import 'package:dartypod/dartypod.dart';
import 'package:faro/src/tracing/faro_exporter.dart';
import 'package:faro/src/user_actions/constants.dart';
import 'package:faro/src/user_actions/user_action_handle.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:faro/src/user_actions/user_action_state.dart';
import 'package:faro/src/user_actions/user_actions_service.dart';

/// Resolves the currently active user action, if any.
typedef ActiveUserActionResolver = UserActionHandle? Function();

/// Span processor that enriches spans with user action context.
///
/// Wraps a delegate [otel.SpanProcessor] and, in [onStart], checks
/// whether a user action is active and in [UserActionState.started] state.
/// If so, sets `faro.action.user.name` and `faro.action.user.parentId`
/// on the span.
///
/// It also emits pending operation lifecycle signals for spans that have
/// [UserActionConstants.pendingOperationKey] set to `true`, using span ID as
/// operation ID.
class FaroUserActionSpanProcessor implements otel.SpanProcessor {
  FaroUserActionSpanProcessor({
    required otel.SpanProcessor delegate,
    required ActiveUserActionResolver activeUserActionResolver,
    required UserActionLifecycleSignalChannel lifecycleSignalChannel,
  }) : _delegate = delegate,
       _activeUserActionResolver = activeUserActionResolver,
       _lifecycleSignalChannel = lifecycleSignalChannel;

  final otel.SpanProcessor _delegate;
  final ActiveUserActionResolver _activeUserActionResolver;
  final UserActionLifecycleSignalChannel _lifecycleSignalChannel;
  final Set<String> _pendingOperationSpanIds = <String>{};

  bool _isPendingOperationMarkerEnabled(dynamic value) => value == true;

  @override
  Future<void> onStart(otel.Span span, otel.Context? parentContext) async {
    // ignore: invalid_use_of_visible_for_testing_member
    final pendingMarkerValue = span.attributes.getBool(
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
      span.setStringAttribute<String>(
        UserActionConstants.actionNameKey,
        activeAction.name,
      );
      span.setStringAttribute<String>(
        UserActionConstants.actionParentIdKey,
        activeAction.id,
      );
    }

    await _delegate.onStart(span, parentContext);
  }

  @override
  Future<void> onEnd(otel.Span span) async {
    final operationId = span.spanContext.spanId.toString();
    if (_pendingOperationSpanIds.remove(operationId)) {
      _lifecycleSignalChannel.emitPendingEnd(
        source: 'span',
        operationId: operationId,
      );
    }
    await _delegate.onEnd(span);
  }

  @override
  Future<void> onNameUpdate(otel.Span span, String newName) =>
      _delegate.onNameUpdate(span, newName);

  @override
  Future<void> shutdown() async {
    try {
      await _delegate.shutdown();
    } finally {
      _pendingOperationSpanIds.clear();
    }
  }

  @override
  Future<void> forceFlush() => _delegate.forceFlush();
}

/// Provides a [FaroUserActionSpanProcessor] that wraps a
/// [otel.SimpleSpanProcessor] and enriches spans with user action context.
final faroSpanProcessorProvider = Provider<otel.SpanProcessor>((pod) {
  final exporter = FaroExporterFactory().create();
  final userActionsService = pod.resolve(userActionsServiceProvider);
  final lifecycleSignalChannel = pod.resolve(
    userActionLifecycleSignalChannelProvider,
  );
  return FaroUserActionSpanProcessor(
    delegate: otel.SimpleSpanProcessor(exporter),
    activeUserActionResolver: userActionsService.getActiveUserAction,
    lifecycleSignalChannel: lifecycleSignalChannel,
  );
});
