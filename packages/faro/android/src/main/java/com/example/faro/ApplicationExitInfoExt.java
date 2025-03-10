package com.example.faro;

import android.app.ApplicationExitInfo;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;

/**
 * Utility class for handling ApplicationExitInfo objects.
 * Provides methods to determine if an exit should be reported and to extract
 * useful information from exit info objects.
 */
public class ApplicationExitInfoExt {
    private static final String TAG = "ApplicationExitInfoExt";

    // List of exit reasons that should be captured and reported
    private static final List<Integer> EXIT_REASONS_TO_CAPTURE = Collections.unmodifiableList(Arrays.asList(
            ApplicationExitInfo.REASON_ANR,
            ApplicationExitInfo.REASON_CRASH,
            ApplicationExitInfo.REASON_CRASH_NATIVE,
            ApplicationExitInfo.REASON_LOW_MEMORY,
            ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
            ApplicationExitInfo.REASON_INITIALIZATION_FAILURE
    ));

    // Private constructor to prevent instantiation
    private ApplicationExitInfoExt() {
        throw new AssertionError("No instances allowed");
    }

    /**
     * Determine if an exit info should be reported
     * @param exitInfo The exit info to check
     * @return true if the exit should be reported, false otherwise
     */
    @RequiresApi(api = Build.VERSION_CODES.R)
    public static boolean shouldBeReported(@NonNull ApplicationExitInfo exitInfo) {
        try {
            return EXIT_REASONS_TO_CAPTURE.contains(exitInfo.getReason());
        } catch (Exception e) {
            Log.e(TAG, "Error checking if exit info should be reported", e);
            return false;
        }
    }

    /**
     * Generate a unique ID for an exit info
     * @param exitInfo The exit info to generate an ID for
     * @return A unique string ID based on timestamp and process ID
     */
    @RequiresApi(api = Build.VERSION_CODES.R)
    public static String getUniqueId(@NonNull ApplicationExitInfo exitInfo) {
        try {
            return exitInfo.getTimestamp() + "_" + exitInfo.getPid();
        } catch (Exception e) {
            Log.e(TAG, "Error generating unique ID for exit info", e);
            // Fallback to current time if there's an error
            return System.currentTimeMillis() + "_fallback";
        }
    }

    /**
     * Get a human-readable name for an exit reason
     * @param exitInfo The exit info to get the reason name for
     * @return A human-readable string describing the exit reason
     */
    @RequiresApi(api = Build.VERSION_CODES.R)
    public static String getReasonName(@NonNull ApplicationExitInfo exitInfo) {
        try {
            int reason = exitInfo.getReason();
            switch (reason) {
                case ApplicationExitInfo.REASON_ANR:
                    return "ANR";
                case ApplicationExitInfo.REASON_CRASH:
                    return "CRASH";
                case ApplicationExitInfo.REASON_CRASH_NATIVE:
                    return "CRASH_NATIVE";
                case ApplicationExitInfo.REASON_DEPENDENCY_DIED:
                    return "DEPENDENCY_DIED";
                case ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE:
                    return "EXCESSIVE_RESOURCE_USAGE";
                case ApplicationExitInfo.REASON_EXIT_SELF:
                    return "EXIT_SELF";
                case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
                    return "INITIALIZATION_FAILURE";
                case ApplicationExitInfo.REASON_LOW_MEMORY:
                    return "LOW_MEMORY";
                case ApplicationExitInfo.REASON_OTHER:
                    return "OTHER";
                case ApplicationExitInfo.REASON_PERMISSION_CHANGE:
                    return "PERMISSION_CHANGE";
                case ApplicationExitInfo.REASON_SIGNALED:
                    return "SIGNALED";
                case ApplicationExitInfo.REASON_USER_REQUESTED:
                    return "USER_REQUESTED";
                case ApplicationExitInfo.REASON_USER_STOPPED:
                    return "USER_STOPPED";
                default:
                    return "UNKNOWN_" + reason;
            }
        } catch (Exception e) {
            Log.e(TAG, "Error getting reason name for exit info", e);
            return "ERROR_GETTING_REASON";
        }
    }

    /**
     * Determine if an exit info should be filtered out based on specific criteria
     * This filters out normal system terminations of background apps due to low memory
     * @param exitInfo The exit info to check
     * @return true if the exit should be filtered out (not reported), false otherwise
     */
    @RequiresApi(api = Build.VERSION_CODES.R)
    public static boolean shouldBeFilteredOut(@NonNull ApplicationExitInfo exitInfo) {
        try {
            // Filter out: status code 0 (normal exit) + importance > 300 (background) + reason LOW_MEMORY
            return exitInfo.getStatus() == 0 && 
                   exitInfo.getImportance() > 300 && 
                   exitInfo.getReason() == ApplicationExitInfo.REASON_LOW_MEMORY;
        } catch (Exception e) {
            Log.e(TAG, "Error checking if exit info should be filtered out", e);
            return false; // When in doubt, don't filter out
        }
    }
}