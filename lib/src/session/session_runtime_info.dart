import 'dart:developer';
import 'dart:isolate';
import 'dart:ui' show RootIsolateToken;

import 'package:faro/src/native_platform_interaction/faro_native_methods.dart';

class SessionRuntimeInfo {
  const SessionRuntimeInfo({
    required this.processIdentifier,
    required this.isolateIdentifier,
    required this.ownsSessionPersistence,
  });

  final String processIdentifier;
  final String isolateIdentifier;
  final bool ownsSessionPersistence;
}

/// Resolves the native process that owns this Dart runtime.
class SessionRuntimeInfoProvider {
  SessionRuntimeInfoProvider({
    required FaroNativeMethods nativeMethods,
    bool Function()? isRootIsolate,
  }) : _nativeMethods = nativeMethods,
       _isRootIsolate =
           isRootIsolate ?? (() => RootIsolateToken.instance != null);

  final FaroNativeMethods _nativeMethods;
  final bool Function() _isRootIsolate;

  Future<SessionRuntimeInfo?> getRuntimeInfo() async {
    try {
      final nativeInfo = await _nativeMethods.getSessionRuntimeInfo();
      final processIdentifier = nativeInfo?['processIdentifier'];
      final ownsSessionPersistence =
          nativeInfo?['ownsSessionPersistence'] == true;
      if (processIdentifier is! String || processIdentifier.isEmpty) {
        log('Faro: Session persistence disabled: process identity unavailable');
        return null;
      }

      final isRootIsolate = _isRootIsolate();
      final debugName = Isolate.current.debugName;
      final isolateIdentifier = isRootIsolate
          ? 'main'
          : debugName != null && debugName != 'main'
          ? debugName
          : 'background-${identityHashCode(Isolate.current)}';

      // Secondary isolates must not race the owning root isolate's file.
      return SessionRuntimeInfo(
        processIdentifier: processIdentifier,
        isolateIdentifier: isolateIdentifier,
        ownsSessionPersistence: ownsSessionPersistence && isRootIsolate,
      );
    } catch (error) {
      log('Faro: Session persistence disabled: $error');
      return null;
    }
  }
}
