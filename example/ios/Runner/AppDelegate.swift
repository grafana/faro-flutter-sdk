import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var crashChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FaroExampleCrash") {
      let channel = FlutterMethodChannel(
        name: "faro_example/crash",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { (call, _) in
        if call.method == "crashNative" {
          // Intentional native crash for validating crash reporting:
          // force-unwrap a value that is nil at runtime.
          let value = AppDelegate.alwaysNil()
          print(value!)
        }
      }
      self.crashChannel = channel
    }
  }

  // Returns nil, but the compiler cannot prove it, so the force-unwrap at
  // the call site traps at runtime instead of being a compile-time error.
  private static func alwaysNil() -> String? {
    return nil
  }
}
