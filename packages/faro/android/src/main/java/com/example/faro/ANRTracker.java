package com.example.faro;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * ANRTracker detects Application Not Responding (ANR) situations by monitoring the main thread.
 * It posts a task to the main thread and checks if it completes within a specified timeout.
 * If the task doesn't complete in time, it indicates the main thread is blocked (ANR).
 */
public class ANRTracker extends Thread {
    private static final String TAG = "ANRTracker";
    private static final long TIMEOUT = 5000L; // Time interval for checking ANR, in milliseconds
    private static final long CHECK_INTERVAL = 500L; // Time to wait between checks, in milliseconds
    
    // Thread-safe list to store ANR information
    private static final List<String> anrList = Collections.synchronizedList(new ArrayList<>());
    
    private final Handler mainHandler = new Handler(Looper.getMainLooper());
    private final Thread mainThread = Looper.getMainLooper().getThread();
    private final AtomicBoolean isRunning = new AtomicBoolean(true);
    private final AtomicBoolean taskExecuted = new AtomicBoolean(false);
    
    private final Runnable checkTask = () -> {
        // This task runs on the main thread
        taskExecuted.set(true);
    };

    /**
     * Get the list of ANR events that have been detected
     * @return List of ANR stack traces as strings, or null if no ANRs detected
     */
    public static List<String> getANRStatus() {
        if (anrList.isEmpty()) {
            return null;
        }
        // Return a copy to avoid concurrent modification issues
        synchronized (anrList) {
            return new ArrayList<>(anrList);
        }
    }

    /**
     * Clear the ANR events list
     */
    public static void resetANR() {
        synchronized (anrList) {
            anrList.clear();
        }
    }

    @Override
    public void run() {
        Log.d(TAG, "Tracking started");
        
        while (isRunning.get() && !isInterrupted()) {
            try {
                // Capture start time
                long startTime = System.currentTimeMillis();
                
                // Reset the flag before posting the task
                taskExecuted.set(false);
                
                // Post the task to the main thread
                mainHandler.post(checkTask);
                
                // Wait for a short time to give the main thread a chance to execute the task
                sleep(CHECK_INTERVAL);
                
                // Check if we've been interrupted or should stop
                if (!isRunning.get() || isInterrupted()) {
                    Log.d(TAG, "Tracking interrupted or stopped during execution");
                    break;
                }
                
                // If the task hasn't executed after the check interval, start monitoring for ANR
                if (!taskExecuted.get()) {
                    Log.d(TAG, "Task not executed after initial check");

                    // Calculate how much more time to wait for a total of TIMEOUT since we started
                    long elapsedTime = System.currentTimeMillis() - startTime;
                    long remainingTime = TIMEOUT - elapsedTime;
                    
                    // Wait for the remaining time if needed
                    if (remainingTime > 0) {
                        sleep(remainingTime);
                        Log.d(TAG, "Waited additional " + remainingTime + "ms");
                        
                        // Check again if we should exit
                        if (!isRunning.get() || isInterrupted()) {
                            Log.d(TAG, "Tracking interrupted or stopped during additional wait");
                            break;
                        }
                    }
                    
                    // Check again if the task has executed
                    if (!taskExecuted.get()) {
                        Log.d(TAG, "Task is still not executed after " + TIMEOUT + "ms");
                        // The main thread is blocked - this is an ANR
                        handleAnrDetected();
                    }
                }
                
                // Calculate total time spent in this cycle
                long cycleTime = System.currentTimeMillis() - startTime;
                
                // Wait before next check cycle to maintain 5 second intervals
                long timeToNextCheck = TIMEOUT - cycleTime;
                if (timeToNextCheck > 0) {
                    sleep(timeToNextCheck);
                    
                    // One final check if we should exit
                    if (!isRunning.get() || isInterrupted()) {
                        Log.d(TAG, "Tracking interrupted or stopped during between-cycle wait");
                        break;
                    }
                }
            } catch (InterruptedException e) {
                // Check if this was due to a deliberate stopTracking call
                if (!isRunning.get()) {
                    // This is a normal shutdown, no need to log as a warning
                    Log.d(TAG, "Tracking thread interrupted during normal shutdown");
                } else {
                    // This is an unexpected interruption
                    Log.w(TAG, "Tracking unexpectedly interrupted", e);
                }
                Thread.currentThread().interrupt();
                return;
            }
        }
        
        Log.d(TAG, "Tracking stopped");
    }
    
    /**
     * Stop the ANR tracker
     */
    public void stopTracking() {
        Log.d(TAG, "stopTracking called - shutting down tracker");
        
        // First set the running flag to false before interrupting
        // This helps us distinguish between normal shutdown and unexpected interruptions
        isRunning.set(false);
        
        // Remove any pending tasks on the main handler
        mainHandler.removeCallbacks(checkTask);
        
        // Now interrupt the thread
        interrupt();
        
        Log.d(TAG, "Tracker shutdown complete");
    }
    
    /**
     * Handle ANR detection by capturing stack trace and storing information
     */
    private void handleAnrDetected() {
        try {
            // Get the main thread's stack trace
            StackTraceElement[] stackTrace = mainThread.getStackTrace();
            
            // Build a readable stack trace
            StringBuilder stackTraceStr = new StringBuilder();
            for (StackTraceElement element : stackTrace) {
                stackTraceStr.append(element.getClassName())
                        .append(".")
                        .append(element.getMethodName())
                        .append("(")
                        .append(element.getFileName())
                        .append(":")
                        .append(element.getLineNumber())
                        .append(")\n");
            }
            
            // Create JSON object with ANR information
            JSONObject anrInfo = new JSONObject();
            try {
                anrInfo.put("type", "ANR");
                anrInfo.put("timestamp", System.currentTimeMillis());
                anrInfo.put("stacktrace", stackTraceStr.toString());
                
                // Add duration estimate (at least TIMEOUT ms)
                anrInfo.put("duration", TIMEOUT);
            } catch (JSONException e) {
                Log.e(TAG, "Error creating ANR JSON", e);
            }
            
            // Store the ANR information
            String anrData = anrInfo.toString();
            synchronized (anrList) {
                anrList.add(anrData);
            }
            
            Log.w(TAG, "ANR detected: " + stackTraceStr);
        } catch (Exception e) {
            Log.e(TAG, "Error handling ANR", e);
        }
    }
}
