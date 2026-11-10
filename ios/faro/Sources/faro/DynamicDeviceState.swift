import CoreTelephony
import Foundation
import Network
import UIKit

/// Device and network values that change while the app runs.
///
/// Every value a system notification can update is listener-fed: battery, Low
/// Power Mode, thermal state, connection type and the cellular technology. The
/// notifications keep a cache and tell observers when it changes. They start
/// when a Flutter engine first asks, not when the plugin loads, and only for
/// the groups the app asks for: a group that is off registers no notification
/// and reads no value. Each engine is an owner. A group stops, and its cached
/// values clear, when the last engine that asked for it leaves. Nothing here
/// needs a permission, and every value is omitted when it cannot be read. iOS
/// never reports a carrier.
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
  private static var owners = GroupOwners()
  private static var notificationTokens: [Group: [NSObjectProtocol]] = [:]
  private static var batteryMonitoringWasEnabled = false
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

  /// The cache keys that belong to a group.
  static func keys(for group: Group) -> Set<String> {
    switch group {
    case .battery:
      return [batteryLevelKey, isChargingKey, lowPowerModeKey]
    case .thermal:
      return [thermalStateKey]
    case .network:
      return [connectionTypeKey, connectionSubtypeKey]
    }
  }

  /// Makes `owner` an owner of `groups`, starts the listeners of any group that
  /// was not running, and stops those that no owner wants any more. Returns the
  /// cached values of `groups`. The work runs on the main thread, where it
  /// seeds the cache before it returns.
  static func startListening(owner: AnyObject, groups: Set<Group>) -> [String: Any] {
    apply { $0.set(ObjectIdentifier(owner), groups: groups) }
    return listenedState(groups: groups)
  }

  /// Removes `owner`. A group no other owner wants stops.
  static func stopListening(owner: AnyObject) {
    apply { $0.release(ObjectIdentifier(owner)) }
  }

  private static func apply(_ change: (inout GroupOwners) -> GroupOwners.Change) {
    if Thread.isMainThread {
      applyOnMain(change)
    } else {
      DispatchQueue.main.sync { applyOnMain(change) }
    }
  }

  private static func applyOnMain(_ change: (inout GroupOwners) -> GroupOwners.Change) {
    lock.lock()
    let changed = change(&owners)
    lock.unlock()
    if changed.isEmpty {
      return
    }
    stopListeners(changed.stopped)
    startListeners(changed.started)
    refreshListened()
  }

  private static func startListeners(_ groups: Set<Group>) {
    if groups.contains(.battery) {
      batteryMonitoringWasEnabled = UIDevice.current.isBatteryMonitoringEnabled
      UIDevice.current.isBatteryMonitoringEnabled = true
    }
    let center = NotificationCenter.default
    for group in groups {
      notificationTokens[group] = notificationNames(for: group).map { name in
        center.addObserver(forName: name, object: nil, queue: .main) { _ in
          refreshListened()
        }
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
  }

  private static func stopListeners(_ groups: Set<Group>) {
    let center = NotificationCenter.default
    for group in groups {
      notificationTokens[group]?.forEach { center.removeObserver($0) }
      notificationTokens[group] = nil
    }
    if groups.contains(.battery) {
      UIDevice.current.isBatteryMonitoringEnabled = batteryMonitoringWasEnabled
    }
    if groups.contains(.network) {
      telephonyInfo.delegate = nil
      lock.lock()
      monitor?.cancel()
      monitor = nil
      latestPath = nil
      lock.unlock()
    }
  }

  /// Calls `observer` each time the listener-fed values change. Read
  /// `listenedState(groups:)` for the values.
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

  /// The cached values that system notifications keep current, for `groups`
  /// only.
  static func listenedState(groups: Set<Group>) -> [String: Any] {
    let keys = groups.reduce(into: Set<String>()) { $0.formUnion(keys(for: $1)) }
    lock.lock()
    defer { lock.unlock() }
    return listenedCache.filter { keys.contains($0.key) }
  }

  /// Reads the system into the cache and tells observers when it changed.
  /// Runs on the main thread, where UIKit values are safe to read.
  private static func refreshListened() {
    var state: [String: Any] = [:]

    lock.lock()
    let groups = owners.running
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
