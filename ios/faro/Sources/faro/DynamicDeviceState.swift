import CoreTelephony
import Foundation
import Network
import UIKit

/// Device and network values that change while the app runs.
///
/// Every value a system notification can update is listener-fed: battery, Low
/// Power Mode, thermal state, connection type and the cellular technology. The
/// notifications keep a cache and tell observers when it changes. They start
/// on the first read, not when the plugin loads. Nothing here needs a
/// permission, and every value is omitted when it cannot be read. iOS never
/// reports a carrier.
enum DynamicDeviceState {
  static let batteryLevelKey = "batteryLevel"
  static let isChargingKey = "isCharging"
  static let lowPowerModeKey = "lowPowerMode"
  static let thermalStateKey = "thermalState"
  static let connectionTypeKey = "connectionType"
  static let connectionSubtypeKey = "connectionSubtype"
  static let versionKey = "version"

  private static let lock = NSLock()
  private static var started = false
  private static var monitor: NWPathMonitor?
  private static var latestPath: NWPath?
  private static var listenedCache: [String: Any] = [:]
  /// Numbers each listener-fed snapshot, so Dart can tell which of two is
  /// newer.
  private static var listenedVersion = 0
  private static var observers: [ObjectIdentifier: ([String: Any]) -> Void] = [:]
  private static let telephonyInfo = CTTelephonyNetworkInfo()

  /// Starts the system listeners once. Safe to call more than once. The plugin
  /// calls it on the main thread, where it seeds the cache before it returns.
  /// A call from another thread hops to the main thread, and a second caller
  /// that races it can read an empty cache.
  static func start() {
    lock.lock()
    if started {
      lock.unlock()
      return
    }
    started = true
    lock.unlock()

    if Thread.isMainThread {
      startListeners()
    } else {
      DispatchQueue.main.sync { startListeners() }
    }
  }

  private static func startListeners() {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      UIDevice.batteryLevelDidChangeNotification,
      UIDevice.batteryStateDidChangeNotification,
      .NSProcessInfoPowerStateDidChange,
      ProcessInfo.thermalStateDidChangeNotification,
      // Newer SDKs import this constant as a Notification.Name and older ones as
      // a String, so the literal compiles on both.
      Notification.Name("CTServiceRadioAccessTechnologyDidChangeNotification"),
    ]
    for name in names {
      center.addObserver(forName: name, object: nil, queue: .main) { _ in
        refreshListened()
      }
    }

    let pathMonitor = NWPathMonitor()
    pathMonitor.pathUpdateHandler = { path in
      lock.lock()
      latestPath = path
      lock.unlock()
      DispatchQueue.main.async {
        refreshListened()
      }
    }
    pathMonitor.start(queue: DispatchQueue(label: "com.grafana.faro.network-path", qos: .utility))
    lock.lock()
    monitor = pathMonitor
    lock.unlock()
    refreshListened()
  }

  /// Calls `observer` with the listener-fed values each time they change. The
  /// listeners start on the first read, so an app that never reads pays
  /// nothing.
  static func addObserver(_ owner: AnyObject, _ observer: @escaping ([String: Any]) -> Void) {
    lock.lock()
    observers[ObjectIdentifier(owner)] = observer
    lock.unlock()
  }

  static func removeObserver(_ owner: AnyObject) {
    lock.lock()
    observers[ObjectIdentifier(owner)] = nil
    lock.unlock()
  }

  /// The cached values that system notifications keep current.
  static func listenedState() -> [String: Any] {
    start()
    lock.lock()
    defer { lock.unlock() }
    return withVersion(listenedCache)
  }

  private static func withVersion(_ state: [String: Any]) -> [String: Any] {
    var numbered = state
    numbered[versionKey] = listenedVersion
    return numbered
  }

  /// Reads the system into the cache and tells observers when it changed.
  /// Runs on the main thread, where UIKit values are safe to read.
  private static func refreshListened() {
    var state: [String: Any] = [:]

    let device = UIDevice.current
    if let level = batteryPercent(device.batteryLevel) {
      state[batteryLevelKey] = level
    }
    if let charging = isCharging(device.batteryState) {
      state[isChargingKey] = charging
    }
    let processInfo = ProcessInfo.processInfo
    state[lowPowerModeKey] = processInfo.isLowPowerModeEnabled
    state[thermalStateKey] = thermalStateName(processInfo.thermalState)

    lock.lock()
    let path = latestPath
    lock.unlock()
    if let path {
      let type = connectionType(for: path)
      state[connectionTypeKey] = type
      if type == "cell",
        let subtype = connectionSubtypeName(radioTechnology: currentDataRadioTechnology())
      {
        state[connectionSubtypeKey] = subtype
      }
    }

    lock.lock()
    let changed = !NSDictionary(dictionary: listenedCache).isEqual(to: state)
    listenedCache = state
    if changed {
      listenedVersion += 1
    }
    let numbered = withVersion(state)
    let callbacks = Array(observers.values)
    lock.unlock()
    if changed {
      callbacks.forEach { $0(numbered) }
    }
  }

  /// Whole percent from 0 to 100, or nil when the system reports no level.
  static func batteryPercent(_ level: Float) -> Int? {
    guard level >= 0 else {
      return nil
    }
    return min(100, Int((level * 100).rounded()))
  }

  /// True when connected to power, whether charging or full.
  static func isCharging(_ state: UIDevice.BatteryState) -> Bool? {
    switch state {
    case .charging, .full:
      return true
    case .unplugged:
      return false
    default:
      return nil
    }
  }

  static func thermalStateName(_ state: ProcessInfo.ThermalState) -> String {
    switch state {
    case .nominal:
      return "nominal"
    case .fair:
      return "fair"
    case .serious:
      return "serious"
    case .critical:
      return "critical"
    @unknown default:
      return "critical"
    }
  }

  /// Checks the interface types in the same order as Android: wifi, then
  /// cell, then wired. A VPN is an `other` interface, and `usesInterfaceType`
  /// also reports the interface under it, so a VPN does not hide the
  /// connection.
  static func connectionType(for path: NWPath) -> String {
    connectionType(
      status: path.status,
      usesWifi: path.usesInterfaceType(.wifi),
      usesCellular: path.usesInterfaceType(.cellular),
      usesWired: path.usesInterfaceType(.wiredEthernet)
    )
  }

  static func connectionType(
    status: NWPath.Status,
    usesWifi: Bool,
    usesCellular: Bool,
    usesWired: Bool
  ) -> String {
    guard status == .satisfied else {
      return "unavailable"
    }
    if usesWifi {
      return "wifi"
    }
    if usesCellular {
      return "cell"
    }
    if usesWired {
      return "wired"
    }
    return "unknown"
  }

  /// The radio technology of the SIM that carries mobile data.
  private static func currentDataRadioTechnology() -> String? {
    dataRadioTechnology(
      technologies: telephonyInfo.serviceCurrentRadioAccessTechnology,
      dataServiceIdentifier: telephonyInfo.dataServiceIdentifier
    )
  }

  /// On a dual-SIM phone the other SIM can report a different technology, so
  /// it must not decide the subtype. Without a known data SIM and with more
  /// than one SIM reporting, there is nothing safe to pick.
  static func dataRadioTechnology(
    technologies: [String: String]?,
    dataServiceIdentifier: String?
  ) -> String? {
    guard let technologies else {
      return nil
    }
    if let dataServiceIdentifier, let technology = technologies[dataServiceIdentifier] {
      return technology
    }
    return technologies.count == 1 ? technologies.values.first : nil
  }

  /// Maps a `CTRadioAccessTechnology` value to an OpenTelemetry subtype name.
  static func connectionSubtypeName(radioTechnology: String?) -> String? {
    radioTechnology.flatMap { radioTechnologyNames[$0] }
  }

  private static let radioTechnologyNames: [String: String] = {
    var names: [String: String] = [
      CTRadioAccessTechnologyGPRS: "gprs",
      CTRadioAccessTechnologyEdge: "edge",
      CTRadioAccessTechnologyWCDMA: "umts",
      CTRadioAccessTechnologyHSDPA: "hsdpa",
      CTRadioAccessTechnologyHSUPA: "hsupa",
      CTRadioAccessTechnologyCDMA1x: "cdma",
      CTRadioAccessTechnologyCDMAEVDORev0: "evdo_0",
      CTRadioAccessTechnologyCDMAEVDORevA: "evdo_a",
      CTRadioAccessTechnologyCDMAEVDORevB: "evdo_b",
      CTRadioAccessTechnologyeHRPD: "ehrpd",
      CTRadioAccessTechnologyLTE: "lte",
    ]
    if #available(iOS 14.1, *) {
      names[CTRadioAccessTechnologyNRNSA] = "nrnsa"
      names[CTRadioAccessTechnologyNR] = "nr"
    }
    return names
  }()
}
