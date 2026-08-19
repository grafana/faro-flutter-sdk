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
            case "getCpuUsage":
                result(CPUInfo.getCpuInfo());
            case "initRefreshRate":
                let _ = RefreshRateVitals()
                result(nil)
            case "getRefreshRate":
                result(RefreshRateVitals.lastRefreshRate)
            case "getANRStatus":
                result("ANRStatus");
            case "getMemoryUsage":
                print("getMemoryUsage");
            var _:[String] = [];
                _ = CACurrentMediaTime();
                let memory = getMemoryUsage()/1024
                result( memory);
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

      func getMemoryUsage() -> Double {
         let task_vm_info_count = MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size

                var vmInfo = task_vm_info()
                var vmInfoSize = mach_msg_type_size_t(task_vm_info_count)

                let kern: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        task_info(
                            mach_task_self_,
                            task_flavor_t(TASK_VM_INFO),
                            $0,
                            &vmInfoSize
                        )
                    }
                }

                if kern == KERN_SUCCESS {
                   // print(vmInfo.resident_size);
                     return Double(vmInfo.resident_size)
                } else {
                    //print("kern size undefined");
                     return 0.0
                }
        }


}
