import Foundation
import UIKit

/// Device metadata that device_info_plus does not expose.
enum DeviceMetadata {
  static let osBuildIdKey = "osBuildId"
  static let archKey = "arch"
  static let screenWidthKey = "screenWidth"
  static let screenHeightKey = "screenHeight"
  static let screenDensityKey = "screenDensity"
  static let memoryTotalKey = "memoryTotal"

  static func current() -> [String: Any] {
    #if targetEnvironment(simulator)
      let isSimulator = true
    #else
      let isSimulator = false
    #endif
    let processInfo = ProcessInfo.processInfo
    let osBuildId = resolveOsBuildId(
      isSimulator: isSimulator,
      // isMacCatalystApp is also true for an unmodified iOS app on an Apple
      // silicon Mac (see its doc comment in NSProcessInfo.h).
      isRunningOnNonIOSHost: processInfo.isMacCatalystApp
        || isiOSAppOnVision(processInfo),
      simulatorRuntimeBuild: processInfo.environment["SIMULATOR_RUNTIME_BUILD_VERSION"],
      kernelOsVersion: sysctlString("kern.osversion")
    )
    var metadata: [String: Any] = [:]
    if let osBuildId {
      metadata[osBuildIdKey] = osBuildId
    }
    if let arch = cpuArchitecture {
      metadata[archKey] = arch
    }
    // nativeBounds is in physical pixels and does not rotate with the
    // interface, unlike bounds.
    let screen = UIScreen.main
    metadata[screenWidthKey] = Int(screen.nativeBounds.width)
    metadata[screenHeightKey] = Int(screen.nativeBounds.height)
    metadata[screenDensityKey] = Double(screen.nativeScale)
    metadata[memoryTotalKey] = Int(clamping: processInfo.physicalMemory)
    return metadata
  }

  /// The architecture this process is built for, such as "arm64".
  ///
  /// iOS runs no 32-bit apps, so this is also the device's architecture,
  /// except for an x86_64 simulator under Rosetta.
  static var cpuArchitecture: String? {
    #if arch(arm64)
      return "arm64"
    #elseif arch(x86_64)
      return "x86_64"
    #else
      return nil
    #endif
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

  /// Whether this iPhone or iPad app runs on an Apple Vision Pro.
  ///
  /// There the app sees an iPad `hw.machine`, so the hardware identifier
  /// cannot tell.
  static func isiOSAppOnVision(_ processInfo: ProcessInfo) -> Bool {
    // Looked up at run time: calling the property directly needs the iOS
    // 26.1 SDK to build, and it exists only on visionOS 26.1 and later.
    let getter = "isiOSAppOnVision"
    if processInfo.responds(to: NSSelectorFromString(getter)) {
      return (processInfo.value(forKey: getter) as? Bool) ?? false
    }
    // Before visionOS 26.1. This UIKit class exists only on visionOS.
    return NSClassFromString("UIWindowSceneGeometryPreferencesVision") != nil
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
