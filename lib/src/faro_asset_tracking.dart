import 'package:faro/src/faro_asset_bundle.dart';
import 'package:flutter/widgets.dart';

/// Wraps the widget subtree with asset-load tracking.
///
/// Place this widget above any widgets that load assets to automatically
/// track loading times and sizes via Faro.
///
/// ```dart
/// FaroAssetTracking(
///   child: MyApp(),
/// )
/// ```
class FaroAssetTracking extends StatelessWidget {
  const FaroAssetTracking({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DefaultAssetBundle(
      bundle: FaroAssetBundleFactory().create(),
      child: child,
    );
  }
}
