import Darwin
import Foundation

/// Reads raw app process counters for the Dart CPU and memory sampler.
///
/// Only reads counters. Windows, the CPU formula and the cadence live in
/// Dart. `task_info` and `getrusage` must not run on the main thread, so call
/// `read` from a background queue.
enum ProcessVitals {
  static let memoryBasis = "phys_footprint"

  /// Returns `monotonicNanos`, `timestampMillis` and, when requested and
  /// readable, CPU and memory counters. A counter that cannot be read is left
  /// out.
  static func read(cpu: Bool, memory: Bool) -> [String: Any] {
    var result: [String: Any] = [:]
    if cpu, let cpuTimeSeconds = cpuTimeSeconds() {
      result["cpuTimeSeconds"] = cpuTimeSeconds
      result["cpuCount"] = ProcessInfo.processInfo.activeProcessorCount
    }
    if memory, let memoryBytes = physFootprintBytes() {
      result["memoryBytes"] = memoryBytes
      result["memoryBasis"] = memoryBasis
    }
    result["monotonicNanos"] = Int64(clamping: clock_gettime_nsec_np(CLOCK_UPTIME_RAW))
    result["timestampMillis"] = Int64(Date().timeIntervalSince1970 * 1000)
    return result
  }

  /// User plus system CPU time of the whole process, including threads that
  /// have already exited, in seconds.
  static func cpuTimeSeconds() -> Double? {
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
      return nil
    }
    return cpuTimeSeconds(user: usage.ru_utime, system: usage.ru_stime)
  }

  static func cpuTimeSeconds(user: timeval, system: timeval) -> Double {
    seconds(user) + seconds(system)
  }

  /// The app's physical footprint in bytes, the figure jetsam and Xcode use.
  static func physFootprintBytes() -> Int64? {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
    )
    let kern = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard kern == KERN_SUCCESS else {
      return nil
    }
    return footprintBytes(info.phys_footprint)
  }

  /// A usable footprint in bytes, or `nil` when it is 0 or does not fit.
  static func footprintBytes(_ physFootprint: UInt64) -> Int64? {
    guard physFootprint > 0, physFootprint <= UInt64(Int64.max) else {
      return nil
    }
    return Int64(physFootprint)
  }

  private static func seconds(_ value: timeval) -> Double {
    Double(value.tv_sec) + Double(value.tv_usec) / 1_000_000
  }
}
