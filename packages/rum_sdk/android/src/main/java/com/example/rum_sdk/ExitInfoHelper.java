package com.example.rum_sdk;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;

import androidx.annotation.RequiresApi;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.Arrays;


import java.util.List;


public class ExitInfoHelper {

    public static List<ApplicationExitInfo> getApplicationExitInfo(Context context) {
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);

        if (activityManager != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                return activityManager.getHistoricalProcessExitReasons(null, 0, 15);
            }
        }

        return null;
    }

    public static JSONObject getExitInfo(ApplicationExitInfo exitInfo) throws JSONException {
        JSONObject jsonObject = new JSONObject();
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            int reason = exitInfo.getReason();
            if(getExitReasonsToCapture().contains(reason)){
                long timestamp = exitInfo.getTimestamp();
                int status = exitInfo.getStatus();
                String description = exitInfo.getDescription();
                jsonObject.put("reason", getReasonName(reason));
                jsonObject.put("timestamp", timestamp);
                jsonObject.put("status", status);
                jsonObject.put("description", description);
                // format parse tombstone traces for crash and native crash
                // if(reason == ApplicationExitInfo.REASON_CRASH || reason == ApplicationExitInfo.REASON_CRASH_NATIVE){ }
            }
        }
        return jsonObject;
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

    private static String getReasonName(int reason) {
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
