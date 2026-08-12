import Foundation

/// Measures how long a cold start took, from the earliest anchor the SDK can
/// observe until the Dart side reports the first frame.
///
/// Two things make a naive "now minus process start time" measurement wrong:
///
/// - iOS may *prewarm* an app: it creates the process and loads the linked
///   libraries ahead of the user tapping the icon, then suspends it. The gap
///   before the real launch can be minutes or hours, so measuring from process
///   start reports idle time rather than anything the user waited for.
/// - `kp_proc.p_starttime` comes from the calendar clock, the same settable
///   clock `gettimeofday` reads. A clock correction inside the measurement
///   window can skew the result or make it negative.
///
/// Prewarmed launches are re-based onto a monotonic anchor taken when the SDK
/// loads, which is close to `main()`. They are still reported: a prewarmed
/// launch is a real launch, and one the user genuinely experiences as faster.
/// The `prewarmed` flag travels with the measurement so the two distributions
/// can be separated later.
///
/// The upper bound on a plausible cold start is applied on the Dart side, so
/// that the same limit holds on Android and iOS.
enum AppStartTracker {

  /// Whether iOS prewarmed this process, as read before the flag is cleared.
  private static var isPrewarmedLaunch = false

  /// Monotonic anchor captured when the SDK loaded, in milliseconds.
  private static var sdkLoadUptimeMillis: Double?

  /// Captures the launch anchors.
  ///
  /// Must run as early as possible. iOS removes `ActivePrewarm` from the
  /// environment once the app has finished launching, so reading it any later
  /// reports every launch as non-prewarmed.
  static func recordSdkLoad() {
    guard sdkLoadUptimeMillis == nil else { return }
    isPrewarmedLaunch = ProcessInfo.processInfo.environment["ActivePrewarm"] == "1"
    sdkLoadUptimeMillis = uptimeMillis()
  }

  /// The cold start payload for the Dart side.
  ///
  /// `isUserVisibleColdStart` is false only when no start anchor could be
  /// established, in which case `appStartDurationMillis` is meaningless.
  static func coldStartMetrics() -> [String: Any] {
    let duration = durationMillis()
    return [
      "appStartDurationMillis": millisAsInt(duration),
      "isUserVisibleColdStart": duration != nil,
      "prewarmed": isPrewarmedLaunch,
    ]
  }

  private static func durationMillis() -> Double? {
    launchDurationMillis(
      prewarmed: isPrewarmedLaunch,
      sdkLoadAnchor: sdkLoadUptimeMillis,
      uptimeNow: uptimeMillis(),
      processStart: processStartWallclockMillis(),
      wallclockNow: wallclockMillis()
    )
  }

  /// Picks the anchor to measure from, or nil when neither is usable.
  ///
  /// Process start is meaningless for a prewarmed launch, and the SDK load
  /// anchor is monotonic, so that arm is also immune to clock changes.
  ///
  /// Takes its inputs rather than reading them so both arms can be tested. The
  /// prewarmed arm is otherwise unreachable from a test: `ActivePrewarm` is
  /// read once when the SDK loads, and iOS clears it after launch.
  static func launchDurationMillis(
    prewarmed: Bool,
    sdkLoadAnchor: Double?,
    uptimeNow: Double,
    processStart: Double?,
    wallclockNow: Double
  ) -> Double? {
    if prewarmed {
      guard let sdkLoadAnchor else { return nil }
      return uptimeNow - sdkLoadAnchor
    }
    guard let processStart else { return nil }
    return wallclockNow - processStart
  }

  /// Converts to the integer the method channel carries, without trapping.
  ///
  /// `Int64(Double)` is a runtime trap for NaN and out-of-range values, both of
  /// which a corrupted clock reading can produce.
  static func millisAsInt(_ value: Double?) -> Int64 {
    guard let value,
      value.isFinite,
      value > Double(Int64.min),
      value < Double(Int64.max)
    else {
      return -1
    }
    return Int64(value)
  }

  private static func processStartWallclockMillis() -> Double? {
    var info = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0 else {
      return nil
    }
    let startTime = info.kp_proc.p_starttime
    return Double(startTime.tv_sec) * 1000.0 + Double(startTime.tv_usec) / 1000.0
  }

  private static func wallclockMillis() -> Double {
    var time = timeval(tv_sec: 0, tv_usec: 0)
    gettimeofday(&time, nil)
    return Double(time.tv_sec) * 1000.0 + Double(time.tv_usec) / 1000.0
  }

  /// Milliseconds since boot, excluding time the device spent asleep.
  private static func uptimeMillis() -> Double {
    return Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000.0
  }
}
