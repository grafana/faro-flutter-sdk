import Foundation

/// Device metadata that device_info_plus does not expose.
enum DeviceMetadata {
  static let osBuildIdKey = "osBuildId"

  static func current() -> [String: Any] {
    #if targetEnvironment(simulator)
      let isSimulator = true
    #else
      let isSimulator = false
    #endif
    let processInfo = ProcessInfo.processInfo
    let osBuildId = resolveOsBuildId(
      isSimulator: isSimulator,
      isRunningOnNonIOSHost: processInfo.isMacCatalystApp
        || isVisionMachine(sysctlString("hw.machine")),
      simulatorRuntimeBuild: processInfo.environment["SIMULATOR_RUNTIME_BUILD_VERSION"],
      kernelOsVersion: sysctlString("kern.osversion")
    )
    guard let osBuildId else { return [:] }
    return [osBuildIdKey: osBuildId]
  }

  /// Picks the OS build to report, such as "24A437", or nil when unknown.
  ///
  /// Takes its inputs rather than reading them so every arm can be tested.
  static func resolveOsBuildId(
    isSimulator: Bool,
    isRunningOnNonIOSHost: Bool,
    simulatorRuntimeBuild: String?,
    kernelOsVersion: String?
  ) -> String? {
    if isSimulator {
      // A simulator shares the host kernel, so kern.osversion is the Mac's
      // build. CoreSimulator puts the simulated runtime's build in the
      // environment.
      return nonEmpty(simulatorRuntimeBuild)
    }
    if isRunningOnNonIOSHost {
      // An iOS app on a Mac or an Apple Vision Pro runs on that platform's
      // kernel. Its build does not belong next to the iOS os.name and
      // os.version the app reports.
      return nil
    }
    return nonEmpty(kernelOsVersion)
  }

  /// Whether a hardware identifier is an Apple Vision Pro, such as
  /// "RealityDevice14,1".
  ///
  /// `ProcessInfo.isiOSAppOnVision` would need the iOS 26.1 SDK to build.
  static func isVisionMachine(_ machine: String?) -> Bool {
    machine?.hasPrefix("RealityDevice") ?? false
  }

  /// Reads a string sysctl. Sizes the buffer first so the value is never
  /// truncated.
  static func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else {
      return nil
    }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else {
      return nil
    }
    return decode(buffer)
  }

  /// Decodes up to the first NUL, without reading past the buffer when the
  /// kernel returned no terminator.
  static func decode(_ buffer: [CChar]) -> String? {
    let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return nonEmpty(String(bytes: bytes, encoding: .utf8))
  }

  private static func nonEmpty(_ value: String?) -> String? {
    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
      !trimmed.isEmpty
    else {
      return nil
    }
    return trimmed
  }
}
