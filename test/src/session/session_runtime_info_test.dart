import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';
import 'package:faro/src/session/session_runtime_info.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFaroNativeMethods extends Mock implements FaroNativeMethods {}

void main() {
  late _MockFaroNativeMethods nativeMethods;

  setUp(() {
    nativeMethods = _MockFaroNativeMethods();
  });

  test('allows the owning root isolate to persist', () async {
    when(
      () => nativeMethods.getSessionRuntimeInfo(claimSessionPersistence: true),
    ).thenAnswer(
      (_) async => <String, dynamic>{
        'processIdentifier': 'com.example.app',
        'ownsSessionPersistence': true,
      },
    );
    final provider = SessionRuntimeInfoProvider(
      nativeMethods: nativeMethods,
      isRootIsolate: () => true,
    );

    final info = await provider.getRuntimeInfo();

    expect(info?.processIdentifier, 'com.example.app');
    expect(info?.isolateIdentifier, 'main');
    expect(info?.ownsSessionPersistence, isTrue);
  });

  test('secondary isolates keep identity but cannot persist', () async {
    when(
      () => nativeMethods.getSessionRuntimeInfo(claimSessionPersistence: false),
    ).thenAnswer(
      (_) async => <String, dynamic>{
        'processIdentifier': 'com.example.app',
        'ownsSessionPersistence': true,
      },
    );
    final provider = SessionRuntimeInfoProvider(
      nativeMethods: nativeMethods,
      isRootIsolate: () => false,
    );

    final info = await provider.getRuntimeInfo();

    expect(info?.processIdentifier, 'com.example.app');
    expect(info?.isolateIdentifier, 'background');
    expect(info?.ownsSessionPersistence, isFalse);
  });

  test('a non-owning engine cannot persist', () async {
    when(
      () => nativeMethods.getSessionRuntimeInfo(claimSessionPersistence: true),
    ).thenAnswer(
      (_) async => <String, dynamic>{
        'processIdentifier': 'com.example.app',
        'ownsSessionPersistence': false,
      },
    );
    final provider = SessionRuntimeInfoProvider(
      nativeMethods: nativeMethods,
      isRootIsolate: () => true,
    );

    expect((await provider.getRuntimeInfo())?.ownsSessionPersistence, isFalse);
  });

  test('missing process identity disables persistence safely', () async {
    when(
      () => nativeMethods.getSessionRuntimeInfo(claimSessionPersistence: true),
    ).thenAnswer((_) async => <String, dynamic>{});
    final provider = SessionRuntimeInfoProvider(
      nativeMethods: nativeMethods,
      isRootIsolate: () => true,
    );

    expect(await provider.getRuntimeInfo(), isNull);
  });

  test('native failures disable persistence safely', () async {
    when(
      () => nativeMethods.getSessionRuntimeInfo(claimSessionPersistence: true),
    ).thenThrow(StateError('unavailable'));
    final provider = SessionRuntimeInfoProvider(
      nativeMethods: nativeMethods,
      isRootIsolate: () => true,
    );

    expect(await provider.getRuntimeInfo(), isNull);
  });
}
