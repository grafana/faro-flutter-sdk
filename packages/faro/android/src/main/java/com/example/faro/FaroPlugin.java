package com.example.faro;

import android.app.Activity;
import android.app.Application;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import android.os.Debug;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.os.SystemClock;
import android.view.Choreographer;
import android.view.Window;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * FaroPlugin
 * 
 * This plugin provides native functionality for the RUM SDK, including:
 * - Memory usage monitoring
 * - CPU usage monitoring
 * - ANR detection
 * - Crash reporting
 * - Frame rate monitoring
 */
public class FaroPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;
    private Context applicationContext;
    private @Nullable WeakReference<Activity> activity = null;
    private @Nullable ANRTracker anrTracker;
    private @Nullable ExitInfoHelper exitInfoHelper;
    private @Nullable Window window;
    private @Nullable Application application;

    private FlutterPluginBinding pluginBinding;
    private long lastFrameTimeNanos = 0;
    final int[] frozenFrameCount = {0};

    private static final long NANOSECONDS_IN_SECOND = 1_000_000_000L;
    private static final String TAG = "FaroPlugin";

    Double refreshRate = 0.0;
    private int count = 0;
    private int frameCount = 0;
    private AtomicInteger slowFrames = new AtomicInteger(0);

    private boolean isAnrTrackerRunning = false;
    private boolean isActivityResumed = false;
    
    private final Application.ActivityLifecycleCallbacks activityLifecycleCallbacks = new Application.ActivityLifecycleCallbacks() {
        @Override
        public void onActivityCreated(Activity activity, android.os.Bundle savedInstanceState) {
            // Not needed for our purposes
        }

        @Override
        public void onActivityStarted(Activity activity) {
            // Not needed for our purposes
        }

        @Override
        public void onActivityResumed(Activity activity) {
            Log.d(TAG, "Activity resumed (foreground)");
            isActivityResumed = true;
            
            // Ensure we start the ANR tracker when app comes to foreground
            if (!isAnrTrackerRunning && isActivityResumed) {
                Log.d(TAG, "Starting tracker from resume");
                
                // Ensure we don't have a lingering ANR tracker
                if (anrTracker != null) {
                    Log.d(TAG, "Cleaning up old tracker before starting new one");
                    try {
                        anrTracker.stopTracking();
                    } catch (Exception e) {
                        Log.e(TAG, "Error stopping old tracker", e);
                    }
                }
                
                anrTracker = new ANRTracker();
                anrTracker.start();
                isAnrTrackerRunning = true;
            }
            
            // Restart frame monitoring
            startFrameMonitoring();
        }

        @Override
        public void onActivityPaused(Activity activity) {
            Log.d(TAG, "Activity paused (background)");
            isActivityResumed = false;
            
            // Stop ANR tracking when app goes to background
            if (isAnrTrackerRunning && anrTracker != null) {
                Log.d(TAG, "Stopping tracker from pause");
                
                try {
                    anrTracker.stopTracking();
                } catch (Exception e) {
                    Log.e(TAG, "Error stopping tracker", e);
                } finally {
                    Log.d(TAG, "Cleanup or stop monitoring if needed");
                    anrTracker = null;
                    isAnrTrackerRunning = false;
                }
            }
            
            // Stop frame monitoring
            stopFrameMonitoring();
        }

        @Override
        public void onActivityStopped(Activity activity) {
            // Not needed for our purposes
        }

        @Override
        public void onActivitySaveInstanceState(Activity activity, android.os.Bundle outState) {
            // Not needed for our purposes
        }

        @Override
        public void onActivityDestroyed(Activity activity) {
            // Not needed for our purposes
        }
    };

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        Log.d(TAG, "onAttachedToEngine");
        this.pluginBinding = flutterPluginBinding;
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "faro");
        channel.setMethodCallHandler(this);
        
        // Store application context which is more stable than activity context
        this.applicationContext = flutterPluginBinding.getApplicationContext();
        
        // Initialize ExitInfoHelper with application context
        if (this.exitInfoHelper == null && this.applicationContext != null) {
            this.exitInfoHelper = new ExitInfoHelper(applicationContext);
        }
        
        ExceptionHandler exceptionHandler = new ExceptionHandler();
        exceptionHandler.install();

        // StrictMode.setVmPolicy(new StrictMode.VmPolicy.Builder(StrictMode.getVmPolicy()) .detectLeakedClosableObjects() .build());
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        Log.d(TAG, "attached to Activity");
        
        if (binding.getActivity() != null) {
            activity = new WeakReference<>(binding.getActivity());
            window = activity.get().getWindow();
            // Update application context from activity if needed
            if (applicationContext == null) {
                applicationContext = activity.get().getApplicationContext();
            }
            
            // Register activity lifecycle callbacks
            if (activity.get() != null && activity.get().getApplication() != null) {
                application = activity.get().getApplication();
                application.registerActivityLifecycleCallbacks(activityLifecycleCallbacks);
                
                // Check if activity is currently resumed (visible to user)
                isActivityResumed = true;
            }
        }
        
        // Start ANR tracking if enabled and activity is resumed
        if (!isAnrTrackerRunning && isActivityResumed) {
            // Ensure we don't have a lingering ANR tracker
            if (anrTracker != null) {
                Log.d(TAG, "Cleaning up old tracker before starting new one");
                try {
                    anrTracker.stopTracking();
                } catch (Exception e) {
                    Log.e(TAG, "Error stopping old tracker", e);
                }
            }
            
            anrTracker = new ANRTracker();
            anrTracker.start();
            isAnrTrackerRunning = true;
        }
        
        // Ensure exitInfoHelper is initialized with a valid context
        if (exitInfoHelper == null && applicationContext != null) {
            exitInfoHelper = new ExitInfoHelper(applicationContext);
        }
        
        // Start frame monitoring if activity is resumed
        if (isActivityResumed) {
            startFrameMonitoring();
        }
    }
    
    @Override
    public void onDetachedFromActivityForConfigChanges() {
        Log.d(TAG, "detached from Activity (config change)");
        
        // Set isActivityResumed to false during config changes
        isActivityResumed = false;
        
        // Stop ANR tracking if running
        if (isAnrTrackerRunning && anrTracker != null) {
            try {
                anrTracker.stopTracking();
            } catch (Exception e) {
                Log.e(TAG, "Error stopping tracker", e);
            } finally {
                anrTracker = null;
                isAnrTrackerRunning = false;
            }
        }
        
        // Unregister activity lifecycle callbacks during config change
        if (application != null) {
            application.unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks);
        }
        
        // Stop frame monitoring
        stopFrameMonitoring();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        Log.d(TAG, "reattached to Activity");
        
        if (binding.getActivity() != null) {
            activity = new WeakReference<>(binding.getActivity());
            window = activity.get().getWindow();
            
            // Re-register activity lifecycle callbacks
            if (activity.get() != null && activity.get().getApplication() != null) {
                application = activity.get().getApplication();
                application.registerActivityLifecycleCallbacks(activityLifecycleCallbacks);
                
                // Activity is considered resumed after reattachment for config changes
                isActivityResumed = true;
            }
        }
        
        // Restart ANR tracking if enabled and activity is resumed
        if (!isAnrTrackerRunning && isActivityResumed) {
            // Ensure we don't have a lingering ANR tracker
            if (anrTracker != null) {
                Log.d(TAG, "Cleaning up old tracker before starting new one");
                try {
                    anrTracker.stopTracking();
                } catch (Exception e) {
                    Log.e(TAG, "Error stopping old tracker", e);
                }
            }
            
            anrTracker = new ANRTracker();
            anrTracker.start();
            isAnrTrackerRunning = true;
        }
        
        // Restart frame monitoring if activity is resumed
        if (isActivityResumed) {
            startFrameMonitoring();
        }
    }

    @Override
    public void onDetachedFromActivity() {
        Log.d(TAG, "detached from Activity");
        
        // Stop ANR tracking if running
        if (isAnrTrackerRunning && anrTracker != null) {
            try {
                anrTracker.stopTracking();
            } catch (Exception e) {
                Log.e(TAG, "Error stopping tracker", e);
            } finally {
                anrTracker = null;
                isAnrTrackerRunning = false;
            }
        }
        
        // Stop frame monitoring
        stopFrameMonitoring();
        
        // Unregister activity lifecycle callbacks
        if (application != null) {
            application.unregisterActivityLifecycleCallbacks(activityLifecycleCallbacks);
        }
        
        window = null;
        isActivityResumed = false;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Log.d(TAG, "onDetachedFromEngine");
        channel.setMethodCallHandler(null);
        channel = null;
    }

    // test
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            if (call.method != null) {
                switch (call.method) {
                    case "initRefreshRate":
                        this.lastFrameTimeNanos = 0;
                        this.count = 0;
                        startFrameMonitoring();
                        result.success(checkFrozenFrames());
                        break;
                    case "getMemoryUsage":
                        result.success(MemoryUsageInfo.onGetMemoryUsageInfo());
                        break;
                    case "getCpuUsage":
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                            result.success(CPUInfo.onGetCpuInfo());
                        }
                        else{
                            result.success(null);
                        }
                        break;
                    case "getCrashReport":
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                            // Check if exitInfoHelper is initialized
                            if (exitInfoHelper == null) {
                                if (applicationContext != null) {
                                    exitInfoHelper = new ExitInfoHelper(applicationContext);
                                } else {
                                    Log.e(TAG, "Cannot initialize ExitInfoHelper: applicationContext is null");
                                    result.success(null);
                                    break;
                                }
                            }
                            
                            List<String> exitInfo;
                            try {
                                exitInfo = getExitInfo();
                                result.success(exitInfo);
                            } catch (JSONException e) {
                                Log.e(TAG, "Error getting exit info: " + e.getMessage());
                                result.success(null);
                            } catch (NullPointerException e) {
                                Log.e(TAG, "NullPointerException in getExitInfo: " + e.getMessage());
                                result.success(null);
                            }
                        } else {
                            result.success(null);
                        }
                        break;
                    case "getANRStatus":
                        List<String> anrStatuses = ANRTracker.getANRStatus();
                        ANRTracker.resetANR();
                        result.success(anrStatuses);
                        break;
                    case "getAppStart":
                        Map<String, Object> appStart = new HashMap<>();
                        appStart.put("appStartDuration", getAppStart());
                        result.success(appStart);
                        break;
                    default:
                        result.notImplemented();
                        break;
                }
            }
        } catch (Exception error) {
            Log.e(TAG, "Error handling method call: " + call.method, error);
            result.error("NATIVE_ERROR", "Error in native code: " + error.getMessage(), null);
        }
    }

    private void startFrameMonitoring() {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.JELLY_BEAN) {
            Choreographer.getInstance().postFrameCallback(frameTimeNanos -> {
                checkFrameDuration(frameTimeNanos);
                if(this.count<5){
                    startFrameMonitoring();
                }
            });
        } else {
            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                checkFrameDuration(System.nanoTime());
                startFrameMonitoring();
            }, 16);
        }
    }

    private void stopFrameMonitoring() {
        // Cleanup or stop monitoring if needed
        Log.d("Cleanup or stop monitoring if needed","");
    }

    private List<String> getExitInfo() throws JSONException {
        if (exitInfoHelper == null || applicationContext == null) {
            Log.e(TAG, "ExitInfoHelper or applicationContext is null");
            return null;
        }
        
        List<ApplicationExitInfo> exitInfos = exitInfoHelper.getApplicationExitInfo(applicationContext);
        if (exitInfos == null) {
            return null;
        }
        
        List<String> infoList = new ArrayList<>();
        for (ApplicationExitInfo exitInfo : exitInfos) {
            JSONObject info = exitInfoHelper.getExitInfo(exitInfo);
            if(info != null && info.length() > 0){
                String infoString = info.toString();
                infoList.add(infoString);
            }
        }
        
        return infoList.isEmpty() ? null : infoList;
    }

    private int checkFrozenFrames() {
        return this.frozenFrameCount[0];
    }

    private void checkFrameDuration(long frameTimeNanos) {
        long frameDuration = frameTimeNanos - lastFrameTimeNanos;
        this.frameCount++;
        this.refreshRate = NANOSECONDS_IN_SECOND / (double) frameDuration;
        if(lastFrameTimeNanos !=0){
            handleRefreshRate();
        }
        double fps = this.frameCount / (frameDuration / (double) NANOSECONDS_IN_SECOND);
        // Reset counters for the next second
        this.frameCount = 0;
        this.count++;

        // Check for slow or frozen frames based on your thresholds
        if (fps < 60) {
            // Handle slow frames
            this.slowFrames.incrementAndGet();
            handleSlowFrameDrop();
        }

        if (lastFrameTimeNanos != 0 && frameDuration > 100_000_000L) {
            this.frozenFrameCount[0]++;
            handleFrameDrop();
        }
        lastFrameTimeNanos = frameTimeNanos;
    }

    private long getAppStart(){
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            return SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime();
        }
        return 0;
    }

    private void handleFrameDrop() {
        int frozenFrame = this.frozenFrameCount[0];
        // Handle the frozen frame event, e.g., log, send an event to Dart, etc.
        channel.invokeMethod("onFrozenFrame", frozenFrame);
        this.frozenFrameCount[0] = 0;
    }

    private void handleSlowFrameDrop() {
        int slowFramesCount = this.slowFrames.get();
        // Handle the frozen frame event, e.g., log, send an event to Dart, etc.
        channel.invokeMethod("onSlowFrames", slowFramesCount);
        this.slowFrames.set(0);
    }

    private void handleRefreshRate() {
        Object refreshRates = this.refreshRate;
        // Handle the frozen frame event, e.g., log, send an event to Dart, etc.
        channel.invokeMethod("onRefreshRate", refreshRates);
        this.refreshRate = 0.0;
    }
}
