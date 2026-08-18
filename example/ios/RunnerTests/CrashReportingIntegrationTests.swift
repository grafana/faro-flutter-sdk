import Foundation
import Testing

@testable import faro

@Suite("CrashReportingIntegration")
struct CrashReportingIntegrationTests {

  private struct TestError: Error {}

  @Test("leaves the reporter untouched when no crash is pending")
  func noPendingCrash() {
    var loadCount = 0
    var purgeCount = 0
    let integration = CrashReportingIntegration(
      hasPendingCrashReport: { false },
      loadPendingCrashReport: {
        loadCount += 1
        return Data()
      },
      purgePendingCrashReport: {
        purgeCount += 1
        return true
      },
      exportCrashReport: { _ in [:] }
    )

    #expect(integration.takePendingCrashReports().isEmpty)
    #expect(loadCount == 0)
    #expect(purgeCount == 0)
  }

  @Test("returns a structured pending crash and purges it once")
  func pendingCrash() throws {
    var purgeCount = 0
    let integration = CrashReportingIntegration(
      hasPendingCrashReport: { true },
      loadPendingCrashReport: { Data([1, 2, 3]) },
      purgePendingCrashReport: {
        purgeCount += 1
        return true
      },
      exportCrashReport: { data in
        #expect(data == Data([1, 2, 3]))
        return [
          "type": "SIGSEGV",
          "value": "Application crash",
          "stacktrace": [
            "frames": [["filename": "Runner", "lineno": 42]]
          ],
          "timestamp": "2026-08-18T12:00:00.000Z",
          "fatal": true,
        ]
      }
    )

    let reports = integration.takePendingCrashReports()
    let report = try #require(reports.first)
    let object = try #require(
      try JSONSerialization.jsonObject(with: Data(report.utf8))
        as? [String: Any]
    )
    let stacktrace = try #require(object["stacktrace"] as? [String: Any])
    let frames = try #require(stacktrace["frames"] as? [[String: Any]])

    #expect(reports.count == 1)
    #expect(object["type"] as? String == "SIGSEGV")
    #expect(frames.first?["filename"] as? String == "Runner")
    #expect(purgeCount == 1)
  }

  @Test("purges a pending crash that cannot be loaded")
  func malformedPendingCrash() {
    var purgeCount = 0
    let integration = CrashReportingIntegration(
      hasPendingCrashReport: { true },
      loadPendingCrashReport: { throw TestError() },
      purgePendingCrashReport: {
        purgeCount += 1
        return true
      },
      exportCrashReport: { _ in [:] }
    )

    #expect(integration.takePendingCrashReports().isEmpty)
    #expect(purgeCount == 1)
  }
}
