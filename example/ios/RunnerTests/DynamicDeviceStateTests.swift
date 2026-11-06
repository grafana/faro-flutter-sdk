import CoreTelephony
import Foundation
import Network
import Testing
import UIKit

@testable import faro

// The plugin reads this state on the main thread, so the tests do too.
@MainActor
@Suite("DynamicDeviceState")
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

  @Test("every listener-fed snapshot carries a version")
  func listenedStateIsNumbered() {
    #expect(DynamicDeviceState.listenedState()[DynamicDeviceState.versionKey] is Int)
  }

  @Test("the state has power-saving and thermal values")
  func listenedStateHasSystemValues() {
    let listened = DynamicDeviceState.listenedState()

    #expect(listened[DynamicDeviceState.lowPowerModeKey] is Bool)
    #expect(listened[DynamicDeviceState.thermalStateKey] is String)
  }
}
