package com.grafana.faro;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.ConnectivityManager;
import android.net.Network;
import android.net.NetworkCapabilities;
import android.net.NetworkInfo;
import android.os.BatteryManager;
import android.os.Build;
import android.os.PowerManager;
import android.telephony.TelephonyManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CopyOnWriteArraySet;

import io.flutter.Log;

/**
 * Device and network values that change while the app runs.
 *
 * <p>The values form three groups: battery, thermal and network. A group starts only when the
 * app asks for it, so a group that is off registers no listener and reads nothing.
 *
 * <p>Every value a system listener can update is listener-fed: battery, charging, battery
 * saver, thermal state and connection type. Listeners keep cached values and tell
 * {@link Listener}s when the set changes. They start on the first read, not when the plugin
 * loads. Only values with no permission-free listener are read on demand: the cellular subtype
 * and the carrier name. Nothing here needs a runtime permission, and every value is omitted when
 * it cannot be read.
 */
final class DynamicDeviceState {
    private static final String TAG = "FaroDynamicDeviceState";

    static final String BATTERY_LEVEL_KEY = "batteryLevel";
    static final String IS_CHARGING_KEY = "isCharging";
    static final String LOW_POWER_MODE_KEY = "lowPowerMode";
    static final String THERMAL_STATE_KEY = "thermalState";
    static final String CONNECTION_TYPE_KEY = "connectionType";
    static final String CONNECTION_SUBTYPE_KEY = "connectionSubtype";
    static final String CARRIER_NAME_KEY = "carrierName";
    static final String VERSION_KEY = "version";

    static final String BATTERY_GROUP = "battery";
    static final String THERMAL_GROUP = "thermal";
    static final String NETWORK_GROUP = "network";

    /** Receives the listener-fed values each time one of them changes. */
    interface Listener {
        void onChanged(@NonNull Map<String, Object> listenedState);
    }

    private static final Object LOCK = new Object();
    private static final Set<Listener> listeners = new CopyOnWriteArraySet<>();
    private static final Set<String> startedGroups = new HashSet<>();
    private static Map<String, Object> lastNotified = new HashMap<>();
    // Numbers each listener-fed snapshot, so Dart can tell which of two is newer.
    private static int listenedVersion = 0;
    private static volatile Integer batteryLevel;
    private static volatile Boolean isCharging;
    private static volatile Boolean lowPowerMode;
    private static volatile String thermalState;
    private static volatile String connectionType;

    // Read and written only on the connectivity callback thread, so the loss of the default
    // network is not confused with the loss of a network it replaced.
    private static Network defaultNetwork;

    private DynamicDeviceState() {}

    /**
     * Sends every change to {@code listener}. The system listeners start on the first read, so
     * an app that never reads the state pays nothing.
     */
    static void addListener(@NonNull Listener listener) {
        listeners.add(listener);
    }

    static void removeListener(@NonNull Listener listener) {
        listeners.remove(listener);
    }

    /** The cached values that system listeners keep current. */
    @NonNull
    static Map<String, Object> listenedState(
            @Nullable Context context, @NonNull Collection<String> groups) {
        if (context == null) {
            return new HashMap<>();
        }
        start(context.getApplicationContext(), groups);
        synchronized (LOCK) {
            Map<String, Object> state = snapshot();
            state.put(VERSION_KEY, listenedVersion);
            return state;
        }
    }

    /** The values with no listener, read now: cellular subtype and carrier name. */
    @NonNull
    static Map<String, Object> probedState(@Nullable Context context) {
        Map<String, Object> state = new HashMap<>();
        if (context == null) {
            return state;
        }
        if (!isStarted(NETWORK_GROUP)) {
            return state;
        }
        try {
            if ("cell".equals(connectionType)) {
                putIfPresent(state, CONNECTION_SUBTYPE_KEY, readConnectionSubtype(context));
            }
            putIfPresent(state, CARRIER_NAME_KEY, readCarrierName(context));
        } catch (RuntimeException e) {
            Log.w(TAG, "Network details unavailable: " + e.getMessage());
        }
        return state;
    }

    @NonNull
    private static Map<String, Object> snapshot() {
        Map<String, Object> state = new HashMap<>();
        putIfPresent(state, BATTERY_LEVEL_KEY, batteryLevel);
        putIfPresent(state, IS_CHARGING_KEY, isCharging);
        putIfPresent(state, LOW_POWER_MODE_KEY, lowPowerMode);
        putIfPresent(state, THERMAL_STATE_KEY, thermalState);
        putIfPresent(state, CONNECTION_TYPE_KEY, connectionType);
        return state;
    }

    private static void putIfPresent(Map<String, Object> map, String key, @Nullable Object value) {
        if (value != null) {
            map.put(key, value);
        }
    }

    /** Sends the listener-fed values to the listeners when they differ from the last send. */
    private static void notifyIfChanged() {
        Map<String, Object> pushed;
        synchronized (LOCK) {
            // Read under the lock, so a snapshot never takes a newer version than a fresher one.
            Map<String, Object> state = snapshot();
            if (state.equals(lastNotified)) {
                return;
            }
            lastNotified = state;
            listenedVersion++;
            pushed = new HashMap<>(state);
            pushed.put(VERSION_KEY, listenedVersion);
        }
        for (Listener listener : listeners) {
            listener.onChanged(pushed);
        }
    }

    /**
     * Registers the listeners of the requested groups that are not running yet and seeds the
     * cache from the current state.
     */
    private static void start(@NonNull Context context, @NonNull Collection<String> groups) {
        Set<String> toStart;
        synchronized (LOCK) {
            toStart = groupsToStart(groups, startedGroups);
            startedGroups.addAll(toStart);
        }
        if (toStart.isEmpty()) {
            return;
        }
        if (toStart.contains(BATTERY_GROUP)) {
            startBatteryAndPowerListener(context);
        }
        if (toStart.contains(THERMAL_GROUP)) {
            startThermalListener(context);
        }
        if (toStart.contains(NETWORK_GROUP)) {
            startNetworkListener(context);
        }
        synchronized (LOCK) {
            lastNotified = snapshot();
        }
    }

    private static boolean isStarted(@NonNull String group) {
        synchronized (LOCK) {
            return startedGroups.contains(group);
        }
    }

    /** The known groups in {@code requested} that are not in {@code running}. */
    @VisibleForTesting
    @NonNull
    static Set<String> groupsToStart(
            @NonNull Collection<String> requested, @NonNull Set<String> running) {
        Set<String> toStart = new HashSet<>();
        for (String group : requested) {
            if ((BATTERY_GROUP.equals(group)
                            || THERMAL_GROUP.equals(group)
                            || NETWORK_GROUP.equals(group))
                    && !running.contains(group)) {
                toStart.add(group);
            }
        }
        return toStart;
    }

    private static void startBatteryAndPowerListener(@NonNull Context context) {
        try {
            IntentFilter filter = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                filter.addAction(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED);
            }
            BroadcastReceiver receiver =
                    new BroadcastReceiver() {
                        @Override
                        public void onReceive(Context receiverContext, Intent intent) {
                            // Only the battery broadcast has battery extras. Reading them from
                            // the battery saver broadcast would clear the level and the
                            // charging state.
                            if (carriesBatteryExtras(intent == null ? null : intent.getAction())) {
                                readBattery(intent);
                            }
                            readLowPowerMode(receiverContext);
                            notifyIfChanged();
                        }
                    };
            // Battery changes are sticky, so registering also returns the current value.
            readBattery(context.registerReceiver(receiver, filter));
            readLowPowerMode(context);
        } catch (RuntimeException e) {
            Log.w(TAG, "Battery state unavailable: " + e.getMessage());
        }
    }

    private static void readBattery(@Nullable Intent intent) {
        if (intent == null) {
            return;
        }
        batteryLevel =
                batteryPercent(
                        intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1),
                        intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1));
        isCharging = isPluggedIn(intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0));
    }

    private static void readLowPowerMode(@Nullable Context context) {
        if (context == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            return;
        }
        try {
            PowerManager powerManager =
                    (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (powerManager != null) {
                lowPowerMode = powerManager.isPowerSaveMode();
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "Battery saver state unavailable: " + e.getMessage());
        }
    }

    private static void startThermalListener(@NonNull Context context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return;
        }
        try {
            PowerManager powerManager =
                    (PowerManager) context.getSystemService(Context.POWER_SERVICE);
            if (powerManager == null) {
                return;
            }
            thermalState = thermalStateName(powerManager.getCurrentThermalStatus());
            powerManager.addThermalStatusListener(
                    context.getMainExecutor(),
                    status -> {
                        thermalState = thermalStateName(status);
                        notifyIfChanged();
                    });
        } catch (RuntimeException e) {
            Log.w(TAG, "Thermal state unavailable: " + e.getMessage());
        }
    }

    /**
     * From API 24 a default-network callback reports every change of transport and of the
     * system's internet check. Before that, the connectivity broadcast is the listener.
     */
    @SuppressWarnings("deprecation")
    private static void startNetworkListener(@NonNull Context context) {
        try {
            ConnectivityManager connectivityManager =
                    (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
            if (connectivityManager == null) {
                return;
            }
            readNetwork(connectivityManager);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                connectivityManager.registerDefaultNetworkCallback(
                        new ConnectivityManager.NetworkCallback() {
                            @Override
                            public void onCapabilitiesChanged(
                                    @NonNull Network network,
                                    @NonNull NetworkCapabilities capabilities) {
                                defaultNetwork = network;
                                applyCapabilities(capabilities);
                                notifyIfChanged();
                            }

                            @Override
                            public void onLost(@NonNull Network network) {
                                // A switch from wifi to cell can report the loss of wifi after
                                // cell is applied. Only the loss of the current default network
                                // means there is no connection.
                                if (network.equals(defaultNetwork)) {
                                    defaultNetwork = null;
                                    connectionType = "unavailable";
                                    notifyIfChanged();
                                }
                            }
                        });
            } else {
                context.registerReceiver(
                        new BroadcastReceiver() {
                            @Override
                            public void onReceive(Context receiverContext, Intent intent) {
                                ConnectivityManager manager =
                                        (ConnectivityManager)
                                                receiverContext.getSystemService(
                                                        Context.CONNECTIVITY_SERVICE);
                                if (manager != null) {
                                    readNetwork(manager);
                                    notifyIfChanged();
                                }
                            }
                        },
                        new IntentFilter(ConnectivityManager.CONNECTIVITY_ACTION));
            }
        } catch (RuntimeException e) {
            Log.w(TAG, "Network state unavailable: " + e.getMessage());
        }
    }

    private static void applyCapabilities(@NonNull NetworkCapabilities capabilities) {
        connectionType =
                connectionTypeName(
                        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI),
                        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR),
                        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET));
    }

    /** Reads the network once, for the first value and for the broadcast before API 24. */
    @SuppressWarnings("deprecation")
    private static void readNetwork(@NonNull ConnectivityManager connectivityManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Network active = connectivityManager.getActiveNetwork();
            NetworkCapabilities capabilities =
                    active == null ? null : connectivityManager.getNetworkCapabilities(active);
            if (capabilities != null) {
                applyCapabilities(capabilities);
            } else {
                connectionType = "unavailable";
            }
            return;
        }
        NetworkInfo info = connectivityManager.getActiveNetworkInfo();
        if (info == null || !info.isConnected()) {
            connectionType = "unavailable";
            return;
        }
        connectionType =
                connectionTypeName(
                        info.getType() == ConnectivityManager.TYPE_WIFI,
                        info.getType() == ConnectivityManager.TYPE_MOBILE,
                        info.getType() == ConnectivityManager.TYPE_ETHERNET);
    }

    /**
     * From API 33 the data network type comes from {@code TelephonyManager}, which the
     * install-time {@code READ_BASIC_PHONE_STATE} permission allows. An app can remove that
     * permission, and before API 33 the deprecated {@code NetworkInfo} is the only source that
     * needs none, so both fall back to it.
     */
    @Nullable
    private static String readConnectionSubtype(@NonNull Context context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
                && context.checkSelfPermission(Manifest.permission.READ_BASIC_PHONE_STATE)
                        == PackageManager.PERMISSION_GRANTED) {
            TelephonyManager telephonyManager =
                    (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
            if (telephonyManager != null) {
                return connectionSubtypeName(telephonyManager.getDataNetworkType());
            }
        }
        return readNetworkInfoSubtype(context);
    }

    @SuppressWarnings("deprecation")
    @Nullable
    private static String readNetworkInfoSubtype(@NonNull Context context) {
        ConnectivityManager connectivityManager =
                (ConnectivityManager) context.getSystemService(Context.CONNECTIVITY_SERVICE);
        NetworkInfo info =
                connectivityManager == null ? null : connectivityManager.getActiveNetworkInfo();
        return info == null ? null : connectionSubtypeName(info.getSubtype());
    }

    // getNetworkOperatorName needs no permission, unlike the SIM and
    // data-network calls that need READ_PHONE_STATE.
    @Nullable
    private static String readCarrierName(@NonNull Context context) {
        TelephonyManager telephonyManager =
                (TelephonyManager) context.getSystemService(Context.TELEPHONY_SERVICE);
        if (telephonyManager == null) {
            return null;
        }
        String name = telephonyManager.getNetworkOperatorName();
        return name == null || name.trim().isEmpty() ? null : name.trim();
    }

    /** True for the broadcast that carries battery extras. */
    @VisibleForTesting
    static boolean carriesBatteryExtras(@Nullable String action) {
        return Intent.ACTION_BATTERY_CHANGED.equals(action);
    }

    /** Whole percent from 0 to 100, or null when the system reports no level. */
    @VisibleForTesting
    @Nullable
    static Integer batteryPercent(int level, int scale) {
        if (level < 0 || scale <= 0) {
            return null;
        }
        return Math.min(100, level * 100 / scale);
    }

    /** True for AC, USB or wireless power, whether it charges or the battery is full. */
    @VisibleForTesting
    static boolean isPluggedIn(int plugged) {
        int power =
                BatteryManager.BATTERY_PLUGGED_AC
                        | BatteryManager.BATTERY_PLUGGED_USB
                        | BatteryManager.BATTERY_PLUGGED_WIRELESS;
        return (plugged & power) != 0;
    }

    /**
     * Maps {@code PowerManager.THERMAL_STATUS_*}: none to nominal, light to fair, moderate
     * to serious, and severe and above to critical.
     */
    @VisibleForTesting
    @Nullable
    static String thermalStateName(int status) {
        if (status < 0) {
            return null;
        }
        switch (status) {
            case 0:
                return "nominal";
            case 1:
                return "fair";
            case 2:
                return "serious";
            default:
                return "critical";
        }
    }

    @VisibleForTesting
    @NonNull
    static String connectionTypeName(boolean wifi, boolean cellular, boolean ethernet) {
        if (wifi) {
            return "wifi";
        }
        if (cellular) {
            return "cell";
        }
        if (ethernet) {
            return "wired";
        }
        return "unknown";
    }

    /** Maps {@code TelephonyManager.NETWORK_TYPE_*} to OpenTelemetry subtype names. */
    @VisibleForTesting
    @Nullable
    static String connectionSubtypeName(int networkType) {
        switch (networkType) {
            case TelephonyManager.NETWORK_TYPE_GPRS:
                return "gprs";
            case TelephonyManager.NETWORK_TYPE_EDGE:
                return "edge";
            case TelephonyManager.NETWORK_TYPE_UMTS:
                return "umts";
            case TelephonyManager.NETWORK_TYPE_CDMA:
                return "cdma";
            case TelephonyManager.NETWORK_TYPE_EVDO_0:
                return "evdo_0";
            case TelephonyManager.NETWORK_TYPE_EVDO_A:
                return "evdo_a";
            case TelephonyManager.NETWORK_TYPE_1xRTT:
                return "cdma2000_1xrtt";
            case TelephonyManager.NETWORK_TYPE_HSDPA:
                return "hsdpa";
            case TelephonyManager.NETWORK_TYPE_HSUPA:
                return "hsupa";
            case TelephonyManager.NETWORK_TYPE_HSPA:
                return "hspa";
            case TelephonyManager.NETWORK_TYPE_IDEN:
                return "iden";
            case TelephonyManager.NETWORK_TYPE_EVDO_B:
                return "evdo_b";
            case TelephonyManager.NETWORK_TYPE_LTE:
                return "lte";
            case TelephonyManager.NETWORK_TYPE_EHRPD:
                return "ehrpd";
            case TelephonyManager.NETWORK_TYPE_HSPAP:
                return "hspap";
            case 16: // NETWORK_TYPE_GSM, API 25
                return "gsm";
            case 17: // NETWORK_TYPE_TD_SCDMA, API 25
                return "td_scdma";
            case 18: // NETWORK_TYPE_IWLAN, API 25
                return "iwlan";
            case 19: // NETWORK_TYPE_LTE_CA, API 25
                return "lte_ca";
            case 20: // NETWORK_TYPE_NR, API 29
                return "nr";
            default:
                return null;
        }
    }
}
