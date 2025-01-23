package com.example.rum_sdk;

import android.app.ApplicationExitInfo;
import android.os.Build;

import androidx.annotation.RequiresApi;

import java.util.Arrays;
import java.util.List;

public final class ApplicationExitInfoExt {
    private ApplicationExitInfoExt() {
        // Prevent instantiation
    }

    @RequiresApi(api = Build.VERSION_CODES.R)
    private static List<Integer> getExitReasonsToCapture() {
        return Arrays.asList(
                ApplicationExitInfo.REASON_ANR,
                ApplicationExitInfo.REASON_CRASH,
                ApplicationExitInfo.REASON_CRASH_NATIVE,
                ApplicationExitInfo.REASON_DEPENDENCY_DIED,
                ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
                ApplicationExitInfo.REASON_EXIT_SELF,
                ApplicationExitInfo.REASON_INITIALIZATION_FAILURE,
                ApplicationExitInfo.REASON_LOW_MEMORY,
                ApplicationExitInfo.REASON_SIGNALED,
                ApplicationExitInfo.REASON_UNKNOWN
        );
    }

    @RequiresApi(api = Build.VERSION_CODES.R)
    public static boolean shouldBeReported(ApplicationExitInfo exitInfo) {
        return getExitReasonsToCapture().contains(exitInfo.getReason());
    }

    @RequiresApi(api = Build.VERSION_CODES.R)
    public static String getUniqueId(ApplicationExitInfo exitInfo) {
        return exitInfo.getTimestamp() + ":" + exitInfo.getPid();
    }

    @RequiresApi(api = Build.VERSION_CODES.R)
    public static String getReasonName(ApplicationExitInfo exitInfo) {
        int reason = exitInfo.getReason();
        switch (reason) {
            case ApplicationExitInfo.REASON_ANR:
                return "ANR";
            case ApplicationExitInfo.REASON_CRASH:
                return "Crash";
            case ApplicationExitInfo.REASON_CRASH_NATIVE:
                return "Native Crash";
            case ApplicationExitInfo.REASON_DEPENDENCY_DIED:
                return "Dependency Died";
            case ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE:
                return "Excessive Resource Usage";
            case ApplicationExitInfo.REASON_EXIT_SELF:
                return "Exit Self";
            case ApplicationExitInfo.REASON_INITIALIZATION_FAILURE:
                return "Initialization Failure";
            case ApplicationExitInfo.REASON_LOW_MEMORY:
                return "Low Memory";
            case ApplicationExitInfo.REASON_OTHER:
                return "Other";
            case ApplicationExitInfo.REASON_PERMISSION_CHANGE:
                return "Permission Change";
            case ApplicationExitInfo.REASON_SIGNALED:
                return "Signaled";
            case ApplicationExitInfo.REASON_UNKNOWN:
                return "Unknown";
            case ApplicationExitInfo.REASON_USER_REQUESTED:
                return "User Requested";
            case ApplicationExitInfo.REASON_USER_STOPPED:
                return "User Stopped";
            default:
                return "Unknown Reason";
        }
    }
}