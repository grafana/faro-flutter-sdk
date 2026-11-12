package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.os.BatteryManager;
import android.telephony.TelephonyManager;

import org.junit.Test;

public class DynamicDeviceStateTest {
    @Test
    public void batteryPercentIsAWholePercent() {
        assertEquals(Integer.valueOf(0), DynamicDeviceState.batteryPercent(0, 100));
        assertEquals(Integer.valueOf(100), DynamicDeviceState.batteryPercent(100, 100));
        assertEquals(Integer.valueOf(50), DynamicDeviceState.batteryPercent(127, 254));
    }

    @Test
    public void batteryPercentIsNullWhenTheSystemReportsNoLevel() {
        assertNull(DynamicDeviceState.batteryPercent(-1, 100));
        assertNull(DynamicDeviceState.batteryPercent(50, -1));
        assertNull(DynamicDeviceState.batteryPercent(50, 0));
    }

    @Test
    public void batteryPercentNeverExceedsOneHundred() {
        assertEquals(Integer.valueOf(100), DynamicDeviceState.batteryPercent(120, 100));
    }

    @Test
    public void isPluggedInIsTrueForEveryPowerSource() {
        assertTrue(DynamicDeviceState.isPluggedIn(BatteryManager.BATTERY_PLUGGED_AC));
        assertTrue(DynamicDeviceState.isPluggedIn(BatteryManager.BATTERY_PLUGGED_USB));
        assertTrue(DynamicDeviceState.isPluggedIn(BatteryManager.BATTERY_PLUGGED_WIRELESS));
    }

    @Test
    public void isPluggedInIsFalseOnBattery() {
        assertFalse(DynamicDeviceState.isPluggedIn(0));
    }

    @Test
    public void thermalStatusMapsToFourStates() {
        assertEquals("nominal", DynamicDeviceState.thermalStateName(0));
        assertEquals("fair", DynamicDeviceState.thermalStateName(1));
        assertEquals("serious", DynamicDeviceState.thermalStateName(2));
        assertEquals("critical", DynamicDeviceState.thermalStateName(3));
        assertEquals("critical", DynamicDeviceState.thermalStateName(4));
        assertEquals("critical", DynamicDeviceState.thermalStateName(5));
        assertEquals("critical", DynamicDeviceState.thermalStateName(6));
    }

    @Test
    public void unknownThermalStatusIsNull() {
        assertNull(DynamicDeviceState.thermalStateName(-1));
    }

    @Test
    public void connectionTypePrefersWifiThenCellThenWired() {
        assertEquals("wifi", DynamicDeviceState.connectionTypeName(true, true, true));
        assertEquals("cell", DynamicDeviceState.connectionTypeName(false, true, true));
        assertEquals("wired", DynamicDeviceState.connectionTypeName(false, false, true));
        assertEquals("unknown", DynamicDeviceState.connectionTypeName(false, false, false));
    }

    @Test
    public void subtypeMapsToOpenTelemetryNames() {
        assertEquals("lte", DynamicDeviceState.connectionSubtypeName(TelephonyManager.NETWORK_TYPE_LTE));
        assertEquals("nr", DynamicDeviceState.connectionSubtypeName(20));
        assertEquals("lte_ca", DynamicDeviceState.connectionSubtypeName(19));
        assertEquals("hspap", DynamicDeviceState.connectionSubtypeName(TelephonyManager.NETWORK_TYPE_HSPAP));
        assertEquals(
                "cdma2000_1xrtt",
                DynamicDeviceState.connectionSubtypeName(TelephonyManager.NETWORK_TYPE_1xRTT));
    }

    @Test
    public void unknownSubtypeIsNull() {
        assertNull(DynamicDeviceState.connectionSubtypeName(TelephonyManager.NETWORK_TYPE_UNKNOWN));
    }

    @Test
    public void onlyTheBatteryBroadcastCarriesBatteryExtras() {
        assertTrue(DynamicDeviceState.carriesBatteryExtras("android.intent.action.BATTERY_CHANGED"));
        assertFalse(
                DynamicDeviceState.carriesBatteryExtras(
                        "android.os.action.POWER_SAVE_MODE_CHANGED"));
        assertFalse(DynamicDeviceState.carriesBatteryExtras(null));
    }

    @Test
    public void listenedAndProbedStatesAreEmptyWithoutAContext() {
        assertTrue(DynamicDeviceState.listenedState(null).isEmpty());
        assertTrue(DynamicDeviceState.probedState(null).isEmpty());
    }

    @Test
    public void keysMatchTheDartSide() {
        assertEquals("batteryLevel", DynamicDeviceState.BATTERY_LEVEL_KEY);
        assertEquals("isCharging", DynamicDeviceState.IS_CHARGING_KEY);
        assertEquals("lowPowerMode", DynamicDeviceState.LOW_POWER_MODE_KEY);
        assertEquals("thermalState", DynamicDeviceState.THERMAL_STATE_KEY);
        assertEquals("connectionType", DynamicDeviceState.CONNECTION_TYPE_KEY);
        assertEquals("connectionSubtype", DynamicDeviceState.CONNECTION_SUBTYPE_KEY);
        assertEquals("carrierName", DynamicDeviceState.CARRIER_NAME_KEY);
    }
}
