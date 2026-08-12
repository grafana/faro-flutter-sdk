import Flutter
import UIKit
import Foundation
import CrashReporter


public class FaroPlugin: NSObject, FlutterPlugin {
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

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enableCrashReporter":
            do{
                _ = try CrashReportingIntegration(crashReporterConfig: call.arguments as! [String: Any])
            } catch {
                print("crash reporter not initialized")
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
            default:
                result(FlutterMethodNotImplemented);
        }

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

