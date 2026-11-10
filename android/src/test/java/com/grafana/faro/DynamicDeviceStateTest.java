package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import android.os.BatteryManager;
import android.telephony.TelephonyManager;

import org.junit.Test;

import java.util.Arrays;
import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

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
        assertTrue(
                DynamicDeviceState.startListening(
                                null, new Object(), Arrays.asList("battery", "thermal"))
                        .isEmpty());
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

    @Test
    public void everyKnownGroupIsKept() {
        assertEquals(
                new HashSet<>(Arrays.asList("battery", "thermal", "network")),
                DynamicDeviceState.knownGroups(Arrays.asList("battery", "thermal", "network")));
    }

    @Test
    public void anUnknownGroupIsIgnored() {
        assertTrue(DynamicDeviceState.knownGroups(Collections.singletonList("location")).isEmpty());
    }

    @Test
    public void aGroupThatIsOffContributesNoKeys() {
        Set<String> keys = DynamicDeviceState.keysOf(Arrays.asList("battery", "network"));

        assertTrue(keys.contains("batteryLevel"));
        assertTrue(keys.contains("isCharging"));
        assertTrue(keys.contains("lowPowerMode"));
        assertTrue(keys.contains("connectionType"));
        assertFalse(keys.contains("thermalState"));
    }

    @Test
    public void noGroupContributesNoKeys() {
        assertTrue(DynamicDeviceState.keysOf(Collections.<String>emptyList()).isEmpty());
    }

    @Test
    public void aFirstOwnerStartsItsGroups() {
        GroupOwners owners = new GroupOwners();

        GroupOwners.Change change = owners.set("engineA", Arrays.asList("battery", "thermal"));

        assertEquals(new HashSet<>(Arrays.asList("battery", "thermal")), change.started);
        assertTrue(change.stopped.isEmpty());
    }

    @Test
    public void aSecondOwnerOfARunningGroupStartsNothing() {
        GroupOwners owners = new GroupOwners();
        owners.set("engineA", Arrays.asList("battery", "thermal"));

        GroupOwners.Change change = owners.set("engineB", Collections.singletonList("thermal"));

        assertTrue(change.isEmpty());
    }

    @Test
    public void aGroupKeepsRunningUntilItsLastOwnerLeaves() {
        GroupOwners owners = new GroupOwners();
        owners.set("engineA", Arrays.asList("battery", "thermal"));
        owners.set("engineB", Collections.singletonList("thermal"));

        GroupOwners.Change first = owners.release("engineA");
        GroupOwners.Change last = owners.release("engineB");

        assertEquals(Collections.singleton("battery"), first.stopped);
        assertEquals(Collections.singleton("thermal"), last.stopped);
        assertTrue(owners.running().isEmpty());
    }

    @Test
    public void anOwnerThatNarrowsItsGroupsStopsTheOnesItDropped() {
        GroupOwners owners = new GroupOwners();
        owners.set("engineA", Arrays.asList("battery", "thermal", "network"));

        GroupOwners.Change change = owners.set("engineA", Collections.singletonList("thermal"));

        assertEquals(new HashSet<>(Arrays.asList("battery", "network")), change.stopped);
        assertTrue(change.started.isEmpty());
    }

    @Test
    public void aReplacementEngineThatTurnsGroupsOffStopsThem() {
        GroupOwners owners = new GroupOwners();
        owners.set("oldEngine", Arrays.asList("battery", "thermal", "network"));
        owners.release("oldEngine");

        GroupOwners.Change change = owners.set("newEngine", Collections.singletonList("thermal"));

        assertEquals(Collections.singleton("thermal"), change.started);
        assertEquals(Collections.singleton("thermal"), owners.running());
    }

    @Test
    public void releasingAnUnknownOwnerChangesNothing() {
        assertTrue(new GroupOwners().release("nobody").isEmpty());
    }
}
