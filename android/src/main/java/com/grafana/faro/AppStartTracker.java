package com.grafana.faro;

import android.app.ActivityManager;
import android.os.Build;
import android.os.Process;
import android.os.SystemClock;

import androidx.annotation.NonNull;
import androidx.annotation.VisibleForTesting;

import java.util.HashMap;
import java.util.Map;

import io.flutter.Log;

/**
 * Measures cold start duration and decides whether the current process was
 * started for a reason the user could actually see.
 *
 * <p>Android forks app processes for many reasons that never put anything on
 * screen: push messages, scheduled jobs, broadcasts, or another app querying an
 * exported ContentProvider. Such a process then sits in the LRU cache with no
 * timeout, so the interval between process start and the first frame can be
 * hours or days and says nothing about how long a user waited. Reporting that
 * as a cold start makes any percentile over the metric meaningless.
 *
 * <p>The signal that tells the cases apart is the process importance recorded
 * by {@link FaroStartupProvider} at process init. It has to be sampled before
 * any app code runs, because once an Activity exists every process reports
 * foreground importance. A process forked for background work is not
 * foreground at that moment; one Android brought up to show UI is.
 *
 * <p>{@link android.app.ApplicationStartInfo}, added in API 35, looks like a
 * better answer and is deliberately not used. Its records are persisted across
 * reboots and carry per-boot uptime timestamps, with the ordering clock hidden
 * from apps, so a record cannot be tied to the current launch: matching on
 * process name finds stale records from earlier boots, and matching on pid
 * fails because the record for a cold start keeps {@code pid=0}. The API also
 * only says it <em>might</em> include the in-progress start, and in practice
 * the record for the launch being measured is not filed by the time the first
 * frame renders. Consulting it therefore replaced a correct answer with a
 * wrong one. The same cases it would have caught are already covered here: a
 * launcher tap into a process that was forked in the background is rejected,
 * because the importance sample was taken when that fork happened.
 *
 * <p>The duration is reported as-is; the Dart side applies the plausibility
 * bound so the same limit holds on both platforms.
 */
final class AppStartTracker {
    private static final String TAG = "AppStartTracker";

    /**
     * Whether Android started this process to show UI, as sampled at process
     * init. Written from {@link FaroStartupProvider} on the main thread and
     * read later from the Flutter platform-channel thread.
     */
    private static volatile boolean foregroundAtProcessInit = false;

    private AppStartTracker() {}

    /**
     * Records whether Android started this process to show UI.
     *
     * <p>Called from {@link FaroStartupProvider#onCreate()}, which the platform
     * runs before {@code Application.onCreate()}. The answer is only correct at
     * that point.
     */
    static void recordProcessInit() {
        try {
            final ActivityManager.RunningAppProcessInfo processInfo =
                    new ActivityManager.RunningAppProcessInfo();
            ActivityManager.getMyMemoryState(processInfo);
            foregroundAtProcessInit = processInfo.importance
                    == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
        } catch (Exception error) {
            // Without the sample we cannot prove the launch was user-visible,
            // so leave the flag false and let the cold start be discarded.
            Log.w(TAG, "Could not sample process importance at process init", error);
            foregroundAtProcessInit = false;
        }
    }

    /**
     * Returns the cold start payload for the Dart side.
     *
     * <p>{@code appStartDurationMillis} is from process start to now, or
     * a negative value when the platform cannot report a process start time.
     * {@code isUserVisibleColdStart} is false when the process was started for
     * something the user never saw. {@code prewarmed} is always false on
     * Android, which has no prewarming; it is sent anyway so that this payload
     * carries the same keys as the iOS one. The Dart side treats a missing
     * value as false, so the key is for the contract, not for behaviour.
     */
    @NonNull
    static Map<String, Object> getColdStartMetrics() {
        final Map<String, Object> metrics = new HashMap<>();
        metrics.put("appStartDurationMillis", getDurationMillis());
        metrics.put(
                "isUserVisibleColdStart",
                resolveUserVisible(Build.VERSION.SDK_INT, foregroundAtProcessInit));
        metrics.put("prewarmed", false);
        return metrics;
    }

    /**
     * Milliseconds from process start until now, or -1 when unavailable.
     *
     * <p>Uses {@link SystemClock#uptimeMillis()} rather than
     * {@code elapsedRealtime()} so that time the device spent in deep sleep is
     * not counted as startup work.
     */
    private static long getDurationMillis() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
            return -1;
        }
        return SystemClock.uptimeMillis() - Process.getStartUptimeMillis();
    }

    /**
     * Decides whether to report, given what we managed to find out.
     *
     * <p>Reporting stops entirely below API 24, because there is no process
     * start time to measure from.
     *
     * @param importanceSample the process importance recorded at process init.
     */
    @VisibleForTesting
    static boolean resolveUserVisible(int sdkInt, boolean importanceSample) {
        if (sdkInt < Build.VERSION_CODES.N) {
            return false;
        }
        return importanceSample;
    }
}
