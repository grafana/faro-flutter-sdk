package com.example.rum_sdk;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;

import androidx.annotation.RequiresApi;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;


public class ExitInfoHelper {
    private final SharedPreferencesService preferencesService;

    public ExitInfoHelper(Context context) {
        this.preferencesService = new SharedPreferencesService(context);
    }

    public List<ApplicationExitInfo> getApplicationExitInfo(Context context) {
        ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);

        if (activityManager != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                List<ApplicationExitInfo> exitInfoList = activityManager.getHistoricalProcessExitReasons(null, 0, 15);
                return filterHandledExitInfo(exitInfoList);
            }
        }

        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.R)
    private List<ApplicationExitInfo> filterHandledExitInfo(List<ApplicationExitInfo> exitInfoList) {
        if (exitInfoList == null || exitInfoList.isEmpty()) {
            return exitInfoList;
        }

        Set<String> handledExitInfo = preferencesService.getHandledExitInfos();
        List<ApplicationExitInfo> newExitInfo = new ArrayList<>();
        Set<String> updatedHandledExitInfo = new HashSet<>(handledExitInfo);

        for (ApplicationExitInfo exitInfo : exitInfoList) {
            String exitInfoKey = ApplicationExitInfoExt.getUniqueId(exitInfo);
            if (!handledExitInfo.contains(exitInfoKey)) {
                newExitInfo.add(exitInfo);
                updatedHandledExitInfo.add(exitInfoKey);
            }
        }

        preferencesService.setHandledExitInfos(updatedHandledExitInfo);

        return newExitInfo;
    }

    public JSONObject getExitInfo(ApplicationExitInfo exitInfo) throws JSONException {
        JSONObject jsonObject = new JSONObject();
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            if(ApplicationExitInfoExt.shouldBeReported(exitInfo)){
                long timestamp = exitInfo.getTimestamp();
                int status = exitInfo.getStatus();
                String description = exitInfo.getDescription();
                jsonObject.put("reason", ApplicationExitInfoExt.getReasonName(exitInfo));
                jsonObject.put("timestamp", timestamp);
                jsonObject.put("status", status);
                jsonObject.put("description", description);
                // format parse tombstone traces for crash and native crash
                // if(reason == ApplicationExitInfo.REASON_CRASH || reason == ApplicationExitInfo.REASON_CRASH_NATIVE){ }
            }
        }
        return jsonObject;
    }
}

