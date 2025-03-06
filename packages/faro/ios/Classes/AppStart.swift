import Foundation

class AppStart {

  private static let instance = AppStart()

  private static let MAX_APP_START_DURATION: Double = 60000.0

  private static var appStartMillis: Double?
  private static var appStartEndMillis: Double = 0.0

  private static var warmStartMillis: Double?


  private init() {}

  // MARK: - Getter
  static func getInstance() -> AppStart {
      return instance
  }


  static func getAppStartMillis() -> Double? {
      return appStartMillis
  }

  static func getAppStartEndMillis() -> Double? {
      return appStartEndMillis
  }

  static func getWarmStartMillis() -> Double? {
      return warmStartMillis
  }

  static func getAppStartDuration() -> Double {
    var appStartDuration: Double = 0.0
    var kinfo = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    sysctl(&mib, u_int(mib.count), &kinfo, &size, nil, 0)

    let start_time = kinfo.kp_proc.p_starttime
    var time: timeval = timeval(tv_sec: 0, tv_usec: 0)
    gettimeofday(&time, nil)

    let currentTimeMilliseconds = Double(Int64(time.tv_sec) * 1000) + Double(time.tv_usec) / 1000.0
    let processTimeMilliseconds = Double(Int64(start_time.tv_sec) * 1000) + Double(start_time.tv_usec) / 1000.0

    appStartDuration =  (currentTimeMilliseconds - processTimeMilliseconds)

    let AppStartEndMillis = getAppStartEndMillis()!
    if let appStartMillis = getAppStartEndMillis() {
        let appStartDuration = Double(appStartMillis) - (ProcessInfo.processInfo.systemUptime * 1000)
    }

    return appStartDuration
  }

  static func getColdStartDuration() -> Double {
      let coldStartDuration: Double = 0.0
      return coldStartDuration
  }

  static func setWarmStartMillis(_ warmStartMillis: Double) {
      self.warmStartMillis = warmStartMillis
  }

  static func setAppStartMillis(_ appStartMillis: Double) {
      self.appStartMillis = appStartMillis
  }

  static func setAppStartEndMillis(_ appStartEndMillis: Double) {
      self.appStartEndMillis = appStartEndMillis
  }

  static func clear() {
      appStartMillis = nil
      appStartEndMillis = 0.0
  }
}

