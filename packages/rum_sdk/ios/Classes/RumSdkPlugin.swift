import Flutter
import UIKit
import Foundation
import CrashReporter


public class RumSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "rum_sdk", binaryMessenger: registrar.messenger())
    let instance = RumSdkPlugin()
      
//    if(isCrashReportAutoEnabled() == true){
//          let crashreporter = CrashReportingIntegration()
//    }
    registrar.addMethodCallDelegate(instance, channel: channel)
    NotificationCenter.default.addObserver(instance, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

  }
    
    private static func isCrashReportAutoEnabled() -> Bool{
        return false
    }

  deinit {
    // Remove observers or perform other cleanup here
    AppStart.clear()
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func applicationDidBecomeActive() {
    // Handle the app becoming active
      var time: timeval = timeval(tv_sec: 0, tv_usec: 0)
      gettimeofday(&time, nil)

      let currentTimeMilliseconds = Double(Int64(time.tv_sec) * 1000) + Double(time.tv_usec) / 1000.0
      AppStart.setAppStartEndMillis(currentTimeMilliseconds)
      
  }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enableCrashReporter":
            do{
                let crashReporter = try CrashReportingIntegration(crashReporterConfig: call.arguments as! [String: Any])
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
                let appStart = Int64(AppStart.getAppStartDuration())
                let appStartMetrics: [String: Any] = [
                   "appStartDuration": appStart,
               ]
               result(appStartMetrics);
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
                var lastEventTime = CACurrentMediaTime();
                var memory = getMemoryUsage()/1024
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

