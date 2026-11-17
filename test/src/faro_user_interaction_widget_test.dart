import 'package:faro/src/core/pod.dart';
import 'package:faro/src/faro.dart';
import 'package:faro/src/faro_user_interaction_widget.dart';
import 'package:faro/src/session/session_activity_kind.dart';
import 'package:faro/src/session/session_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFaro extends Mock implements Faro {}

class MockSessionManager extends Mock implements SessionManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFaro mockFaro;
  late MockSessionManager mockSessionManager;
  late Faro originalFaro;

  setUpAll(() {
    registerFallbackValue(SessionActivityKind.passive);
  });

  setUp(() {
    originalFaro = Faro();
    mockFaro = MockFaro();
    mockSessionManager = MockSessionManager();
    Faro.instance = mockFaro;
    pod.overrideProvider(sessionManagerProvider, (_) => mockSessionManager);

    when(
      () => mockSessionManager.checkSession(activity: any(named: 'activity')),
    ).thenReturn(null);
    when(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    ).thenReturn(null);
  });

  tearDown(() {
    Faro.instance = originalFaro;
    pod.removeOverride(sessionManagerProvider);
  });

  void verifyVisibleInteractions(int count) {
    verify(
      () => mockFaro.pushEvent(
        'user_interaction',
        attributes: {
          'element_type': 'ButtonStyleButton',
          'element_description': 'Visible action',
          'event_type': 'onClick',
          'event': 'onClick',
        },
      ),
    ).called(count);
  }

  Future<void> mountBackground(
    WidgetTester tester, {
    required Widget background,
    required VoidCallback onPressed,
  }) async {
    await tester.pumpWidget(
      FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                background,
                Center(
                  child: ElevatedButton(
                    onPressed: onPressed,
                    child: const Text('Visible action'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('FaroUserInteractionWidget layout safety:', () {
    testWidgets(
      'tracks taps after cold-start navigation without layout errors',
      (tester) async {
        const backgroundKey = Key('never-laid-out-background');
        var taps = 0;
        await tester.pumpWidget(
          FaroUserInteractionWidget(
            child: MaterialApp(
              initialRoute: '/detail',
              routes: {
                '/': (_) => const Scaffold(body: SizedBox(key: backgroundKey)),
                '/detail': (_) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => taps++,
                      child: const Text('Visible action'),
                    ),
                  ),
                ),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final background = tester.renderObject<RenderBox>(
          find.byKey(backgroundKey, skipOffstage: false),
        );
        expect(background.attached, isTrue);
        expect(background.hasSize, isFalse);

        await tester.tap(find.text('Visible action'));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(taps, 1);
        verify(
          () => mockFaro.pushEvent(
            'user_interaction',
            attributes: {
              'element_type': 'ButtonStyleButton',
              'element_description': 'Visible action',
              'event_type': 'onClick',
              'event': 'onClick',
            },
          ),
        ).called(1);
      },
    );

    testWidgets('tracks repeated taps after a nested cold-start deep link', (
      tester,
    ) async {
      const rootKey = Key('unlaid-root');
      const nestedKey = Key('unlaid-nested');
      var taps = 0;
      await tester.pumpWidget(
        FaroUserInteractionWidget(
          child: MaterialApp(
            initialRoute: '/nested/detail',
            routes: {
              '/': (_) => const Scaffold(body: SizedBox(key: rootKey)),
              '/nested': (_) => const Scaffold(body: SizedBox(key: nestedKey)),
              '/nested/detail': (_) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => taps++,
                    child: const Text('Visible action'),
                  ),
                ),
              ),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [rootKey, nestedKey]) {
        final box = tester.renderObject<RenderBox>(
          find.byKey(key, skipOffstage: false),
        );
        expect(box.attached, isTrue);
        expect(box.hasSize, isFalse);
      }
      await tester.tap(find.text('Visible action'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Visible action'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(taps, 2);
      verifyVisibleInteractions(2);
      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(2);
    });

    testWidgets('skips an attached sliver that has not been laid out', (
      tester,
    ) async {
      const sliverKey = Key('unlaid-sliver');
      var taps = 0;
      await mountBackground(
        tester,
        background: const _UnlaidSliverBox(
          child: SliverToBoxAdapter(
            key: sliverKey,
            child: SizedBox(height: 50),
          ),
        ),
        onPressed: () => taps++,
      );
      final sliver = tester.renderObject<RenderSliver>(find.byKey(sliverKey));
      expect(sliver.attached, isTrue);
      expect(sliver.geometry, isNull);
      await tester.tap(find.text('Visible action'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(taps, 1);
      verifyVisibleInteractions(1);
    });

    for (final failure in _GeometryFailure.values) {
      testWidgets(
        'skips a background render object with a ${failure.name} failure',
        (tester) async {
          const probeKey = Key('geometry-failure');
          var taps = 0;
          await mountBackground(
            tester,
            background: const _GeometryProbe(
              key: probeKey,
              child: SizedBox.expand(),
            ),
            onPressed: () => taps++,
          );
          final probe = tester.renderObject<_RenderGeometryProbe>(
            find.byKey(probeKey),
          );
          probe.failure = failure;
          try {
            await tester.tap(find.text('Visible action'));
          } finally {
            probe.failure = null;
          }
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(taps, 1);
          verifyVisibleInteractions(1);
        },
      );
    }
  });

  testWidgets('records a recognized tap as meaningful session activity', (
    tester,
  ) async {
    await tester.pumpWidget(
      FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: ElevatedButton(onPressed: () {}, child: const Text('Pay')),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));

    verify(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    ).called(1);
    verify(
      () => mockFaro.pushEvent(
        'user_interaction',
        attributes: any(named: 'attributes'),
      ),
    ).called(1);
  });

  testWidgets(
    'records an unsupported tap without emitting an interaction event',
    (tester) async {
      const targetKey = Key('unsupported-tap-target');
      await tester.pumpWidget(
        FaroUserInteractionWidget(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: GestureDetector(
                  key: targetKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox(width: 100, height: 100),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(targetKey));

      verify(
        () => mockSessionManager.checkSession(
          activity: SessionActivityKind.meaningful,
        ),
      ).called(1);
      verifyNever(
        () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
      );
    },
  );

  testWidgets('records a drag without emitting a tap event', (tester) async {
    const targetKey = Key('drag-target');
    await tester.pumpWidget(
      FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: GestureDetector(
                key: targetKey,
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (_) {},
                child: const SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byKey(targetKey), const Offset(0, -40));

    verify(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    ).called(1);
    verifyNever(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    );
  });

  testWidgets('does not record a cancelled pointer sequence', (tester) async {
    const targetKey = Key('cancel-target');
    await tester.pumpWidget(
      const FaroUserInteractionWidget(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Listener(
                key: targetKey,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(width: 100, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(targetKey)),
    );
    await gesture.cancel();

    verifyNever(
      () => mockSessionManager.checkSession(
        activity: SessionActivityKind.meaningful,
      ),
    );
    verifyNever(
      () => mockFaro.pushEvent(any(), attributes: any(named: 'attributes')),
    );
  });
}

// Keeps a sliver attached without laying it out or painting it. This lets the
// tracker encounter a sliver with null geometry behind a working button.
class _UnlaidSliverBox extends SingleChildRenderObjectWidget {
  const _UnlaidSliverBox({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderUnlaidSliverBox();
}

class _RenderUnlaidSliverBox extends RenderBox
    with RenderObjectWithChildMixin<RenderSliver> {
  @override
  void performLayout() {
    size = constraints.biggest;
  }

  @override
  bool paintsChild(RenderObject child) => false;

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}

enum _GeometryFailure { hitTest, transform, paintBounds }

class _GeometryProbe extends SingleChildRenderObjectWidget {
  const _GeometryProbe({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGeometryProbe();
}

class _RenderGeometryProbe extends RenderPointerListener {
  _GeometryFailure? failure;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (failure == _GeometryFailure.hitTest) {
      throw FlutterError('Background hit test unavailable');
    }
    return super.hitTest(result, position: position);
  }

  @override
  Matrix4 getTransformTo(RenderObject? target) {
    if (failure == _GeometryFailure.transform) {
      throw FlutterError('Background transform unavailable');
    }
    return super.getTransformTo(target);
  }

  @override
  Rect get paintBounds {
    if (failure == _GeometryFailure.paintBounds) {
      throw StateError('Background paint bounds unavailable');
    }
    return super.paintBounds;
  }
}
