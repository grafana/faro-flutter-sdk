package com.example.rum_sdk;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

/**
 * Helper class to retrieve and process application exit information.
 * This class handles the retrieval of crash and ANR information from the system.
 */
public class ExitInfoHelper {
    private static final String TAG = "ExitInfoHelper";
    private static final int MAX_EXIT_REASONS = 15; // Maximum number of exit reasons to retrieve
    private static final int MAX_TRACE_BYTES = 1024 * 1024; // 1MB max for trace data
    
    private final SharedPreferencesService preferencesService;

    /**
     * Constructor for ExitInfoHelper
     * @param context Application context used for SharedPreferences
     */
    public ExitInfoHelper(@NonNull Context context) {
        this.preferencesService = new SharedPreferencesService(context);
    }

    /**
     * Get application exit information from the system
     * @param context Context to access system services
     * @return List of ApplicationExitInfo objects, or null if not available
     */
    @Nullable
    public List<ApplicationExitInfo> getApplicationExitInfo(@Nullable Context context) {
        if (context == null) {
            Log.e(TAG, "Context is null when getting application exit info");
            return null;
        }
        
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            Log.d(TAG, "ApplicationExitInfo requires API level 30 (Android 11) or higher");
            return null;
        }
        
        try {
            ActivityManager activityManager = (ActivityManager) context.getSystemService(Context.ACTIVITY_SERVICE);
            if (activityManager == null) {
                Log.e(TAG, "ActivityManager is null");
                return null;
            }
            
            List<ApplicationExitInfo> exitInfoList = activityManager.getHistoricalProcessExitReasons(
                    null, 0, MAX_EXIT_REASONS);
            
            if (exitInfoList == null || exitInfoList.isEmpty()) {
                Log.d(TAG, "No exit information available");
                return null;
            }
            
            return filterHandledExitInfo(exitInfoList);
        } catch (Exception e) {
            Log.e(TAG, "Error getting application exit info", e);
            return null;
        }
    }

    /**
     * Filter out already handled exit information to avoid duplicates
     * @param exitInfoList List of exit information to filter
     * @return Filtered list containing only new exit information
     */
    @RequiresApi(api = Build.VERSION_CODES.R)
    private List<ApplicationExitInfo> filterHandledExitInfo(@NonNull List<ApplicationExitInfo> exitInfoList) {
        if (exitInfoList.isEmpty()) {
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

    /**
     * Convert ApplicationExitInfo to a JSON object with relevant information
     * @param exitInfo The exit information to convert
     * @return JSON object with exit information, or null if not reportable
     */
    @Nullable
    @RequiresApi(api = Build.VERSION_CODES.R)
    public JSONObject getExitInfo(@NonNull ApplicationExitInfo exitInfo) throws JSONException {
        if (!ApplicationExitInfoExt.shouldBeReported(exitInfo)) {
            return null;
        }
        
        JSONObject jsonObject = new JSONObject();
        try {
            String reason = ApplicationExitInfoExt.getReasonName(exitInfo);
            long timestamp = exitInfo.getTimestamp();
            int status = exitInfo.getStatus();
            String description = exitInfo.getDescription();
            int importance = exitInfo.getImportance();
            int pid = exitInfo.getPid();
            String processName = exitInfo.getProcessName();
            
            jsonObject.put("reason", reason);
            jsonObject.put("timestamp", timestamp);
            jsonObject.put("status", status);
            jsonObject.put("description", description);
            jsonObject.put("importance", importance);
            jsonObject.put("pid", pid);
            jsonObject.put("processName", processName);
            
            // Add trace data for crashes if available
            int reasonCode = exitInfo.getReason();
            if ((reasonCode == ApplicationExitInfo.REASON_CRASH || 
                 reasonCode == ApplicationExitInfo.REASON_CRASH_NATIVE || 
                 reasonCode == ApplicationExitInfo.REASON_ANR) && 
                exitInfo.getTraceInputStream() != null) {
                
                String trace = readTraceInputStream(exitInfo);
                if (trace != null && !trace.isEmpty()) {
                    jsonObject.put("trace", trace);
                }
            }
            
            return jsonObject;
        } catch (Exception e) {
            Log.e(TAG, "Error creating exit info JSON", e);
            // Return basic info even if there was an error with some fields
            return jsonObject.length() > 0 ? jsonObject : null;
        }
    }
    
    /**
     * Read trace data from the exit info
     * @param exitInfo The exit information containing trace data
     * @return String representation of the trace, or null if not available
     */
    @Nullable
    @RequiresApi(api = Build.VERSION_CODES.R)
    private String readTraceInputStream(@NonNull ApplicationExitInfo exitInfo) {
        InputStream traceInputStream = null;
        try {
            traceInputStream = exitInfo.getTraceInputStream();
            if (traceInputStream == null) {
                return null;
            }
            
            ByteArrayOutputStream result = new ByteArrayOutputStream();
            byte[] buffer = new byte[4096];
            int totalBytesRead = 0;
            int bytesRead;
            
            while ((bytesRead = traceInputStream.read(buffer)) != -1) {
                result.write(buffer, 0, bytesRead);
                totalBytesRead += bytesRead;
                
                // Limit the size of trace data to prevent OOM
                if (totalBytesRead > MAX_TRACE_BYTES) {
                    Log.w(TAG, "Trace data too large, truncating");
                    break;
                }
            }
            
            return result.toString(StandardCharsets.UTF_8.name());
        } catch (IOException e) {
            Log.e(TAG, "Error reading trace data", e);
            return null;
        } finally {
            if (traceInputStream != null) {
                try {
                    traceInputStream.close();
                } catch (IOException e) {
                    Log.e(TAG, "Error closing trace input stream", e);
                }
            }
        }
    }
}


