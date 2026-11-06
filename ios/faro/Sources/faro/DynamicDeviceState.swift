import CoreTelephony
import Foundation
import Network
import UIKit

/// Device and network values that change while the app runs.
///
/// Every value a system notification can update is listener-fed: battery, Low
/// Power Mode, thermal state, connection type and the cellular technology. The
/// notifications keep a cache and tell observers when it changes. They start
/// on the first read, not when the plugin loads, and only for the groups the
/// app asks for: a group that is off registers no notification and reads no
/// value. Nothing here needs a
/// permission, and every value is omitted when it cannot be read. iOS never
/// reports a carrier.
enum DynamicDeviceState {
  /// The three groups the app can turn off. The raw values are the names the
  /// Dart side sends.
  enum Group: String, CaseIterable {
    case battery
    case thermal
    case network
  }

  static let batteryLevelKey = "batteryLevel"
  static let isChargingKey = "isCharging"
  static let lowPowerModeKey = "lowPowerMode"
  static let thermalStateKey = "thermalState"
  static let connectionTypeKey = "connectionType"
  static let connectionSubtypeKey = "connectionSubtype"

  private static let lock = NSLock()
  private static var startedGroups: Set<Group> = []
  private static var monitor: NWPathMonitor?
  private static var latestPath: NWPath?
  private static var listenedCache: [String: Any] = [:]
  private static var observers: [ObjectIdentifier: () -> Void] = [:]
  private static let telephonyInfo = CTTelephonyNetworkInfo()
  private static let dataServiceObserver = DataServiceObserver()

  /// The system sends no notification when the SIM that carries mobile data
  /// changes, but it calls this delegate. Without it the cached subtype would
  /// stay on the previous SIM.
  private final class DataServiceObserver: NSObject, CTTelephonyNetworkInfoDelegate {
    func dataServiceIdentifierDidChange(_ identifier: String) {
      DispatchQueue.main.async {
        DynamicDeviceState.refreshListened()
      }
    }
  }

  /// Whether a change of the data SIM refreshes the cache.
  static var isObservingDataService: Bool {
    telephonyInfo.delegate != nil
  }

  /// Reads the groups the Dart side sends. Unknown names are ignored.
  static func groups(from argument: Any?) -> Set<Group> {
    guard let arguments = argument as? [String: Any],
      let names = arguments["groups"] as? [String]
    else {
      return []
    }
    return Set(names.compactMap { Group(rawValue: $0) })
  }

  /// The system notifications that keep a group current.
  static func notificationNames(for group: Group) -> [Notification.Name] {
    switch group {
    case .battery:
      return [
        UIDevice.batteryLevelDidChangeNotification,
        UIDevice.batteryStateDidChangeNotification,
        .NSProcessInfoPowerStateDidChange,
      ]
    case .thermal:
      return [ProcessInfo.thermalStateDidChangeNotification]
    case .network:
      // Newer SDKs import this constant as a Notification.Name and older ones as
      // a String, so the literal compiles on both.
      return [Notification.Name("CTServiceRadioAccessTechnologyDidChangeNotification")]
    }
  }

  /// Starts the system listeners of the given groups that are not running yet.
  /// Safe to call more than once. The plugin calls it on the main thread, where
  /// it seeds the cache before it returns. A call from another thread hops to
  /// the main thread, and a second caller that races it can read an empty
  /// cache.
  static func start(groups: Set<Group>) {
    lock.lock()
    let toStart = groups.subtracting(startedGroups)
    startedGroups.formUnion(toStart)
    lock.unlock()
    if toStart.isEmpty {
      return
    }

    if Thread.isMainThread {
      startListeners(toStart)
    } else {
      DispatchQueue.main.sync { startListeners(toStart) }
    }
  }

  private static func startListeners(_ groups: Set<Group>) {
    if groups.contains(.battery) {
      UIDevice.current.isBatteryMonitoringEnabled = true
    }
    let center = NotificationCenter.default
    for name in groups.flatMap({ notificationNames(for: $0) }) {
      center.addObserver(forName: name, object: nil, queue: .main) { _ in
        refreshListened()
      }
    }

    if groups.contains(.network) {
      telephonyInfo.delegate = dataServiceObserver

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
    }
    refreshListened()
  }

  /// Calls `observer` each time the listener-fed values change. Read
  /// `listenedState()` for the values. The listeners start on the first read,
  /// so an app that never reads pays nothing.
  static func addObserver(_ owner: AnyObject, _ observer: @escaping () -> Void) {
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
  static func listenedState(groups: Set<Group> = Set(Group.allCases)) -> [String: Any] {
    start(groups: groups)
    lock.lock()
    defer { lock.unlock() }
    return listenedCache
  }

  /// Reads the system into the cache and tells observers when it changed.
  /// Runs on the main thread, where UIKit values are safe to read.
  private static func refreshListened() {
    var state: [String: Any] = [:]

    lock.lock()
    let groups = startedGroups
    let path = latestPath
    lock.unlock()

    if groups.contains(.battery) {
      let device = UIDevice.current
      if let level = batteryPercent(device.batteryLevel) {
        state[batteryLevelKey] = level
      }
      if let charging = isCharging(device.batteryState) {
        state[isChargingKey] = charging
      }
      state[lowPowerModeKey] = ProcessInfo.processInfo.isLowPowerModeEnabled
    }
    if groups.contains(.thermal) {
      state[thermalStateKey] = thermalStateName(ProcessInfo.processInfo.thermalState)
    }
    if groups.contains(.network), let path {
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
    let callbacks = Array(observers.values)
    lock.unlock()
    if changed {
      callbacks.forEach { $0() }
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
      CTRadioAccessTechnologyCDMA1x: "cdma2000_1xrtt",
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
