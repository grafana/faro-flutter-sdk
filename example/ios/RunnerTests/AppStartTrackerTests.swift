import Testing

@testable import faro

/// Covers the two things the Dart side depends on: that a corrupted clock
/// reading yields a sentinel rather than trapping, and that the payload keeps
/// the keys `NativeIntegration.getAppStart` reads.
@Suite("AppStartTracker")
struct AppStartTrackerTests {

  @Test(
    "returns the sentinel instead of trapping",
    arguments: [
      Double.nan,
      .infinity,
      -.infinity,
      .greatestFiniteMagnitude,
      -.greatestFiniteMagnitude,
      Double(Int64.max),
      Double(Int64.min),
    ]
  )
  func rejectsValuesOutsideTheConvertibleRange(value: Double) {
    #expect(AppStartTracker.millisAsInt(value) == -1)
  }

  @Test("returns the sentinel when no anchor was established")
  func rejectsMissingValue() {
    #expect(AppStartTracker.millisAsInt(nil) == -1)
  }

  @Test("truncates a plausible duration towards zero")
  func truncatesPlausibleDuration() {
    #expect(AppStartTracker.millisAsInt(1234.9) == 1234)
  }

  @Test("carries the keys the Dart side reads")
  func payloadUsesTheAgreedKeys() {
    let metrics = AppStartTracker.coldStartMetrics()

    #expect(metrics["isUserVisibleColdStart"] as? Bool == true)
    #expect(metrics["prewarmed"] as? Bool == false)
    #expect((metrics["appStartDurationMillis"] as? Int64 ?? -1) > 0)
  }
}
