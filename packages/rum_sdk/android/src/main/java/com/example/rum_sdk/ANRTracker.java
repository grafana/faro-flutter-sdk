package com.example.rum_sdk;

import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;

import androidx.annotation.Nullable;

import org.json.JSONException;
import org.json.JSONObject;

import java.lang.Exception;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;

import io.flutter.Log;



public class ANRTracker extends Thread {


        private final long TIMEOUT = 5000L; // Time interval for checking ANR, in milliseconds
        private @Nullable static List<String> ANRs;
        private final Handler handler = new Handler(Looper.getMainLooper());
        private final Thread mainThread =  Looper.getMainLooper().getThread();
        private final Runnable worker = () -> {
        };

        public static List<String> getANRStatus(){
                return ANRs;
        }
        public static void  resetANR(){
                ANRs=null;
        }

        @Override
        public void run() {
                while (!isInterrupted()) {
                        handler.postAtFrontOfQueue(worker);

                        try {
                                sleep(TIMEOUT); // Wait for the specified interval
                        } catch (InterruptedException e) {
                                e.printStackTrace();
                        }

                        if (handler.hasMessages(0)) {
                                // Worker has not finished running, so the UI thread is being held
                                StackTraceElement[] stackTrace = mainThread.getStackTrace();
                                StringBuilder output = new StringBuilder();
                                for (StackTraceElement element : stackTrace) {
                                        output.append(element.getClassName())
                                                .append(" ")
                                                .append(element.getMethodName())
                                                .append(" ")
                                                .append(element.getLineNumber())
                                                .append("\n");
                                }
                                JSONObject jsonObject = new JSONObject();
                                try {
                                        jsonObject.put("stacktrace", Arrays.toString(stackTrace));
                                        jsonObject.put("value", "ANR");
                                } catch (JSONException e) {
                                        e.printStackTrace();
                                }
                                RumCache rumCache = new RumCache();
                                rumCache.writeToCache(jsonObject.toString());
                                if(ANRs == null){
                                        ANRs = new ArrayList<String>();
                                }
                                ANRs.add(String.valueOf(output));
                        }
                }
        }

}
