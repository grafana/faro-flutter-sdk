import Foundation
import Testing

@testable import faro

@Suite("ProcessVitals")
struct ProcessVitalsTests {

  @Test("adds user and system time, keeping fractions of a second")
  func cpuTimeAddsUserAndSystem() {
    let seconds = ProcessVitals.cpuTimeSeconds(
      user: timeval(tv_sec: 3, tv_usec: 250_000),
      system: timeval(tv_sec: 1, tv_usec: 500_000)
    )
    #expect(seconds == 4.75)
  }

  @Test("reads the CPU time of this process, which only grows")
  func liveCpuTimeGrows() throws {
    let before = try #require(ProcessVitals.cpuTimeSeconds())
    var sink = 0.0
    for index in 0..<2_000_000 {
      sink += sqrt(Double(index))
    }
    #expect(sink > 0)
    let after = try #require(ProcessVitals.cpuTimeSeconds())
    #expect(before > 0)
    #expect(after > before)
  }

  @Test("includes CPU time of threads that already exited")
  func cpuTimeIncludesExitedThreads() async throws {
    let before = try #require(ProcessVitals.cpuTimeSeconds())
    let threadCpuSeconds = ThreadCpuBox()
    let thread = Thread {
      var sink = 0.0
      for index in 0..<5_000_000 {
        sink += sqrt(Double(index) + sink.truncatingRemainder(dividingBy: 1))
      }
      var time = timespec()
      clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
      threadCpuSeconds.set(
        Double(time.tv_sec) + Double(time.tv_nsec) / 1_000_000_000,
        work: sink
      )
    }
    thread.start()
    while !thread.isFinished {
      try await Task.sleep(nanoseconds: 10_000_000)
    }
    let after = try #require(ProcessVitals.cpuTimeSeconds())
    let workerSeconds = try #require(threadCpuSeconds.get())
    #expect(workerSeconds > 0)
    // The worker is gone; the process total must still include all of its
    // CPU time. getrusage has microsecond resolution, so allow 1 ms.
    #expect(after - before >= workerSeconds - 0.001)
  }

  @Test("reports the physical footprint in bytes")
  func livePhysFootprint() throws {
    let bytes = try #require(ProcessVitals.physFootprintBytes())
    #expect(bytes > 1_048_576)
  }

  @Test("treats a zero footprint as a failed read")
  func zeroFootprintIsNil() {
    #expect(ProcessVitals.footprintBytes(0) == nil)
    #expect(ProcessVitals.footprintBytes(UInt64.max) == nil)
    #expect(ProcessVitals.footprintBytes(222_715_904) == 222_715_904)
  }

  @Test("always includes the wall-clock capture time in milliseconds")
  func readIncludesTimestamp() throws {
    let before = Int64(Date().timeIntervalSince1970 * 1000)
    let vitals = ProcessVitals.read(cpu: false, memory: false)
    let after = Int64(Date().timeIntervalSince1970 * 1000)
    let timestamp = try #require(vitals["timestampMillis"] as? Int64)
    #expect(timestamp >= before && timestamp <= after)
  }

  @Test("returns only the requested counters with a monotonic clock")
  func readReturnsRequestedCounters() throws {
    let first = ProcessVitals.read(cpu: true, memory: true)
    #expect(first["cpuTimeSeconds"] is Double)
    #expect(first["cpuCount"] as? Int == ProcessInfo.processInfo.activeProcessorCount)
    #expect(first["memoryBytes"] is Int64)
    #expect(first["memoryBasis"] as? String == "phys_footprint")

    let second = ProcessVitals.read(cpu: false, memory: false)
    #expect(second["cpuTimeSeconds"] == nil)
    #expect(second["memoryBytes"] == nil)
    let start = try #require(first["monotonicNanos"] as? Int64)
    let end = try #require(second["monotonicNanos"] as? Int64)
    #expect(end >= start)
  }
}

/// Hands the worker thread's CPU time to the test.
private final class ThreadCpuBox: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Double?
  private(set) var work = 0.0

  /// [work] keeps the loop result alive so the loop is not optimized away.
  func set(_ newValue: Double, work: Double) {
    lock.lock()
    value = newValue
    self.work = work
    lock.unlock()
  }

  func get() -> Double? {
    lock.lock()
    defer { lock.unlock() }
    return value
  }
}
