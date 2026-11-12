import 'package:faro/faro.dart' show FaroNavigationObserver, FaroRouterTracker;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// How the nested go_router demo wires Faro navigation tracking.
enum RouterTrackingMode {
  trackerOnly('Tracker only'),
  observerOnly('Root observer only'),
  leftoverRootObserver('Tracker + leftover root observer'),
  allObservers('Tracker + root and shell observers');

  const RouterTrackingMode(this.label);
  final String label;

  bool get usesTracker => this != observerOnly;
  bool get usesRootObserver => this != trackerOnly;
  bool get usesShellObservers => this == allObservers;
}

/// Picks a tracking mode and opens a nested go_router app with it.
class RouterTrackingPage extends StatelessWidget {
  const RouterTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Router Tracking')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Opens a nested go_router app with a StatefulShellRoute and a '
            'ShellRoute. Each mode wires Faro navigation tracking differently.',
          ),
          const SizedBox(height: 16),
          for (final mode in RouterTrackingMode.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    settings: RouteSettings(name: '/router-demo/${mode.name}'),
                    builder: (_) => _RouterDemoApp(mode: mode),
                  ),
                ),
                child: Text(mode.label),
              ),
            ),
        ],
      ),
    );
  }
}

class _RouterDemoApp extends StatefulWidget {
  const _RouterDemoApp({required this.mode});

  final RouterTrackingMode mode;

  @override
  State<_RouterDemoApp> createState() => _RouterDemoAppState();
}

class _RouterDemoAppState extends State<_RouterDemoApp> {
  late final GoRouter _router;
  FaroRouterTracker? _tracker;

  List<NavigatorObserver>? _shellObservers() =>
      widget.mode.usesShellObservers ? [FaroNavigationObserver()] : null;

  @override
  void initState() {
    super.initState();
    final mode = widget.mode;
    _router = GoRouter(
      observers: mode.usesRootObserver ? [FaroNavigationObserver()] : null,
      routes: [
        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, _) => _DemoHome(onExit: _exit),
          routes: [
            GoRoute(
              path: 'item/:id',
              name: 'item',
              builder: (_, state) =>
                  _Screen(title: 'Item ${state.pathParameters['id']}'),
            ),
          ],
        ),
        // A wizard with its own Navigator(pages:). The URL stays the same
        // while the steps change, so the tracker cannot see the steps.
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (_, _) => const _SignupWizard(recordSteps: false),
        ),
        GoRoute(
          path: '/signup-steps',
          name: 'signup-steps',
          builder: (_, _) => const _SignupWizard(recordSteps: true),
        ),
        StatefulShellRoute.indexedStack(
          notifyRootObserver: !mode.usesShellObservers,
          builder: (_, _, shell) => _TabsShell(shell: shell),
          branches: [
            StatefulShellBranch(
              observers: _shellObservers(),
              routes: [
                GoRoute(
                  path: '/tabs/a',
                  name: 'tab-a',
                  builder: (_, _) => const _Screen(title: 'Tab A'),
                ),
              ],
            ),
            StatefulShellBranch(
              observers: _shellObservers(),
              routes: [
                GoRoute(
                  path: '/tabs/b',
                  name: 'tab-b',
                  builder: (_, _) =>
                      const _Screen(title: 'Tab B', pushTo: '/tabs/b/item/7'),
                  routes: [
                    GoRoute(
                      path: 'item/:id',
                      name: 'tab-b-item',
                      builder: (_, state) => _Screen(
                        title: 'Tab B item ${state.pathParameters['id']}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        ShellRoute(
          notifyRootObserver: !mode.usesShellObservers,
          observers: _shellObservers(),
          builder: (_, _, child) => Scaffold(
            appBar: AppBar(title: const Text('Settings shell')),
            body: child,
          ),
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (_, _) => const _Screen(title: 'Settings'),
            ),
          ],
        ),
      ],
    );
    if (mode.usesTracker) {
      _tracker = FaroRouterTracker(
        routeChanges: _router.routerDelegate,
        viewNameExtractor: () {
          if (_router.routerDelegate.currentConfiguration.isEmpty) return null;
          return _router.state.fullPath;
        },
      );
    }
  }

  void _exit() => Navigator.of(context).pop();

  @override
  void dispose() {
    _tracker?.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class _DemoHome extends StatelessWidget {
  const _DemoHome({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Router demo home')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton(
            onPressed: () => context.push('/item/42'),
            child: const Text('Push item 42'),
          ),
          ElevatedButton(
            onPressed: () => context.go('/tabs/a'),
            child: const Text('Go tabs'),
          ),
          ElevatedButton(
            onPressed: () => context.go('/settings'),
            child: const Text('Go settings'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'native'),
                builder: (_) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // A router page on top of this Navigator.push route.
                        ElevatedButton(
                          onPressed: () => context.push('/item/42'),
                          child: const Text('Push router item'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close native'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Push native route'),
          ),
          ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              // Stay on go_router's Navigator, not the outer example app.
              useRootNavigator: false,
              routeSettings: const RouteSettings(name: 'confirm'),
              builder: (dialogContext) => AlertDialog(
                title: const Text('Confirm dialog'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close dialog'),
                  ),
                ],
              ),
            ),
            child: const Text('Show dialog'),
          ),
          ElevatedButton(
            onPressed: () => context.push('/signup'),
            child: const Text('Open wizard'),
          ),
          ElevatedButton(
            onPressed: () => context.push('/signup-steps'),
            child: const Text('Open wizard, record steps'),
          ),
          ElevatedButton(
            // A route on the outer example app, above the whole router.
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute<void>(
                settings: const RouteSettings(name: 'outer-app-route'),
                builder: (outerContext) => Scaffold(
                  appBar: AppBar(title: const Text('Outer app route')),
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(outerContext).pop(),
                      child: const Text('Close outer route'),
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('Push outer app route'),
          ),
          ElevatedButton(onPressed: onExit, child: const Text('Exit demo')),
        ],
      ),
    );
  }
}

/// A three-step flow on its own Navigator inside the `/signup` page.
///
/// With [recordSteps], its observer sets `deferToRouterTracker: false` so
/// the steps are recorded even though the router never sees them.
class _SignupWizard extends StatefulWidget {
  const _SignupWizard({required this.recordSteps});

  final bool recordSteps;

  @override
  State<_SignupWizard> createState() => _SignupWizardState();
}

class _SignupWizardState extends State<_SignupWizard> {
  static const _stepCount = 3;

  late final NavigatorObserver _observer = FaroNavigationObserver(
    deferToRouterTracker: !widget.recordSteps,
  );
  int _steps = 1;

  void _next() => setState(() => _steps++);

  void _onDidRemovePage(Page<Object?> page) => setState(() => _steps--);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recordSteps ? 'Wizard, record steps' : 'Wizard'),
      ),
      body: Navigator(
        observers: [_observer],
        onDidRemovePage: _onDidRemovePage,
        pages: [
          for (var step = 1; step <= _steps; step++)
            MaterialPage<void>(
              key: ValueKey('step-$step'),
              name: 'step-$step',
              child: _WizardStep(
                step: step,
                onNext: step < _stepCount ? _next : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _WizardStep extends StatelessWidget {
  const _WizardStep({required this.step, required this.onNext});

  final int step;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Step $step', style: Theme.of(context).textTheme.headlineSmall),
          if (onNext != null)
            ElevatedButton(onPressed: onNext, child: const Text('Next step')),
          if (step > 1)
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Previous step'),
            ),
          ElevatedButton(
            onPressed: () => context.go('/'),
            child: const Text('Finish wizard'),
          ),
        ],
      ),
    );
  }
}

class _TabsShell extends StatelessWidget {
  const _TabsShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tabs shell'),
        actions: [
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Leave tabs'),
          ),
        ],
      ),
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.looks_one), label: 'Tab A'),
          NavigationDestination(icon: Icon(Icons.looks_two), label: 'Tab B'),
        ],
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen({required this.title, this.pushTo});

  final String title;
  final String? pushTo;

  @override
  Widget build(BuildContext context) {
    // Router pages outside a shell have no Scaffold of their own.
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if (pushTo != null)
              ElevatedButton(
                onPressed: () => context.push(pushTo!),
                child: Text('Push ${pushTo!}'),
              ),
            if (context.canPop())
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Pop screen'),
              ),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Go demo home'),
            ),
          ],
        ),
      ),
    );
  }
}
