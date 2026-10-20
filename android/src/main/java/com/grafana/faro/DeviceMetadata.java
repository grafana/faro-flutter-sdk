package com.grafana.faro;

import android.app.ActivityManager;
import android.content.Context;
import android.hardware.display.DisplayManager;
import android.util.DisplayMetrics;
import android.view.Display;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;

import java.util.HashMap;
import java.util.Map;

import io.flutter.Log;

/**
 * Device metadata that device_info_plus does not expose.
 *
 * <p>Each value is omitted when it cannot be read, so a missing value never
 * fails SDK init.
 */
final class DeviceMetadata {
    private static final String TAG = "FaroDeviceMetadata";

    static final String SCREEN_WIDTH_KEY = "screenWidth";
    static final String SCREEN_HEIGHT_KEY = "screenHeight";
    static final String SCREEN_DENSITY_KEY = "screenDensity";
    static final String MEMORY_TOTAL_KEY = "memoryTotal";

    private DeviceMetadata() {}

    @NonNull
    static Map<String, Object> current(@Nullable Context context) {
        if (context == null) {
            return new HashMap<>();
        }
        DisplayMetrics screen = readScreen(context);
        return build(
                screen != null ? screen.widthPixels : 0,
                screen != null ? screen.heightPixels : 0,
                screen != null ? screen.densityDpi : 0,
                readMemoryTotal(context));
    }

    @VisibleForTesting
    @NonNull
    static Map<String, Object> build(
            int screenWidth, int screenHeight, int densityDpi, long memoryTotal) {
        Map<String, Object> metadata = new HashMap<>();
        if (screenWidth > 0 && screenHeight > 0) {
            metadata.put(SCREEN_WIDTH_KEY, screenWidth);
            metadata.put(SCREEN_HEIGHT_KEY, screenHeight);
        }
        if (densityDpi > 0) {
            // DisplayMetrics.density is a float, so 213 dpi would arrive as
            // 1.3312499523. The division keeps it at 1.33125.
            metadata.put(
                    SCREEN_DENSITY_KEY,
                    densityDpi / (double) DisplayMetrics.DENSITY_DEFAULT);
        }
        if (memoryTotal > 0) {
            metadata.put(MEMORY_TOTAL_KEY, memoryTotal);
        }
        return metadata;
    }

    // getRealMetrics is deprecated from API 31 in favour of WindowManager,
    // which needs an Activity context. From the application context it still
    // reports the whole display, system bars included.
    @SuppressWarnings("deprecation")
    @Nullable
    private static DisplayMetrics readScreen(@NonNull Context context) {
        try {
            DisplayManager displayManager =
                    (DisplayManager) context.getSystemService(Context.DISPLAY_SERVICE);
            if (displayManager == null) {
                return null;
            }
            Display display = displayManager.getDisplay(Display.DEFAULT_DISPLAY);
            if (display == null) {
                return null;
            }
            DisplayMetrics metrics = new DisplayMetrics();
            display.getRealMetrics(metrics);
            return metrics;
        } catch (RuntimeException e) {
            Log.w(TAG, "Screen metrics unavailable: " + e.getMessage());
            return null;
        }
    }

    private static long readMemoryTotal(@NonNull Context context) {
        try {
            ActivityManager activityManager =
                    (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (activityManager == null) {
                return 0;
            }
            ActivityManager.MemoryInfo memoryInfo = new ActivityManager.MemoryInfo();
            activityManager.getMemoryInfo(memoryInfo);
            return memoryInfo.totalMem;
        } catch (RuntimeException e) {
            Log.w(TAG, "Total memory unavailable: " + e.getMessage());
            return 0;
        }
    }
}
