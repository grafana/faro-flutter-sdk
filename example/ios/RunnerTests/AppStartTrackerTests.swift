import Testing

@testable import faro

/// Covers the three things the Dart side depends on: that a launch is measured
/// from the right anchor, that a corrupted clock reading yields a sentinel
/// rather than trapping, and that the payload keeps the keys
/// `NativeIntegration.getAppStart` reads.
@Suite("AppStartTracker")
struct AppStartTrackerTests {

  @Test("measures a prewarmed launch from the SDK load anchor")
  func prewarmedLaunchIgnoresProcessStart() {
    // The process was created an hour before the user tapped the icon, so its
    // start time would report that hour as the launch.
    let duration = AppStartTracker.launchDurationMillis(
      prewarmed: true,
      sdkLoadAnchor: 1_000,
      uptimeNow: 1_400,
      processStart: 0,
      wallclockNow: 3_600_000
    )

    #expect(duration == 400)
  }

  @Test("reports nothing for a prewarmed launch with no anchor")
  func prewarmedLaunchWithoutAnchor() {
    #expect(
      AppStartTracker.launchDurationMillis(
        prewarmed: true,
        sdkLoadAnchor: nil,
        uptimeNow: 1_400,
        processStart: 0,
        wallclockNow: 3_600_000
      ) == nil
    )
  }

  @Test("measures an ordinary launch from process start")
  func ordinaryLaunchUsesProcessStart() {
    let duration = AppStartTracker.launchDurationMillis(
      prewarmed: false,
      sdkLoadAnchor: 1_000,
      uptimeNow: 1_400,
      processStart: 3_000,
      wallclockNow: 3_900
    )

    #expect(duration == 900)
  }

  @Test("reports nothing when the process start lookup failed")
  func ordinaryLaunchWithoutProcessStart() {
    #expect(
      AppStartTracker.launchDurationMillis(
        prewarmed: false,
        sdkLoadAnchor: 1_000,
        uptimeNow: 1_400,
        processStart: nil,
        wallclockNow: 3_900
      ) == nil
    )
  }

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
