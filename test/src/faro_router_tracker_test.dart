import 'package:faro/faro.dart' show FaroRouterTracker;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_router_tracker.dart'
    show routerTrackerErrorLoggerProvider;
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFaro extends Mock implements Faro {}

class _MockSessionManager extends Mock implements SessionManager {}

class _MockSignalChannel extends Mock
    implements UserActionLifecycleSignalChannel {}

class _RouteChanges extends ChangeNotifier {
  bool get hasAttachedListeners => hasListeners;
}

void main() {
  group('FaroRouterTracker:', () {
    late Faro originalFaro;
    late _MockFaro faro;
    late _MockSessionManager sessionManager;
    late _MockSignalChannel signalChannel;
    late _RouteChanges changes;
    FaroRouterTracker? tracker;
    String? selectedView;
    Error? extractorError;
    late List<Object> extractorErrors;
    late List<Map<String, dynamic>> events;

    void recordExtractorError(Object error, StackTrace stackTrace) {
      extractorErrors.add(error);
    }

    FaroRouterTracker attach() => FaroRouterTracker(
      routeChanges: changes,
      viewNameExtractor: () {
        final error = extractorError;
        if (error != null) throw error;
        return selectedView;
      },
    );

    setUpAll(() {
      registerFallbackValue(SessionActivityKind.meaningful);
    });

    setUp(() {
      originalFaro = Faro();
      faro = _MockFaro();
      sessionManager = _MockSessionManager();
      signalChannel = _MockSignalChannel();
      Faro.instance = faro;
      pod.overrideProvider(sessionManagerProvider, (_) => sessionManager);
      pod.overrideProvider(
        userActionLifecycleSignalChannelProvider,
        (_) => signalChannel,
      );
      changes = _RouteChanges();
      tracker = null;
      selectedView = '/home';
      extractorError = null;
      extractorErrors = [];
      pod.overrideProvider(
        routerTrackerErrorLoggerProvider,
        (_) => recordExtractorError,
      );
      events = [];
      when(() => faro.setViewMeta(name: any(named: 'name'))).thenReturn(null);
      when(
        () => faro.pushEvent(any(), attributes: any(named: 'attributes')),
      ).thenAnswer((call) {
        events.add(
          Map<String, dynamic>.from(call.namedArguments[#attributes] as Map),
        );
      });
    });

    tearDown(() {
      tracker?.dispose();
      changes.dispose();
      Faro.instance = originalFaro;
      pod.removeOverride(sessionManagerProvider);
      pod.removeOverride(routerTrackerErrorLoggerProvider);
      pod.removeOverride(userActionLifecycleSignalChannelProvider);
    });

    test('records an already resolved view when attached', () {
      tracker = attach();
      expect(changes.hasAttachedListeners, isTrue);
      expect(events, [
        {'fromView': null, 'toView': '/home'},
      ]);
      verify(() => faro.setViewMeta(name: '/home')).called(1);
    });

    test('waits for an initial view when the router is not ready', () {
      selectedView = null;
      tracker = attach();
      expect(events, isEmpty);
      selectedView = '/home';
      changes.notifyListeners();
      expect(events, [
        {'fromView': null, 'toView': '/home'},
      ]);
    });

    test('deduplicates repeated notifications of the same view', () {
      tracker = attach();
      changes.notifyListeners();
      changes.notifyListeners();
      expect(events, hasLength(1));
      verify(
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(3);
      verify(
        () => signalChannel.emitActivity(source: 'navigation.router'),
      ).called(3);
    });

    test('skips null and empty names without losing the previous view', () {
      tracker = attach();
      events.clear();
      selectedView = null;
      changes.notifyListeners();
      selectedView = '';
      changes.notifyListeners();
      expect(events, isEmpty);
      verifyNever(() => faro.setViewMeta());
      verify(
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(3);
      verify(
        () => signalChannel.emitActivity(source: 'navigation.router'),
      ).called(3);
      selectedView = '/about';
      changes.notifyListeners();
      expect(events, [
        {'fromView': '/home', 'toView': '/about'},
      ]);
    });

    test('allows callers to supply stable human-readable names', () {
      selectedView = 'Home';
      tracker = attach();
      selectedView = 'Account';
      changes.notifyListeners();
      expect(events.last, {'fromView': 'Home', 'toView': 'Account'});
    });

    test(
      'router changes remain meaningful session and user-action activity',
      () {
        tracker = attach();
        selectedView = '/about';
        changes.notifyListeners();
        verify(
          () => sessionManager.checkSession(
            activity: SessionActivityKind.meaningful,
          ),
        ).called(2);
        verify(
          () => signalChannel.emitActivity(source: 'navigation.router'),
        ).called(2);
      },
    );

    test('dispose removes the listener and is idempotent', () {
      tracker = attach();
      events.clear();
      tracker?.dispose();
      tracker?.dispose();
      expect(changes.hasAttachedListeners, isFalse);
      selectedView = '/about';
      changes.notifyListeners();
      expect(events, isEmpty);
    });

    test('dispose preserves other listeners and the source notifier', () {
      var otherNotifications = 0;
      changes.addListener(() => otherNotifications++);
      tracker = attach();
      tracker?.dispose();
      changes.notifyListeners();
      expect(otherNotifications, 1);
      expect(changes.hasAttachedListeners, isTrue);
    });

    test('a new tracker can attach after the previous one is disposed', () {
      tracker = attach();
      tracker?.dispose();
      events.clear();
      selectedView = '/about';
      tracker = attach();
      expect(events, [
        {'fromView': null, 'toView': '/about'},
      ]);
      changes.notifyListeners();
      expect(events, hasLength(1));
    });

    test('initial extractor failure skips the view and recovers', () {
      extractorError = StateError('router not ready');
      tracker = attach();
      expect(changes.hasAttachedListeners, isTrue);
      expect(events, isEmpty);
      expect(extractorErrors, [extractorError]);
      verify(
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
      verify(
        () => signalChannel.emitActivity(source: 'navigation.router'),
      ).called(1);

      extractorError = null;
      changes.notifyListeners();
      expect(events, [
        {'fromView': null, 'toView': '/home'},
      ]);
      tracker?.dispose();
      expect(changes.hasAttachedListeners, isFalse);
    });

    test('later extractor failure preserves the view and activity', () {
      tracker = attach();
      events.clear();
      clearInteractions(faro);
      extractorError = StateError('route lookup failed');
      changes.notifyListeners();
      expect(events, isEmpty);
      verifyNever(() => faro.setViewMeta(name: any(named: 'name')));
      verify(
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(2);
      verify(
        () => signalChannel.emitActivity(source: 'navigation.router'),
      ).called(2);

      extractorError = null;
      selectedView = '/about';
      changes.notifyListeners();
      expect(events, [
        {'fromView': '/home', 'toView': '/about'},
      ]);
    });

    test(
      'logs once per failure period and resets after the same view recovers',
      () {
        tracker = attach();
        final firstError = StateError('first failure');
        extractorError = firstError;
        changes.notifyListeners();
        changes.notifyListeners();
        expect(extractorErrors, [firstError]);

        extractorError = null;
        changes.notifyListeners();
        expect(events, hasLength(1));
        final nextError = StateError('failure after recovery');
        extractorError = nextError;
        changes.notifyListeners();
        changes.notifyListeners();
        expect(extractorErrors, [firstError, nextError]);
        expect(events, hasLength(1));
        verify(
          () => sessionManager.checkSession(
            activity: SessionActivityKind.meaningful,
          ),
        ).called(6);
        verify(
          () => signalChannel.emitActivity(source: 'navigation.router'),
        ).called(6);
      },
    );

    test('a successful skipped name also resets failure logging', () {
      extractorError = StateError('initial failure');
      tracker = attach();
      extractorError = null;
      selectedView = null;
      changes.notifyListeners();
      extractorError = StateError('later failure');
      changes.notifyListeners();
      expect(extractorErrors, hasLength(2));
      expect(events, isEmpty);
    });
  });
}
