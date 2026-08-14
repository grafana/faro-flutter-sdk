import Testing

@testable import faro

@Suite("CrashReportingIntegration")
struct CrashReportingIntegrationTests {

  @Test("reports pending crashes by default")
  func reportsPendingCrashByDefault() {
    #expect(CrashReportingIntegration.shouldReportPendingCrash(config: [:]))
  }

  @Test("does not report a crash from an unsampled session")
  func skipsPendingCrashForUnsampledSession() {
    #expect(
      !CrashReportingIntegration.shouldReportPendingCrash(
        config: ["reportPendingCrash": false]
      )
    )
  }

  @Test("ignores malformed sampling configuration")
  func ignoresMalformedSamplingConfiguration() {
    #expect(
      CrashReportingIntegration.shouldReportPendingCrash(
        config: ["reportPendingCrash": "false"]
      )
    )
  }
}
