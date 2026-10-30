import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_navigation_observer.dart';
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
  late Faro originalFaro;
  late _MockFaro faro;
  late _MockSessionManager sessionManager;
  late _MockSignalChannel signalChannel;
  late _RouteChanges changes;
  FaroNavigationObserver? observer;
  String? selectedView;
  late List<Map<String, dynamic>> events;

  FaroNavigationObserver attach() => FaroNavigationObserver.router(
    routeChanges: changes,
    viewNameExtractor: () => selectedView,
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
    observer = null;
    selectedView = '/home';
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
    observer?.dispose();
    changes.dispose();
    Faro.instance = originalFaro;
    pod.removeOverride(sessionManagerProvider);
    pod.removeOverride(userActionLifecycleSignalChannelProvider);
  });

  test('records an already resolved view when attached', () {
    observer = attach();
    expect(changes.hasAttachedListeners, isTrue);
    expect(events, [
      {'fromView': null, 'toView': '/home'},
    ]);
    verify(() => faro.setViewMeta(name: '/home')).called(1);
  });

  test('waits for an initial view when the router is not ready', () {
    selectedView = null;
    observer = attach();
    expect(events, isEmpty);
    selectedView = '/home';
    changes.notifyListeners();
    expect(events, [
      {'fromView': null, 'toView': '/home'},
    ]);
  });

  test('deduplicates repeated notifications of the same view', () {
    observer = attach();
    changes.notifyListeners();
    changes.notifyListeners();
    expect(events, hasLength(1));
  });

  test('skips null and empty names without losing the previous view', () {
    observer = attach();
    events.clear();
    selectedView = null;
    changes.notifyListeners();
    selectedView = '';
    changes.notifyListeners();
    expect(events, isEmpty);
    verifyNever(() => faro.setViewMeta());
    selectedView = '/about';
    changes.notifyListeners();
    expect(events, [
      {'fromView': '/home', 'toView': '/about'},
    ]);
  });

  test('allows callers to supply stable human-readable names', () {
    selectedView = 'Home';
    observer = attach();
    selectedView = 'Account';
    changes.notifyListeners();
    expect(events.last, {'fromView': 'Home', 'toView': 'Account'});
  });

  test('router changes remain meaningful session and user-action activity', () {
    observer = attach();
    selectedView = '/about';
    changes.notifyListeners();
    verify(
      () =>
          sessionManager.checkSession(activity: SessionActivityKind.meaningful),
    ).called(2);
    verify(
      () => signalChannel.emitActivity(source: 'navigation.router'),
    ).called(2);
  });

  test('Navigator callbacks cannot duplicate router-mode telemetry', () {
    observer = attach();
    events.clear();
    final route = PageRouteBuilder<void>(
      settings: const RouteSettings(name: '/ignored'),
      pageBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    observer?.didPush(route, null);
    observer?.didPop(route, null);
    observer?.didReplace(newRoute: route);
    expect(events, isEmpty);
    verifyNever(() => faro.setViewMeta(name: '/ignored'));
  });

  test('dispose removes the listener and is idempotent', () {
    observer = attach();
    events.clear();
    observer?.dispose();
    observer?.dispose();
    expect(changes.hasAttachedListeners, isFalse);
    selectedView = '/about';
    changes.notifyListeners();
    expect(events, isEmpty);
  });

  test('dispose preserves other listeners and the source notifier', () {
    var otherNotifications = 0;
    changes.addListener(() => otherNotifications++);
    observer = attach();
    observer?.dispose();
    changes.notifyListeners();
    expect(otherNotifications, 1);
    expect(changes.hasAttachedListeners, isTrue);
  });

  test('a new observer can attach after the previous one is disposed', () {
    observer = attach();
    observer?.dispose();
    events.clear();
    selectedView = '/about';
    observer = attach();
    expect(events, [
      {'fromView': null, 'toView': '/about'},
    ]);
    changes.notifyListeners();
    expect(events, hasLength(1));
  });

  test('initial extractor failure does not leave a router listener behind', () {
    expect(
      () => FaroNavigationObserver.router(
        routeChanges: changes,
        viewNameExtractor: () => throw StateError('invalid route'),
      ),
      throwsStateError,
    );
    expect(changes.hasAttachedListeners, isFalse);
  });
}
