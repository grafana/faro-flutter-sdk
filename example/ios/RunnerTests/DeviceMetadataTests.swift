import Testing

@testable import faro

@Suite("DeviceMetadata")
struct DeviceMetadataTests {

  @Test("reports the kernel build on a device")
  func deviceUsesKernelBuild() {
    #expect(
      DeviceMetadata.resolveOsBuildId(
        isSimulator: false,
        isRunningOnNonIOSHost: false,
        simulatorRuntimeBuild: nil,
        kernelOsVersion: "24A437"
      ) == "24A437"
    )
  }

  @Test("reports the simulated runtime build, not the host Mac build")
  func simulatorUsesRuntimeBuild() {
    #expect(
      DeviceMetadata.resolveOsBuildId(
        isSimulator: true,
        isRunningOnNonIOSHost: false,
        simulatorRuntimeBuild: "23F77",
        kernelOsVersion: "25G83"
      ) == "23F77"
    )
  }

  @Test("reports nothing on a simulator without the runtime build")
  func simulatorWithoutRuntimeBuild() {
    #expect(
      DeviceMetadata.resolveOsBuildId(
        isSimulator: true,
        isRunningOnNonIOSHost: false,
        simulatorRuntimeBuild: nil,
        kernelOsVersion: "25G83"
      ) == nil
    )
  }

  @Test("reports nothing for an iOS app running on a Mac or Vision Pro")
  func runningOnNonIOSHost() {
    #expect(
      DeviceMetadata.resolveOsBuildId(
        isSimulator: false,
        isRunningOnNonIOSHost: true,
        simulatorRuntimeBuild: nil,
        kernelOsVersion: "25G83"
      ) == nil
    )
  }

  @Test("recognizes an Apple Vision Pro hardware identifier")
  func visionMachine() {
    #expect(DeviceMetadata.isVisionMachine("RealityDevice14,1"))
    #expect(!DeviceMetadata.isVisionMachine("iPad14,3"))
    #expect(!DeviceMetadata.isVisionMachine("arm64"))
    #expect(!DeviceMetadata.isVisionMachine(nil))
  }

  @Test("reports nothing for a missing or blank build", arguments: [nil, "", " \n"] as [String?])
  func missingBuild(value: String?) {
    #expect(
      DeviceMetadata.resolveOsBuildId(
        isSimulator: false,
        isRunningOnNonIOSHost: false,
        simulatorRuntimeBuild: value,
        kernelOsVersion: value
      ) == nil
    )
  }

  @Test("decodes a buffer that has no NUL terminator")
  func decodeWithoutTerminator() {
    #expect(DeviceMetadata.decode(Array("22G91".utf8CString.dropLast())) == "22G91")
  }

  @Test("stops decoding at the first NUL")
  func decodeStopsAtNul() {
    #expect(DeviceMetadata.decode([0x32, 0x34, 0x41, 0, 0x41]) == "24A")
  }

  @Test("treats empty and invalid UTF-8 buffers as unknown")
  func decodeRejectsUnusableBuffers() {
    #expect(DeviceMetadata.decode([]) == nil)
    #expect(DeviceMetadata.decode([0]) == nil)
    #expect(DeviceMetadata.decode([CChar(bitPattern: 0xFF), 0]) == nil)
  }

  @Test("reads kern.osversion from the running kernel")
  func readsLiveKernelBuild() {
    #expect(DeviceMetadata.sysctlString("kern.osversion")?.isEmpty == false)
  }

  @Test("reports nothing for an unknown sysctl")
  func unknownSysctl() {
    #expect(DeviceMetadata.sysctlString("kern.faro_does_not_exist") == nil)
  }

  // The Dart side reads this key by name and ignores any other key.
  @Test("uses the key the Dart side reads")
  func osBuildIdKey() {
    #expect(DeviceMetadata.osBuildIdKey == "osBuildId")
  }
}
