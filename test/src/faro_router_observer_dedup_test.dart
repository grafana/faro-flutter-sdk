import 'dart:async';

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
  group('FaroNavigationObserver with FaroRouterTracker:', () {
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
      signalChannel.stream.listen(
        (signal) => activitySources.add(signal.source),
      );
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

    testWidgets('a leftover root observer defers to the tracker', (
      tester,
    ) async {
      final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
      track(router);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await walk(tester, router);
      expect(events, trackerOnlyEvents);
      verify(
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
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

    testWidgets('without a tracker the observers keep tracking', (
      tester,
    ) async {
      final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      router.push('/detail');
      await tester.pumpAndSettle();
      expect(events.last, {'fromView': 'home', 'toView': 'detail'});
    });

    testWidgets(
      'an observer on an unrelated outer MaterialApp keeps tracking',
      (tester) async {
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
      },
    );

    testWidgets('closing a dialog restores the view after an outer route', (
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
      // The router's own Navigator, not the outer app's root Navigator.
      final routerNavigator = router.routerDelegate.navigatorKey.currentState!;
      unawaited(
        routerNavigator.push(
          DialogRoute<void>(
            context: routerNavigator.context,
            settings: const RouteSettings(name: 'confirm'),
            builder: (_) => const Text('dialog'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/b');
      await tester.pumpAndSettle();
      outerKey.currentState!.push(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/other'),
          builder: (_) => const Text('other'),
        ),
      );
      await tester.pumpAndSettle();
      outerKey.currentState!.pop();
      await tester.pumpAndSettle();
      events.clear();
      Navigator.of(tester.element(find.text('dialog'))).pop();
      await tester.pumpAndSettle();

      expect(events, isEmpty);
      expect(viewMetaNames.last, '/b');
    });

    testWidgets('observers resume after the tracker is disposed', (
      tester,
    ) async {
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

    testWidgets(
      'a second tracker keeps observers deferring after one dispose',
      (tester) async {
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
      },
    );

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
        () => sessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(2);
    });

    testWidgets('an untracked nested router keeps its observers', (
      tester,
    ) async {
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

    testWidgets(
      'before the first tracker view pageless routes use page names',
      (tester) async {
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
      },
    );

    group('observer callbacks under a tracked router:', () {
      Future<(GoRouter, NavigatorState)> pumpTracked(
        WidgetTester tester,
      ) async {
        final router = buildRouter(rootObservers: [FaroNavigationObserver()]);
        track(router);
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        events.clear();
        return (
          router,
          Navigator.of(tester.element(find.text('Visible: /home'))),
        );
      }

      MaterialPageRoute<void> pageless(String name) => MaterialPageRoute<void>(
        settings: RouteSettings(name: name),
        builder: (_) => Text(name),
      );

      testWidgets('without an open pageless route the tracker is synchronous', (
        tester,
      ) async {
        final (router, _) = await pumpTracked(tester);
        router.go('/detail');
        // Recorded before any frame is pumped.
        expect(events, [
          {'fromView': '/home', 'toView': '/detail'},
        ]);
      });

      testWidgets(
        'with an open pageless route the tracker waits for the frame',
        (tester) async {
          final (router, navigator) = await pumpTracked(tester);
          unawaited(navigator.push(pageless('native')));
          await tester.pumpAndSettle();
          events.clear();
          router.go('/a');
          // Not before the frame either, so not just a microtask later.
          await tester.idle();
          expect(events, isEmpty);
          await tester.pumpAndSettle();
          expect(events, [
            {'fromView': 'native', 'toView': '/a'},
          ]);
        },
      );

      testWidgets('a removed pageless route no longer delays the tracker', (
        tester,
      ) async {
        final (router, navigator) = await pumpTracked(tester);
        final route = pageless('native');
        unawaited(navigator.push(route));
        await tester.pumpAndSettle();
        navigator.removeRoute(route);
        await tester.pumpAndSettle();
        events.clear();
        router.go('/detail');
        // No open pageless route is left, so the tracker records right away.
        expect(events, [
          {'fromView': 'native', 'toView': '/detail'},
        ]);
      });

      testWidgets('didReplace between pageless routes is recorded', (
        tester,
      ) async {
        final (_, navigator) = await pumpTracked(tester);
        unawaited(navigator.push(pageless('native-1')));
        await tester.pumpAndSettle();
        unawaited(navigator.pushReplacement(pageless('native-2')));
        await tester.pumpAndSettle();
        navigator.pop();
        await tester.pumpAndSettle();
        expect(events, [
          {'fromView': '/home', 'toView': 'native-1'},
          {'fromView': 'native-1', 'toView': 'native-2'},
          {'fromView': 'native-2', 'toView': '/home'},
        ]);
        expect(activitySources, contains('navigation.replace'));
      });
    });

    group('a dialog over a router page:', () {
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
        events.clear();
        router.go('/b');
        await tester.pumpAndSettle();
        expect(find.text('dialog'), findsOneWidget);
        await closeDialog(tester);
        expect(events, [
          {'fromView': 'confirm', 'toView': '/b'},
        ]);
      });

      testWidgets(
        'a nested push in the frame that closes it and changes page',
        (tester) async {
          final nestedKey = GlobalKey<NavigatorState>();
          final nestedRouter = router = GoRouter(
            initialLocation: '/a',
            observers: [FaroNavigationObserver()],
            routes: [
              GoRoute(
                path: '/a',
                builder: (_, _) => Column(
                  children: [
                    const Text('Visible: /a'),
                    Expanded(
                      child: Navigator(
                        key: nestedKey,
                        observers: [FaroNavigationObserver()],
                        pages: const [
                          MaterialPage<void>(
                            name: 'step-1',
                            child: Text('step'),
                          ),
                        ],
                        onDidRemovePage: (_) {},
                      ),
                    ),
                  ],
                ),
              ),
              page('/b', 'b'),
            ],
          );
          track(nestedRouter);
          await tester.pumpWidget(
            MaterialApp.router(routerConfig: nestedRouter),
          );
          showDialog<void>(
            context: tester.element(find.text('Visible: /a')),
            routeSettings: const RouteSettings(name: 'confirm'),
            builder: (_) => const Text('dialog'),
          );
          await tester.pumpAndSettle();
          events.clear();
          viewMetaNames.clear();
          nestedRouter.go('/b');
          Navigator.of(tester.element(find.text('dialog'))).pop();
          nestedKey.currentState!.push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'native'),
              builder: (_) => const Text('native'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Visible: /b'), findsOneWidget);
          expect(events.last, {'fromView': 'native', 'toView': '/b'});
          expect(viewMetaNames.last, '/b');
        },
      );

      testWidgets('a page that opens a dialog when it loads', (tester) async {
        var opened = false;
        final dialogRouter = router = GoRouter(
          initialLocation: '/a',
          observers: [FaroNavigationObserver()],
          routes: [
            page('/a', 'a'),
            GoRoute(
              path: '/b',
              name: 'b',
              builder: (context, _) {
                if (!opened) {
                  opened = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    showDialog<void>(
                      context: context,
                      routeSettings: const RouteSettings(name: 'welcome'),
                      builder: (_) => const Text('welcome'),
                    );
                  });
                }
                return const Text('Visible: /b');
              },
            ),
          ],
        );
        track(dialogRouter);
        await tester.pumpWidget(MaterialApp.router(routerConfig: dialogRouter));
        showDialog<void>(
          context: tester.element(find.text('Visible: /a')),
          routeSettings: const RouteSettings(name: 'confirm'),
          builder: (_) => const Text('dialog'),
        );
        await tester.pumpAndSettle();
        events.clear();
        viewMetaNames.clear();
        dialogRouter.go('/b');
        Navigator.of(tester.element(find.text('dialog'))).pop();
        await tester.pumpAndSettle();
        expect(find.text('welcome'), findsOneWidget);
        expect(events, [
          {'fromView': 'confirm', 'toView': '/b'},
          {'fromView': '/b', 'toView': 'welcome'},
        ]);
        expect(viewMetaNames.last, 'welcome');
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

    group('a router page on top of a Navigator.push route:', () {
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

      testWidgets('a router push in the frame that closes both', (
        tester,
      ) async {
        final router = await openNativeThenDetail(tester);
        final navigator = Navigator.of(
          tester.element(find.text('Visible: /detail')),
        );
        router.pop();
        navigator.pop();
        router.push('/detail');
        await tester.pumpAndSettle();
        expect(find.text('Visible: /detail'), findsOneWidget);
        expect(events, [
          ...expected,
          {'fromView': '/home', 'toView': '/detail'},
        ]);
      });

      testWidgets('a pageless push in the frame that closes both', (
        tester,
      ) async {
        await openNativeThenDetail(tester);
        Navigator.of(tester.element(find.text('Visible: /detail')))
          ..popUntil((route) => route.isFirst)
          ..push(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: 'next'),
              builder: (_) => const Text('next'),
            ),
          );
        await tester.pumpAndSettle();
        expect(events, [
          ...expected,
          {'fromView': '/home', 'toView': 'next'},
        ]);
      });

      testWidgets('a hidden nested page push keeps the reveal', (tester) async {
        final steps = ValueNotifier<List<String>>(['step-1']);
        final router = GoRouter(
          initialLocation: '/home',
          observers: [FaroNavigationObserver()],
          routes: [
            GoRoute(
              path: '/home',
              builder: (_, _) => Column(
                children: [
                  const Text('Visible: /home'),
                  Expanded(
                    child: ValueListenableBuilder<List<String>>(
                      valueListenable: steps,
                      builder: (_, value, _) => Navigator(
                        observers: [FaroNavigationObserver()],
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
              ),
            ),
            page('/detail', 'detail'),
          ],
        );
        await openNativeThenDetail(tester, router: router);
        router.pop();
        steps.value = ['step-1', 'step-2'];
        await tester.pumpAndSettle();
        expect(find.text('native'), findsOneWidget);
        expect(events, expected.sublist(0, 3));
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
  });
}
