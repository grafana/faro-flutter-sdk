import CoreTelephony
import Foundation
import Network
import Testing
import UIKit

@testable import faro

// The plugin reads this state on the main thread, so the tests do too.
@MainActor
@Suite("DynamicDeviceState", .serialized)
struct DynamicDeviceStateTests {

  @Test("battery level is a whole percent")
  func batteryPercentRounds() {
    #expect(DynamicDeviceState.batteryPercent(0) == 0)
    #expect(DynamicDeviceState.batteryPercent(0.5) == 50)
    #expect(DynamicDeviceState.batteryPercent(1) == 100)
    #expect(DynamicDeviceState.batteryPercent(0.876) == 88)
  }

  @Test("battery level is nil when the system reports none")
  func batteryPercentUnknown() {
    #expect(DynamicDeviceState.batteryPercent(-1) == nil)
  }

  @Test("connected to power means charging or full")
  func chargingIncludesFull() {
    #expect(DynamicDeviceState.isCharging(.charging) == true)
    #expect(DynamicDeviceState.isCharging(.full) == true)
    #expect(DynamicDeviceState.isCharging(.unplugged) == false)
    #expect(DynamicDeviceState.isCharging(.unknown) == nil)
  }

  @Test("thermal state keeps the system names")
  func thermalStates() {
    #expect(DynamicDeviceState.thermalStateName(.nominal) == "nominal")
    #expect(DynamicDeviceState.thermalStateName(.fair) == "fair")
    #expect(DynamicDeviceState.thermalStateName(.serious) == "serious")
    #expect(DynamicDeviceState.thermalStateName(.critical) == "critical")
  }

  @Test("connection type checks wifi, then cell, then wired")
  func connectionTypes() {
    func type(_ wifi: Bool, _ cell: Bool, _ wired: Bool) -> String {
      DynamicDeviceState.connectionType(
        status: .satisfied, usesWifi: wifi, usesCellular: cell, usesWired: wired)
    }

    #expect(type(true, true, true) == "wifi")
    #expect(type(false, true, true) == "cell")
    #expect(type(false, false, true) == "wired")
    #expect(type(false, false, false) == "unknown")
  }

  @Test("a VPN does not hide the connection under it")
  func vpnKeepsTheUnderlyingType() {
    // A VPN adds an `other` interface. The wifi under it still counts.
    #expect(
      DynamicDeviceState.connectionType(
        status: .satisfied, usesWifi: true, usesCellular: false, usesWired: false) == "wifi")
  }

  @Test("no route means unavailable")
  func connectionTypeUnavailable() {
    #expect(
      DynamicDeviceState.connectionType(
        status: .unsatisfied, usesWifi: true, usesCellular: false, usesWired: false) == "unavailable")
    #expect(
      DynamicDeviceState.connectionType(
        status: .requiresConnection, usesWifi: false, usesCellular: false, usesWired: false) == "unavailable")
  }

  @Test("radio technology maps to OpenTelemetry subtype names")
  func subtypes() {
    #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyLTE) == "lte")
    #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyWCDMA) == "umts")
    #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyeHRPD) == "ehrpd")
    #expect(
      DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyCDMA1x)
        == "cdma2000_1xrtt")
    if #available(iOS 14.1, *) {
      #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyNR) == "nr")
      #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: CTRadioAccessTechnologyNRNSA) == "nrnsa")
    }
  }

  @Test("an unknown radio technology has no subtype")
  func unknownSubtype() {
    #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: "Unknown") == nil)
    #expect(DynamicDeviceState.connectionSubtypeName(radioTechnology: nil) == nil)
  }

  @Test("the subtype comes from the data SIM on a dual-SIM phone")
  func dataSimDecidesTheSubtype() {
    let technologies = ["sim1": CTRadioAccessTechnologyLTE, "sim2": CTRadioAccessTechnologyWCDMA]

    #expect(
      DynamicDeviceState.dataRadioTechnology(technologies: technologies, dataServiceIdentifier: "sim2")
        == CTRadioAccessTechnologyWCDMA)
    #expect(
      DynamicDeviceState.dataRadioTechnology(technologies: technologies, dataServiceIdentifier: "sim1")
        == CTRadioAccessTechnologyLTE)
  }

  @Test("two SIMs without a known data SIM give no subtype")
  func ambiguousSimsGiveNoSubtype() {
    let technologies = ["sim1": CTRadioAccessTechnologyLTE, "sim2": CTRadioAccessTechnologyWCDMA]

    #expect(DynamicDeviceState.dataRadioTechnology(technologies: technologies, dataServiceIdentifier: nil) == nil)
    #expect(DynamicDeviceState.dataRadioTechnology(technologies: technologies, dataServiceIdentifier: "sim3") == nil)
  }

  @Test("one SIM is the data SIM even without an identifier")
  func singleSim() {
    #expect(
      DynamicDeviceState.dataRadioTechnology(
        technologies: ["sim1": CTRadioAccessTechnologyLTE], dataServiceIdentifier: nil)
        == CTRadioAccessTechnologyLTE)
    #expect(DynamicDeviceState.dataRadioTechnology(technologies: nil, dataServiceIdentifier: nil) == nil)
  }

  @Test("the state has power-saving and thermal values")
  func listenedStateHasSystemValues() {
    let owner = NSObject()
    let listened = DynamicDeviceState.startListening(owner: owner, groups: [.battery, .thermal])
    defer { DynamicDeviceState.stopListening(owner: owner) }

    #expect(listened[DynamicDeviceState.lowPowerModeKey] is Bool)
    #expect(listened[DynamicDeviceState.thermalStateKey] is String)
  }

  @Test("a change of the data SIM refreshes the cache")
  func dataSimChangeIsObserved() {
    let owner = NSObject()
    _ = DynamicDeviceState.startListening(owner: owner, groups: [.network])
    defer { DynamicDeviceState.stopListening(owner: owner) }

    #expect(DynamicDeviceState.isObservingDataService)
  }

  @Test("the last owner of a group stops it and clears its values")
  func lastOwnerStopsTheGroup() {
    let first = NSObject()
    let second = NSObject()
    _ = DynamicDeviceState.startListening(owner: first, groups: [.thermal, .network])
    _ = DynamicDeviceState.startListening(owner: second, groups: [.network])

    DynamicDeviceState.stopListening(owner: first)
    #expect(DynamicDeviceState.isObservingDataService)
    #expect(DynamicDeviceState.listenedState(groups: [.thermal]).isEmpty)

    DynamicDeviceState.stopListening(owner: second)
    #expect(!DynamicDeviceState.isObservingDataService)
    #expect(DynamicDeviceState.listenedState(groups: [.network, .thermal, .battery]).isEmpty)
  }

  @Test("a replacement engine with a group off leaves that group stopped")
  func replacementEngineLeavesOffGroupStopped() {
    let oldEngine = NSObject()
    let newEngine = NSObject()
    _ = DynamicDeviceState.startListening(owner: oldEngine, groups: [.battery, .thermal, .network])
    DynamicDeviceState.stopListening(owner: oldEngine)

    let listened = DynamicDeviceState.startListening(owner: newEngine, groups: [.thermal])
    defer { DynamicDeviceState.stopListening(owner: newEngine) }

    #expect(listened[DynamicDeviceState.thermalStateKey] is String)
    #expect(listened[DynamicDeviceState.lowPowerModeKey] == nil)
    #expect(!DynamicDeviceState.isObservingDataService)
  }

  @Test("an engine gets only the values of its own groups")
  func engineGetsOnlyItsGroups() {
    let all = NSObject()
    let thermalOnly = NSObject()
    _ = DynamicDeviceState.startListening(owner: all, groups: [.battery, .thermal])
    defer { DynamicDeviceState.stopListening(owner: all) }

    let listened = DynamicDeviceState.startListening(owner: thermalOnly, groups: [.thermal])
    defer { DynamicDeviceState.stopListening(owner: thermalOnly) }

    #expect(listened[DynamicDeviceState.thermalStateKey] is String)
    #expect(listened[DynamicDeviceState.lowPowerModeKey] == nil)
  }

  @Test("a first owner starts its groups")
  func firstOwnerStartsGroups() {
    var owners = GroupOwners()
    let engine = NSObject()

    let change = owners.set(ObjectIdentifier(engine), groups: [.battery, .thermal])

    #expect(change == GroupOwners.Change(started: [.battery, .thermal], stopped: []))
  }

  @Test("a second owner of a running group starts nothing")
  func secondOwnerStartsNothing() {
    var owners = GroupOwners()
    let engineA = NSObject()
    let engineB = NSObject()
    _ = owners.set(ObjectIdentifier(engineA), groups: [.battery, .thermal])

    let change = owners.set(ObjectIdentifier(engineB), groups: [.thermal])

    #expect(change.isEmpty)
  }

  @Test("a group runs until its last owner leaves")
  func groupRunsUntilLastOwnerLeaves() {
    var owners = GroupOwners()
    let engineA = NSObject()
    let engineB = NSObject()
    _ = owners.set(ObjectIdentifier(engineA), groups: [.battery, .thermal])
    _ = owners.set(ObjectIdentifier(engineB), groups: [.thermal])

    let first = owners.release(ObjectIdentifier(engineA))
    let last = owners.release(ObjectIdentifier(engineB))

    #expect(first.stopped == [.battery])
    #expect(last.stopped == [.thermal])
    #expect(owners.running.isEmpty)
  }

  @Test("an owner that narrows its groups stops the ones it dropped")
  func narrowingStopsDroppedGroups() {
    var owners = GroupOwners()
    let engine = NSObject()
    _ = owners.set(ObjectIdentifier(engine), groups: [.battery, .thermal, .network])

    let change = owners.set(ObjectIdentifier(engine), groups: [.thermal])

    #expect(change.stopped == [.battery, .network])
    #expect(change.started.isEmpty)
  }

  @Test("releasing an unknown owner changes nothing")
  func releasingUnknownOwnerChangesNothing() {
    var owners = GroupOwners()
    let nobody = NSObject()

    #expect(owners.release(ObjectIdentifier(nobody)).isEmpty)
  }

  @Test("the groups come from the names the Dart side sends")
  func groupsAreParsed() {
    let groups = DynamicDeviceState.groups(from: ["groups": ["battery", "network"]])

    #expect(groups == [.battery, .network])
  }

  @Test("an unknown group name is ignored")
  func unknownGroupIsIgnored() {
    #expect(DynamicDeviceState.groups(from: ["groups": ["location", "thermal"]]) == [.thermal])
  }

  @Test("no arguments mean no group")
  func missingArgumentsMeanNoGroup() {
    #expect(DynamicDeviceState.groups(from: nil).isEmpty)
    #expect(DynamicDeviceState.groups(from: ["groups": []]).isEmpty)
  }

  @Test("each group listens to its own notifications only")
  func notificationsBelongToOneGroup() {
    let battery = Set(DynamicDeviceState.notificationNames(for: .battery))
    let thermal = Set(DynamicDeviceState.notificationNames(for: .thermal))
    let network = Set(DynamicDeviceState.notificationNames(for: .network))

    #expect(battery.contains(UIDevice.batteryLevelDidChangeNotification))
    #expect(battery.contains(.NSProcessInfoPowerStateDidChange))
    #expect(thermal == [ProcessInfo.thermalStateDidChangeNotification])
    #expect(battery.isDisjoint(with: thermal))
    #expect(battery.isDisjoint(with: network))
    #expect(thermal.isDisjoint(with: network))
  }
}
