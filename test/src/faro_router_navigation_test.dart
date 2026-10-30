import 'dart:async';

import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_navigation_observer.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockFaro extends Mock implements Faro {}

class _MockSessionManager extends Mock implements SessionManager {}

void main() {
  late Faro originalFaro;
  late _MockFaro faro;
  late _MockSessionManager sessionManager;
  late FaroNavigationObserver observer;
  late GoRouter router;
  StatefulNavigationShell? navigationShell;
  String? currentView;
  late List<Map<String, dynamic>> events;

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.meaningful);
  });

  setUp(() {
    originalFaro = Faro();
    faro = _MockFaro();
    sessionManager = _MockSessionManager();
    Faro.instance = faro;
    pod.overrideProvider(sessionManagerProvider, (_) => sessionManager);
    observer = FaroNavigationObserver();
    navigationShell = null;
    currentView = null;
    events = [];
    when(() => faro.setViewMeta(name: any(named: 'name'))).thenAnswer((call) {
      currentView = call.namedArguments[#name] as String?;
    });
    when(
      () => faro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenAnswer((call) {
      if (call.positionalArguments.first == 'view_changed') {
        events.add(
          Map<String, dynamic>.from(call.namedArguments[#attributes] as Map),
        );
      }
    });
  });

  tearDown(() {
    observer.dispose();
    router.dispose();
    Faro.instance = originalFaro;
    pod.removeOverride(sessionManagerProvider);
  });

  Future<void> mountRouter(
    WidgetTester tester, {
    bool stateful = false,
    bool keyedPages = true,
    GoRouterRedirect? redirect,
  }) async {
    final rootKey = GlobalKey<NavigatorState>();
    GoRoute page(String path, {bool onRoot = false}) => GoRoute(
      path: path,
      parentNavigatorKey: onRoot ? rootKey : null,
      pageBuilder: (_, state) => NoTransitionPage<void>(
        key: keyedPages ? state.pageKey : null,
        name: state.uri.path,
        child: Scaffold(body: Text('Visible: ${state.uri.path}')),
      ),
    );
    router = GoRouter(
      navigatorKey: rootKey,
      initialLocation: '/landing',
      redirect: redirect,
      observers: [],
      routes: [
        page('/landing'),
        if (stateful)
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) {
              navigationShell = shell;
              return shell;
            },
            branches: [
              StatefulShellBranch(routes: [page('/a')]),
              StatefulShellBranch(routes: [page('/b')]),
            ],
          )
        else
          ShellRoute(
            builder: (_, _, child) => child,
            routes: [page('/a'), page('/b')],
          ),
        page('/detail', onRoot: true),
        page('/redirect'),
      ],
    );
    observer.dispose();
    observer = FaroNavigationObserver.router(
      routeChanges: router.routerDelegate,
      viewNameExtractor: () =>
          router.routerDelegate.currentConfiguration.isEmpty
          ? null
          : router.state.uri.path,
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    events.clear();
  }

  testWidgets('tracks shell pages without per-shell observers or page keys', (
    tester,
  ) async {
    await mountRouter(tester, keyedPages: false);
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    router.go('/b');
    await tester.pumpAndSettle();
    expect(find.text('Visible: /b'), findsOneWidget);
    expect(currentView, '/b');
    expect(events, [
      {'fromView': '/a', 'toView': '/b'},
    ]);
  });

  testWidgets('tracks a return to an already visited stateful branch', (
    tester,
  ) async {
    await mountRouter(tester, stateful: true);
    router.go('/a');
    await tester.pumpAndSettle();
    navigationShell?.goBranch(1);
    await tester.pumpAndSettle();
    events.clear();
    navigationShell?.goBranch(0);
    await tester.pumpAndSettle();
    expect(find.text('Visible: /a'), findsOneWidget);
    expect(currentView, '/a');
    expect(events, [
      {'fromView': '/b', 'toView': '/a'},
    ]);
  });

  testWidgets('emits once when entering a shell through the root navigator', (
    tester,
  ) async {
    await mountRouter(tester);
    router.go('/a');
    await tester.pumpAndSettle();
    expect(currentView, '/a');
    expect(events, [
      {'fromView': '/landing', 'toView': '/a'},
    ]);
  });

  testWidgets('restores the active shell view after a root push and pop', (
    tester,
  ) async {
    await mountRouter(tester);
    router.go('/b');
    await tester.pumpAndSettle();
    unawaited(router.push<void>('/detail'));
    await tester.pumpAndSettle();
    expect(currentView, '/detail');
    events.clear();
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('Visible: /b'), findsOneWidget);
    expect(currentView, '/b');
    expect(events, [
      {'fromView': '/detail', 'toView': '/b'},
    ]);
  });

  testWidgets('ignores query-only changes when naming views by path', (
    tester,
  ) async {
    await mountRouter(tester);
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    router.go('/a?filter=recent');
    await tester.pumpAndSettle();
    expect(currentView, '/a');
    expect(events, isEmpty);
  });

  testWidgets('records only the resolved destination of a redirect', (
    tester,
  ) async {
    await mountRouter(
      tester,
      redirect: (_, state) => state.uri.path == '/redirect' ? '/b' : null,
    );
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    router.go('/redirect');
    await tester.pumpAndSettle();
    expect(currentView, '/b');
    expect(events, [
      {'fromView': '/a', 'toView': '/b'},
    ]);
  });

  testWidgets('does not record a pending asynchronous redirect', (
    tester,
  ) async {
    final destination = Completer<String?>();
    await mountRouter(
      tester,
      redirect: (_, state) =>
          state.uri.path == '/redirect' ? destination.future : null,
    );
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    router.go('/redirect');
    await tester.pump();
    expect(currentView, '/a');
    expect(events, isEmpty);
    destination.complete('/b');
    await tester.pumpAndSettle();
    expect(currentView, '/b');
    expect(events, [
      {'fromView': '/a', 'toView': '/b'},
    ]);
  });

  testWidgets('stops tracking a live router after disposal', (tester) async {
    await mountRouter(tester);
    router.go('/a');
    await tester.pumpAndSettle();
    events.clear();
    observer.dispose();
    router.go('/b');
    await tester.pumpAndSettle();
    expect(find.text('Visible: /b'), findsOneWidget);
    expect(currentView, '/a');
    expect(events, isEmpty);
  });
}
