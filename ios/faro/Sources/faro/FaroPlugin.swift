import Flutter
import UIKit
import Foundation
import CrashReporter


public class FaroPlugin: NSObject, FlutterPlugin {
  private static let sessionPersistenceOwnerLock = NSLock()
  private static var sessionPersistenceOwnerClaimed = false
  private var ownsSessionPersistence = false
  private var crashReportingIntegration: CrashReportingIntegration?
  private let crashReportQueue = DispatchQueue(
    label: "com.grafana.faro.crash-report",
    qos: .utility
  )
  // task_info and getrusage must not run on the main thread.
  private let processVitalsQueue = DispatchQueue(
    label: "com.grafana.faro.process-vitals",
    qos: .utility
  )

  public static func register(with registrar: FlutterPluginRegistrar) {
    // First thing the SDK does. iOS clears the prewarm flag once the app has
    // finished launching, and plugin registration runs inside
    // `didFinishLaunchingWithOptions`, which is the earliest hook a Flutter
    // plugin gets.
    AppStartTracker.recordSdkLoad()

    let channel = FlutterMethodChannel(name: "faro", binaryMessenger: registrar.messenger())
    let instance = FaroPlugin()
      
//    if(isCrashReportAutoEnabled() == true){
//          let crashreporter = CrashReportingIntegration()
//    }
    registrar.addMethodCallDelegate(instance, channel: channel)

    let deviceStateChannel = FlutterEventChannel(
      name: "faro/device_state",
      binaryMessenger: registrar.messenger()
    )
    deviceStateChannel.setStreamHandler(DeviceStateStreamHandler())
  }
    
    private static func isCrashReportAutoEnabled() -> Bool{
        return false
    }

  deinit {
    if ownsSessionPersistence {
      FaroPlugin.sessionPersistenceOwnerLock.lock()
      FaroPlugin.sessionPersistenceOwnerClaimed = false
      FaroPlugin.sessionPersistenceOwnerLock.unlock()
    }
  }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enableCrashReporter":
            do {
                crashReportingIntegration = try CrashReportingIntegration()
                result(nil)
            } catch {
                result(
                    FlutterError(
                        code: "crash_reporter_initialization_failed",
                        message: "Could not initialize the iOS crash reporter.",
                        details: error.localizedDescription
                    )
                )
            }
        case "getCrashReport":
            // If runtime discovery failed before claiming an owner, let the
            // first root engine reaching recovery claim the pending report.
            claimSessionPersistenceOwnership()
            guard ownsSessionPersistence else {
                result([String]())
                return
            }
            guard let crashReportingIntegration else {
                result([String]())
                return
            }
            crashReportQueue.async {
                let reports = crashReportingIntegration.takePendingCrashReports()
                DispatchQueue.main.async {
                    result(reports)
                }
            }
        case "purgeCrashReport":
            // Match getCrashReport's fallback when runtime discovery could not
            // establish the owner before crash recovery starts.
            claimSessionPersistenceOwnership()
            guard ownsSessionPersistence,
                  let crashReportingIntegration else {
                result(nil)
                return
            }
            crashReportQueue.async {
                let purged = crashReportingIntegration.purgePendingCrashReport()
                DispatchQueue.main.async {
                    if purged {
                        result(nil)
                    } else {
                        result(
                            FlutterError(
                                code: "crash_report_purge_failed",
                                message: "Could not purge the iOS crash report.",
                                details: nil
                            )
                        )
                    }
                }
            }
        case "getPlatformVersion":
                result("iOS " + UIDevice.current.systemVersion);
            case "uptimeUI":
                result(CACurrentMediaTime());
            case "initMobileApp":
                result("IOS init");
            case "getAppStart":
                result(AppStartTracker.coldStartMetrics());
            case "getProcessVitals":
                let arguments = call.arguments as? [String: Any]
                let readCpu = arguments?["cpu"] as? Bool == true
                let readMemory = arguments?["memory"] as? Bool == true
                processVitalsQueue.async {
                    let vitals = ProcessVitals.read(cpu: readCpu, memory: readMemory)
                    DispatchQueue.main.async {
                        result(vitals)
                    }
                }
            case "getANRStatus":
                result("ANRStatus");
            case "getSessionRuntimeInfo":
                let arguments = call.arguments as? [String: Any]
                if arguments?["claimSessionPersistence"] as? Bool == true {
                    claimSessionPersistenceOwnership()
                }
                let processIdentifier = Bundle.main.bundleIdentifier
                    ?? ProcessInfo.processInfo.processName
                result([
                    "processIdentifier": processIdentifier,
                    "ownsSessionPersistence": ownsSessionPersistence,
                ])
            case "getDeviceMetadata":
                result(DeviceMetadata.current())
            default:
                result(FlutterMethodNotImplemented);
        }

      }

  private func claimSessionPersistenceOwnership() {
    // Registration also runs for pre-warmed engines. Claim only when a root
    // Dart runtime actually initializes Faro.
    FaroPlugin.sessionPersistenceOwnerLock.lock()
    defer { FaroPlugin.sessionPersistenceOwnerLock.unlock() }

    guard !ownsSessionPersistence else { return }
    guard !FaroPlugin.sessionPersistenceOwnerClaimed else { return }

    FaroPlugin.sessionPersistenceOwnerClaimed = true
    ownsSessionPersistence = true
  }
}

/// Streams the listener-fed device state: the current values when Dart starts
/// listening, then the latest values after each change. Each event reads the
/// cache when it is sent, so a later change never arrives before an earlier one.
private final class DeviceStateStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var groups: Set<DynamicDeviceState.Group> = []

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    groups = DynamicDeviceState.groups(from: arguments)
    DynamicDeviceState.addObserver(self) { [weak self] in
      DispatchQueue.main.async {
        guard let self, let sink = self.sink else {
          return
        }
        sink(DynamicDeviceState.listenedState(groups: self.groups))
      }
    }
    events(DynamicDeviceState.startListening(owner: self, groups: groups))
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    DynamicDeviceState.removeObserver(self)
    DynamicDeviceState.stopListening(owner: self)
    sink = nil
    return nil
  }

  deinit {
    DynamicDeviceState.removeObserver(self)
    DynamicDeviceState.stopListening(owner: self)
  }
}
