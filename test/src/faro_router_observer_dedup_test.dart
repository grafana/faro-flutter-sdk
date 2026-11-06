import 'package:faro/faro.dart' show FaroNavigationObserver, FaroRouterTracker;
import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_navigation_observer.dart'
    show navigationObserverDeferralLoggerProvider;
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:faro/src/user_actions/user_action_lifecycle_signal_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFaro extends Mock implements Faro {}

class _MockSessionManager extends Mock implements SessionManager {}

/// Observer page names are route names (`a`), tracker names are full paths
/// (`/a`), so each event shows which side emitted it.
void main() {
  late Faro originalFaro;
  late _MockFaro faro;
  late _MockSessionManager sessionManager;
  late List<Map<String, dynamic>> events;
  late int deferralLogs;
  late List<String?> viewMetaNames;
  late List<String> activitySources;
  late UserActionLifecycleSignalChannel signalChannel;
  final trackers = <FaroRouterTracker>[];
  GoRouter? router;

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.meaningful);
  });

  setUp(() {
    originalFaro = Faro();
    faro = _MockFaro();
    sessionManager = _MockSessionManager();
    Faro.instance = faro;
    pod.overrideProvider(sessionManagerProvider, (_) => sessionManager);
    events = [];
    deferralLogs = 0;
    viewMetaNames = [];
    activitySources = [];
    signalChannel = UserActionLifecycleSignalChannel();
    signalChannel.stream.listen((signal) => activitySources.add(signal.source));
    pod.overrideProvider(
      userActionLifecycleSignalChannelProvider,
      (_) => signalChannel,
    );
    pod.overrideProvider(
      navigationObserverDeferralLoggerProvider,
      (_) =>
          () => deferralLogs++,
    );
    when(() => faro.setViewMeta(name: any(named: 'name'))).thenAnswer((call) {
      viewMetaNames.add(call.namedArguments[#name] as String?);
    });
    when(
      () => faro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenAnswer((call) {
      events.add(
        Map<String, dynamic>.from(call.namedArguments[#attributes] as Map),
      );
    });
  });

  tearDown(() {
    for (final tracker in trackers) {
      tracker.dispose();
    }
    trackers.clear();
    router?.dispose();
    router = null;
    Faro.instance = originalFaro;
    pod.removeOverride(sessionManagerProvider);
    pod.removeOverride(navigationObserverDeferralLoggerProvider);
    pod.removeOverride(userActionLifecycleSignalChannelProvider);
    signalChannel.dispose();
  });

  GoRoute page(String path, String name) => GoRoute(
    path: path,
    name: name,
    builder: (_, _) => Text('Visible: $path'),
  );

  GoRouter buildRouter({
    List<NavigatorObserver>? rootObservers,
    List<NavigatorObserver>? shellObservers,
    List<NavigatorObserver>? branchObservers,
    ExitCallback? detailOnExit,
  }) {
    final forward = shellObservers == null && branchObservers == null;
    return router = GoRouter(
      initialLocation: '/home',
      observers: rootObservers,
      routes: [
        page('/home', 'home'),
        GoRoute(
          path: '/detail',
          name: 'detail',
          onExit: detailOnExit,
          builder: (_, _) => const Text('Visible: /detail'),
        ),
        ShellRoute(
          notifyRootObserver: forward,
          observers: shellObservers,
          builder: (_, _, child) => child,
          routes: [page('/s1', 's1'), page('/s2', 's2')],
        ),
        StatefulShellRoute.indexedStack(
          notifyRootObserver: forward,
          builder: (_, _, shell) => shell,
          branches: [
            StatefulShellBranch(
              observers: branchObservers,
              routes: [page('/a', 'a')],
            ),
            StatefulShellBranch(
              observers: branchObservers == null
                  ? null
                  : [FaroNavigationObserver()],
              routes: [
                GoRoute(
                  path: '/b',
                  name: 'b',
                  builder: (_, _) => const Text('Visible: /b'),
                  routes: [page('item/:id', 'b-item')],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FaroRouterTracker track(GoRouter router) {
    final tracker = FaroRouterTracker(
      routeChanges: router.routerDelegate,
      viewNameExtractor: () =>
          router.routerDelegate.currentConfiguration.isEmpty
          ? null
          : router.state.fullPath,
    );
    trackers.add(tracker);
    return tracker;
  }

  Future<void> walk(WidgetTester tester, GoRouter router) async {
    for (final location in ['/s1', '/s2', '/a', '/b']) {
      router.go(location);
      await tester.pumpAndSettle();
    }
    router.push('/b/item/7');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    router.go('/a');
    await tester.pumpAndSettle();
    router.go('/home');
    await tester.pumpAndSettle();
  }

  const trackerOnlyEvents = [
    {'fromView': null, 'toView': '/home'},
    {'fromView': '/home', 'toView': '/s1'},
    {'fromView': '/s1', 'toView': '/s2'},
    {'fromView': '/s2', 'toView': '/a'},
    {'fromView': '/a', 'toView': '/b'},
    {'fromView': '/b', 'toView': '/b/item/:id'},
    {'fromView': '/b/item/:id', 'toView': '/b'},
    {'fromView': '/b', 'toView': '/a'},
    {'fromView': '/a', 'toView': '/home'},
  ];

  testWidgets('baseline: the tracker alone emits one event per view', (
    tester,
  ) async {
    final router = buildRouter();
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await walk(tester, router);
    expect(events, trackerOnlyEvents);
  });

  testWidgets('a leftover root observer defers to the tracker', (tester) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await walk(tester, router);
    expect(events, trackerOnlyEvents);
    verify(
      () =>
          sessionManager.checkSession(activity: SessionActivityKind.meaningful),
    ).called(greaterThan(trackerOnlyEvents.length));
  });

  testWidgets('shell and branch observers defer to the tracker', (
    tester,
  ) async {
    final router = buildRouter(
      rootObservers: [FaroNavigationObserver()],
      shellObservers: [FaroNavigationObserver()],
      branchObservers: [FaroNavigationObserver()],
    );
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await walk(tester, router);
    expect(events, trackerOnlyEvents);
  });

  testWidgets('without a tracker the observers keep tracking', (tester) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(events.last, {'fromView': 'home', 'toView': 'detail'});
  });

  testWidgets('an observer on an unrelated outer MaterialApp keeps tracking', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    final outerKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: outerKey,
        navigatorObservers: [FaroNavigationObserver()],
        initialRoute: '/outer',
        routes: {'/outer': (_) => const Text('outer')},
      ),
    );
    outerKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/demo'),
        builder: (_) => MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    router.go('/a');
    await tester.pumpAndSettle();
    outerKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(events, [
      {'fromView': null, 'toView': '/outer'},
      {'fromView': '/outer', 'toView': '/demo'},
      {'fromView': null, 'toView': '/home'},
      {'fromView': '/home', 'toView': '/a'},
      {'fromView': '/demo', 'toView': '/outer'},
    ]);
  });

  testWidgets('observers resume after the tracker is disposed', (tester) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    final tracker = track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    tracker.dispose();
    events.clear();
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': 'home', 'toView': 'detail'},
    ]);
  });

  testWidgets('a second tracker keeps observers deferring after one dispose', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    final first = track(router);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    first.dispose();
    events.clear();
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': '/home', 'toView': '/detail'},
    ]);
  });

  testWidgets('a tracker created after the first frame takes over', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(events, [
      {'fromView': null, 'toView': 'home'},
    ]);
    track(router);
    router.push('/detail');
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': null, 'toView': 'home'},
      {'fromView': null, 'toView': '/home'},
      {'fromView': '/home', 'toView': '/detail'},
    ]);
  });
  testWidgets('a named dialog is recorded with tracker view names', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    events.clear();
    final context = tester.element(find.text('Visible: /home'));
    showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'confirm'),
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': '/home', 'toView': 'confirm'},
      {'fromView': 'confirm', 'toView': '/home'},
    ]);
  });

  testWidgets('a plain nested Navigator inside a page keeps tracking', (
    tester,
  ) async {
    final wizardKey = GlobalKey<NavigatorState>();
    router = GoRouter(
      initialLocation: '/wizard',
      routes: [
        GoRoute(
          path: '/wizard',
          builder: (_, _) => Navigator(
            key: wizardKey,
            observers: [FaroNavigationObserver()],
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'step-1'),
              builder: (_) => const Text('step 1'),
            ),
          ),
        ),
      ],
    );
    track(router!);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    events.clear();
    wizardKey.currentState!.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'step-2'),
        builder: (_) => const Text('step 2'),
      ),
    );
    await tester.pumpAndSettle();
    // The tracker never sees this push, so the observer keeps recording it.
    expect(events, [
      {'fromView': 'step-1', 'toView': 'step-2'},
    ]);
  });
  testWidgets('a pageless push on the router Navigator is recorded', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    final context = tester.element(find.text('Visible: /a'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'native'),
        builder: (_) => const Text('native'),
      ),
    );
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('native'))).pop();
    await tester.pumpAndSettle();
    router.go('/b');
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': '/a', 'toView': 'native'},
      {'fromView': 'native', 'toView': '/a'},
      {'fromView': '/a', 'toView': '/b'},
    ]);
  });

  Future<void> pumpWizard(
    WidgetTester tester,
    ValueNotifier<List<String>> steps, {
    required FaroNavigationObserver observer,
  }) async {
    router = GoRouter(
      initialLocation: '/wizard',
      routes: [
        GoRoute(
          path: '/wizard',
          builder: (_, _) => ValueListenableBuilder<List<String>>(
            valueListenable: steps,
            builder: (_, value, _) => Navigator(
              observers: [observer],
              pages: [
                for (final step in value)
                  MaterialPage<void>(
                    key: ValueKey(step),
                    name: step,
                    child: Text(step),
                  ),
              ],
              onDidRemovePage: (_) {},
            ),
          ),
        ),
      ],
    );
    track(router!);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    events.clear();
  }

  testWidgets('a pages Navigator inside a router page defers by default', (
    tester,
  ) async {
    final steps = ValueNotifier<List<String>>(['step-1']);
    await pumpWizard(tester, steps, observer: FaroNavigationObserver());
    steps.value = ['step-1', 'step-2'];
    await tester.pumpAndSettle();
    // The URL does not change, so neither side records the step.
    expect(events, isEmpty);
  });

  testWidgets('deferToRouterTracker: false records a pages Navigator', (
    tester,
  ) async {
    final steps = ValueNotifier<List<String>>(['step-1']);
    await pumpWizard(
      tester,
      steps,
      observer: FaroNavigationObserver(deferToRouterTracker: false),
    );
    steps.value = ['step-1', 'step-2'];
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': 'step-1', 'toView': 'step-2'},
    ]);
    expect(deferralLogs, 0);
  });

  testWidgets('an observer logs its first deferral once', (tester) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await walk(tester, router);
    expect(deferralLogs, 1);
  });

  testWidgets('deferred pages keep session and activity side effects', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    track(router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    viewMetaNames.clear();
    activitySources.clear();
    clearInteractions(sessionManager);
    router.push('/detail');
    await tester.pumpAndSettle();
    // Only the tracker sets the view; both sides still report activity.
    expect(viewMetaNames, ['/detail']);
    expect(
      activitySources,
      containsAll(<String>['navigation.router', 'navigation.push']),
    );
    verify(
      () =>
          sessionManager.checkSession(activity: SessionActivityKind.meaningful),
    ).called(2);
  });

  testWidgets('an untracked nested router keeps its observers', (tester) async {
    final inner = GoRouter(
      observers: [FaroNavigationObserver()],
      routes: [page('/', 'inner-home'), page('/inner', 'inner')],
    );
    addTearDown(inner.dispose);
    router = GoRouter(
      initialLocation: '/host',
      routes: [
        GoRoute(
          path: '/host',
          builder: (_, _) => Router.withConfig(config: inner),
        ),
      ],
    );
    track(router!);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    events.clear();
    inner.push('/inner');
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': 'inner-home', 'toView': 'inner'},
    ]);
  });

  testWidgets('before the first tracker view pageless routes use page names', (
    tester,
  ) async {
    final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
    trackers.add(
      FaroRouterTracker(
        routeChanges: router.routerDelegate,
        viewNameExtractor: () => null,
      ),
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    events.clear();
    final context = tester.element(find.text('Visible: /home'));
    showDialog<void>(
      context: context,
      routeSettings: const RouteSettings(name: 'confirm'),
      builder: (_) => const Text('dialog'),
    );
    await tester.pumpAndSettle();
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(events, [
      {'fromView': 'home', 'toView': 'confirm'},
      {'fromView': 'confirm', 'toView': 'home'},
    ]);
  });

  group('a dialog over a router page', () {
    Future<GoRouter> openDialogOnA(WidgetTester tester) async {
      final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
      track(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.go('/a');
      await tester.pumpAndSettle();
      showDialog<void>(
        context: tester.element(find.text('Visible: /a')),
        routeSettings: const RouteSettings(name: 'confirm'),
        builder: (_) => const Text('dialog'),
      );
      await tester.pumpAndSettle();
      return router;
    }

    Future<void> closeDialog(WidgetTester tester) async {
      Navigator.of(tester.element(find.text('dialog'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Visible: /b'), findsOneWidget);
    }

    testWidgets('closes onto a router page changed under it', (tester) async {
      final router = await openDialogOnA(tester);
      router.go('/b');
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);
      events.clear();
      await closeDialog(tester);
      expect(events, [
        {'fromView': 'confirm', 'toView': '/b'},
      ]);
    });

    testWidgets('closes before the router change is applied', (tester) async {
      final router = await openDialogOnA(tester);
      events.clear();
      router.go('/b');
      await tester.idle();
      await closeDialog(tester);
      expect(events, [
        {'fromView': 'confirm', 'toView': '/b'},
      ]);
    });
  });

  group('a router page on top of a Navigator.push route', () {
    Future<GoRouter> openNativeThenDetail(
      WidgetTester tester, {
      GoRouter? router,
    }) async {
      router ??= buildRouter(rootObservers: [FaroNavigationObserver()]);
      track(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      events.clear();
      Navigator.of(tester.element(find.text('Visible: /home'))).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'native'),
          builder: (_) => const Text('native'),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/detail');
      await tester.pumpAndSettle();
      return router;
    }

    const expected = [
      {'fromView': '/home', 'toView': 'native'},
      {'fromView': 'native', 'toView': '/detail'},
      {'fromView': '/detail', 'toView': 'native'},
      {'fromView': 'native', 'toView': '/home'},
    ];

    Future<void> closeNative(WidgetTester tester) async {
      expect(find.text('native'), findsOneWidget);
      Navigator.of(tester.element(find.text('native'))).pop();
      await tester.pumpAndSettle();
    }

    testWidgets('router.pop reveals it with one event', (tester) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('Navigator.pop reveals it with one event', (tester) async {
      await openNativeThenDetail(tester);
      Navigator.of(tester.element(find.text('Visible: /detail'))).pop();
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('system back reveals it with one event', (tester) async {
      await openNativeThenDetail(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('a guarded pop that resolves later reveals it once', (
      tester,
    ) async {
      final router = buildRouter(
        rootObservers: [FaroNavigationObserver()],
        detailOnExit: (_, _) async => true,
      );
      await openNativeThenDetail(tester, router: router);
      router.pop();
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('disposing the newest tracker keeps the reveal working', (
      tester,
    ) async {
      final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
      track(router);
      final newest = track(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      events.clear();
      Navigator.of(tester.element(find.text('Visible: /home'))).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'native'),
          builder: (_) => const Text('native'),
        ),
      );
      await tester.pumpAndSettle();
      newest.dispose();
      router.push('/detail');
      await tester.pumpAndSettle();
      router.pop();
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('a router page with the same name covers it', (tester) async {
      final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
      track(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      events.clear();
      Navigator.of(tester.element(find.text('Visible: /home'))).push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'native'),
          builder: (_) => const Text('native'),
        ),
      );
      await tester.pumpAndSettle();
      router.push('/home');
      await tester.pumpAndSettle();
      expect(events, [
        {'fromView': '/home', 'toView': 'native'},
        {'fromView': 'native', 'toView': '/home'},
      ]);
    });

    testWidgets('go to the page below it reveals it with one event', (
      tester,
    ) async {
      final router = await openNativeThenDetail(tester);
      // go_router keeps the /home page, so the route pushed on it stays.
      router.go('/home');
      await tester.pumpAndSettle();
      await closeNative(tester);
      expect(events, expected);
    });

    testWidgets('closing it in the same frame as router.pop', (tester) async {
      final router = await openNativeThenDetail(tester);
      final navigator = Navigator.of(
        tester.element(find.text('Visible: /detail')),
      );
      router.pop();
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.text('Visible: /home'), findsOneWidget);
      expect(events, expected);
    });

    testWidgets('a router push in the same frame as the reveal', (
      tester,
    ) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      router.push('/a');
      await tester.pumpAndSettle();
      expect(find.text('Visible: /a'), findsOneWidget);
      expect(events, [
        ...expected.sublist(0, 3),
        {'fromView': 'native', 'toView': '/a'},
      ]);
    });

    testWidgets('a query change after the reveal keeps it', (tester) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      router.go('/home?refresh=1');
      await tester.pumpAndSettle();
      expect(find.text('native'), findsOneWidget);
      expect(events, expected.sublist(0, 3));
    });

    testWidgets('a repeated router notification keeps the reveal', (
      tester,
    ) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      router.routerDelegate.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('native'), findsOneWidget);
      expect(events, expected.sublist(0, 3));
    });

    testWidgets('the same page pushed again in the frame of the reveal', (
      tester,
    ) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      router.push('/detail');
      await tester.pumpAndSettle();
      expect(find.text('Visible: /detail'), findsOneWidget);
      expect(events, [
        ...expected.sublist(0, 3),
        {'fromView': 'native', 'toView': '/detail'},
      ]);
    });

    testWidgets('go elsewhere in the frame of the reveal', (tester) async {
      final router = await openNativeThenDetail(tester);
      router.pop();
      router.go('/a');
      await tester.pumpAndSettle();
      expect(find.text('Visible: /a'), findsOneWidget);
      expect(events, [
        ...expected.sublist(0, 3),
        {'fromView': 'native', 'toView': '/a'},
      ]);
    });

    testWidgets('a router change without a reveal is still recorded', (
      tester,
    ) async {
      final router = await openNativeThenDetail(tester);
      router.go('/a');
      await tester.pumpAndSettle();
      expect(events.last, {'fromView': '/detail', 'toView': '/a'});
    });
  });
}
