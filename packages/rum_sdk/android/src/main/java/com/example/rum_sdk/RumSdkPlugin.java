package com.example.rum_sdk;

import android.app.Activity;
import android.app.Application;
import android.app.ApplicationExitInfo;
import android.content.Context;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.os.SystemClock;
import android.view.Choreographer;
import android.view.Window;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** RumSdkPlugin */
public class RumSdkPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private Context context;
  private @Nullable WeakReference<Activity> activity= null;
  private ANRTracker anrTracker;
  private Window window;
  private Application application;

  private FlutterPluginBinding pluginBinding;
  private long lastFrameTimeNanos = 0;
  final int[] frozenFrameCount = {0};

  private static final long NANOSECONDS_IN_SECOND = 1_000_000_000L;

  Double refreshRate = 0.0;
  private int count = 0;

  private int frameCount = 0;

  private int slowFrames = 0;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    this.pluginBinding = flutterPluginBinding;
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "rum_sdk");
    channel.setMethodCallHandler(this);
    RumCache.setContext(flutterPluginBinding.getApplicationContext());
    ExceptionHandler exceptionHandler = new ExceptionHandler();
    exceptionHandler.install();

    // StrictMode.setVmPolicy(new StrictMode.VmPolicy.Builder(StrictMode.getVmPolicy()) .detectLeakedClosableObjects() .build());
  }

  @Override
  public void onAttachedToActivity(ActivityPluginBinding binding){
    anrTracker = new ANRTracker();
    anrTracker.start();

    startFrameMonitoring();
    activity = new WeakReference<>(binding.getActivity());
    if(activity.get()!=null){
      window = activity.get().getWindow();
    }
    context = binding.getActivity();
    RumCache.setContext(activity.get().getApplicationContext());
    RumCache rumCache = new RumCache();
    ArrayList<String> lst = rumCache.readFromCache();
    if(lst.size()>0){
      channel.invokeMethod("lastCrashReport", lst.get(0));
    }
  }
  @Override
  public void onDetachedFromActivityForConfigChanges(){
    stopFrameMonitoring();
  }

  @Override
  public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding){
    startFrameMonitoring();
  }

  @Override
  public void onDetachedFromActivity(){
    stopFrameMonitoring();
    if (anrTracker != null) {
      anrTracker.interrupt();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  // test
  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {

    if (call.method != null) {
      switch (call.method) {
        case "initRefreshRate":
          this.lastFrameTimeNanos=0;
          this.count =0;
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
              List<String> exitInfo;
              try {
                exitInfo = getExitInfo();
              } catch (JSONException e) {
                result.success(null);
                break;
              }
              result.success(exitInfo);
            }
            else{
              result.success(null);
            }
            break;
        case "getANRStatus":
          List<String> lst = ANRTracker.getANRStatus();
          ANRTracker.resetANR();
          result.success(lst);
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
    List<ApplicationExitInfo> exitInfos = ExitInfoHelper.getApplicationExitInfo(context);
    List<String> infoList = new ArrayList<>();

    if (exitInfos != null) {
      for (ApplicationExitInfo exitInfo : exitInfos) {
        JSONObject info = ExitInfoHelper.getExitInfo(exitInfo);
        if(info != null && info.length() > 0){
          String infoString = info.toString();
          infoList.add(infoString);
        }
      }
      return infoList;
    }
    return null;
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
      this.slowFrames++;
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
      return  SystemClock.elapsedRealtime() - Process.getStartElapsedRealtime();
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
    Object slowFrame = this.slowFrames;
    // Handle the frozen frame event, e.g., log, send an event to Dart, etc.
    channel.invokeMethod("onSlowFrames", slowFrame);
    this.slowFrames = 0;
  }

  private void handleRefreshRate() {
    Object refreshRates = this.refreshRate;
    // Handle the frozen frame event, e.g., log, send an event to Dart, etc.
    channel.invokeMethod("onRefreshRate", refreshRates);
    this.refreshRate = 0.0;
  }
}
