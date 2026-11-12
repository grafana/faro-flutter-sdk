import 'dart:async';

import 'package:faro/src/navigation/tracked_router_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('TrackedRouterView:', () {
    late String? currentView;
    late TrackedRouterView view;

    setUp(() {
      currentView = null;
      view = TrackedRouterView(resolveCurrentView: () => currentView);
    });

    test('currentRouterView reads the router and falls back', () {
      view.routerView = '/home';
      expect(view.currentRouterView, '/home');
      currentView = '/detail';
      expect(view.currentRouterView, '/detail');
    });

    test('a pending change without observer input is unclaimed', () {
      expect(view.hasPendingChange, isFalse);
      expect(view.beginPendingChange(), isTrue);
      expect(view.hasPendingChange, isTrue);
      expect(view.endPendingChange(), PendingRouterChange.unclaimed);
      expect(view.hasPendingChange, isFalse);
    });

    test('a later change in the same frame joins the pending one', () {
      expect(view.beginPendingChange(), isTrue);
      view.claimPendingChange();
      expect(view.beginPendingChange(), isFalse);
      expect(view.endPendingChange(), PendingRouterChange.claimed);
    });

    test('covering a pageless route wins over a claim', () {
      view.beginPendingChange();
      view.claimPendingChange();
      view.pendingChangeCoversPagelessRoute();
      expect(view.endPendingChange(), PendingRouterChange.coversPagelessRoute);
    });

    test('claim and cover are ignored without a pending change', () {
      view.claimPendingChange();
      view.pendingChangeCoversPagelessRoute();
      expect(view.hasPendingChange, isFalse);
      view.beginPendingChange();
      expect(view.endPendingChange(), PendingRouterChange.unclaimed);
    });

    test('ending resets the state for the next change', () {
      view.beginPendingChange();
      view.claimPendingChange();
      view.endPendingChange();
      view.beginPendingChange();
      expect(view.endPendingChange(), PendingRouterChange.unclaimed);
    });

    testWidgets('open pageless routes are tracked while active', (
      tester,
    ) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigatorKey, home: const Text('home')),
      );
      final route = MaterialPageRoute<void>(
        builder: (_) => const Text('native'),
      );
      unawaited(navigatorKey.currentState!.push(route));
      await tester.pumpAndSettle();

      final dialog = DialogRoute<void>(
        context: tester.element(find.text('native')),
        builder: (_) => const Text('dialog'),
      );
      unawaited(navigatorKey.currentState!.push(dialog));
      await tester.pumpAndSettle();

      view
        ..pagelessRouteOpened(route)
        ..pagelessRouteOpened(dialog);
      view.pagelessRouteClosed(dialog);
      expect(view.hasOpenPagelessRoutes, isTrue);
      view.pagelessRouteClosed(route);
      expect(view.hasOpenPagelessRoutes, isFalse);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      // A route that left the Navigator without a callback is pruned.
      view.pagelessRouteOpened(route);
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(view.hasOpenPagelessRoutes, isFalse);
    });
  });

  group('TrackedRouterRegistry:', () {
    late TrackedRouterRegistry registry;

    TrackedRouterView newView() =>
        TrackedRouterView(resolveCurrentView: () => null);

    setUp(() => registry = TrackedRouterRegistry());

    GoRouter newRouter() {
      final router = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const Text('home'))],
      );
      addTearDown(router.dispose);
      return router;
    }

    NavigatorState navigatorOf(WidgetTester tester, String text) =>
        Navigator.of(tester.element(find.text(text)));

    testWidgets('returns the views of the nearest tracked Router', (
      tester,
    ) async {
      final router = newRouter();
      final first = newView();
      final second = newView();
      registry
        ..register(router.routerDelegate, first)
        ..register(router.routerDelegate, second);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      expect(registry.viewsFor(navigatorOf(tester, 'home')), [first, second]);
    });

    testWidgets('release is idempotent and keeps other views', (tester) async {
      final router = newRouter();
      final first = newView();
      final second = newView();
      final releaseFirst = registry.register(router.routerDelegate, first);
      final releaseSecond = registry.register(router.routerDelegate, second);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final navigator = navigatorOf(tester, 'home');

      releaseSecond();
      releaseSecond();
      expect(registry.viewsFor(navigator), [first]);
      releaseFirst();
      expect(registry.viewsFor(navigator), isEmpty);
    });

    testWidgets('a Navigator outside any Router has no views', (tester) async {
      final router = newRouter();
      registry.register(router.routerDelegate, newView());
      await tester.pumpWidget(const MaterialApp(home: Text('plain')));

      expect(registry.viewsFor(navigatorOf(tester, 'plain')), isEmpty);
      expect(registry.viewsFor(null), isEmpty);
    });

    testWidgets('an untracked nested Router hides the outer tracker', (
      tester,
    ) async {
      final inner = GoRouter(
        routes: [GoRoute(path: '/', builder: (_, _) => const Text('inner'))],
      );
      addTearDown(inner.dispose);
      final outer = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Router.withConfig(config: inner),
          ),
        ],
      );
      addTearDown(outer.dispose);
      registry.register(outer.routerDelegate, newView());
      await tester.pumpWidget(MaterialApp.router(routerConfig: outer));
      await tester.pumpAndSettle();

      expect(registry.viewsFor(navigatorOf(tester, 'inner')), isEmpty);
    });
  });
}
