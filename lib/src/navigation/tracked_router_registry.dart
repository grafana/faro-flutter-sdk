import 'package:dartypod/dartypod.dart';
import 'package:flutter/widgets.dart';

/// View state that a `FaroRouterTracker` shares with navigation observers.
///
/// The tracker owns router pages. Observers on Navigators under the tracked
/// [Router] still record pageless routes, such as dialogs and
/// `Navigator.push` routes, and report them here so both sides agree on the
/// view that is visible.
class TrackedRouterView {
  /// Creates the view state. [resolveCurrentView] reads the router's view
  /// name right now, or returns null if it cannot.
  TrackedRouterView({required ValueGetter<String?> resolveCurrentView})
    : _resolveCurrentView = resolveCurrentView;

  final ValueGetter<String?> _resolveCurrentView;

  /// The last view name the tracker resolved from the router.
  String? routerView;

  /// The router's view name right now, falling back to [routerView].
  ///
  /// Differs from [routerView] while a router change is pending, for example
  /// when a pageless route is closed in the same frame as a router pop.
  String? get currentRouterView => _resolveCurrentView() ?? routerView;

  /// The last view recorded for this router, by the tracker or an observer.
  String? visibleView;

  _PendingState _pending = _PendingState.none;
  final Set<Route<dynamic>> _openPagelessRoutes = Set.identity();

  /// Whether a pageless route is open on a Navigator under this router.
  ///
  /// While one is open, a router change might reveal it, so the tracker
  /// waits for the Navigator to apply the change before recording, and lets
  /// the observer claim it.
  bool get hasOpenPagelessRoutes {
    _openPagelessRoutes.removeWhere((route) => !route.isActive);
    return _openPagelessRoutes.isNotEmpty;
  }

  /// Marks [route] as an open pageless route.
  void pagelessRouteOpened(Route<dynamic> route) =>
      _openPagelessRoutes.add(route);

  /// Marks [route] as closed.
  void pagelessRouteClosed(Route<dynamic>? route) =>
      _openPagelessRoutes.remove(route);

  /// Whether the tracker has a router change waiting to be recorded.
  bool get hasPendingChange => _pending != _PendingState.none;

  /// Starts a pending router change. Returns false if one already exists.
  ///
  /// Further router changes in the same frame join the pending one and keep
  /// an earlier claim. If they put a router page over the revealed route,
  /// [pendingChangeCoversPagelessRoute] makes the tracker record it.
  bool beginPendingChange() {
    if (hasPendingChange) return false;
    _pending = _PendingState.waiting;
    return true;
  }

  /// Lets an observer take over the pending router change.
  ///
  /// The tracker then updates [routerView] without recording an event,
  /// because the observer already recorded the view that is visible.
  void claimPendingChange() {
    if (hasPendingChange) _pending = _PendingState.claimed;
  }

  /// Reports that the pending change put a router page over a pageless
  /// route.
  ///
  /// The tracker then records the router page even if its name equals the
  /// last router view, because the pageless route was visible in between.
  void pendingChangeCoversPagelessRoute() {
    if (hasPendingChange) _pending = _PendingState.coversPageless;
  }

  /// Ends the pending change and reports how the tracker should record it.
  PendingRouterChange endPendingChange() {
    final result = switch (_pending) {
      _PendingState.claimed => PendingRouterChange.claimed,
      _PendingState.coversPageless => PendingRouterChange.coversPagelessRoute,
      _PendingState.none ||
      _PendingState.waiting => PendingRouterChange.unclaimed,
    };
    _pending = _PendingState.none;
    return result;
  }
}

enum _PendingState { none, waiting, claimed, coversPageless }

/// How the tracker records a router change it deferred.
enum PendingRouterChange {
  /// Record the change as usual.
  unclaimed,

  /// An observer already recorded the visible view. Update silently.
  claimed,

  /// A router page now covers a pageless route. Record it even if the router
  /// view name did not change.
  coversPagelessRoute,
}

/// Router delegates that a `FaroRouterTracker` currently tracks.
///
/// `FaroNavigationObserver` consults this registry so that page routes owned
/// by a tracked [Router] leave view tracking to the tracker.
class TrackedRouterRegistry {
  final Map<Listenable, List<TrackedRouterView>> _trackers = Map.identity();

  /// Marks [routeChanges] as tracked and returns a release callback.
  ///
  /// Release is idempotent.
  VoidCallback register(Listenable routeChanges, TrackedRouterView view) {
    _trackers.putIfAbsent(routeChanges, () => []).add(view);
    var released = false;
    return () {
      if (released) return;
      released = true;
      final entries = _trackers[routeChanges];
      if (entries == null) return;
      entries.remove(view);
      if (entries.isEmpty) _trackers.remove(routeChanges);
    };
  }

  /// The view states of the trackers that own [navigator].
  ///
  /// Returns an empty list unless the nearest [Router] above [navigator] has a
  /// tracked delegate. The walk stops at the nearest [Router], so an untracked
  /// nested router keeps its observers. The last entry is the newest tracker.
  List<TrackedRouterView> viewsFor(NavigatorState? navigator) {
    if (_trackers.isEmpty || navigator == null || !navigator.mounted) {
      return const [];
    }
    Object? delegate;
    navigator.context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is Router<dynamic>) {
        delegate = widget.routerDelegate;
        return false;
      }
      return true;
    });
    final entries = _trackers[delegate];
    return entries == null ? const [] : List.unmodifiable(entries);
  }
}

/// Shared registry for trackers and navigation observers.
final trackedRouterRegistryProvider = Provider<TrackedRouterRegistry>(
  (_) => TrackedRouterRegistry(),
);
