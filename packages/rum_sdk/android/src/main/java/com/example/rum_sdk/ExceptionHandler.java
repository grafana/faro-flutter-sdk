package com.example.rum_sdk;

import android.os.StrictMode;

import androidx.annotation.NonNull;

import org.json.JSONObject;

import java.lang.Thread.UncaughtExceptionHandler;
import java.util.Arrays;

import io.flutter.Log;

/**
 * Provides automatic notification hooks for unhandled exceptions.
 */
class ExceptionHandler implements UncaughtExceptionHandler {



    private final UncaughtExceptionHandler originalHandler;

    ExceptionHandler() {
        this.originalHandler = Thread.getDefaultUncaughtExceptionHandler();
    }

    void install() {
        Thread.setDefaultUncaughtExceptionHandler(this);
    }

    void uninstall() {
        Thread.setDefaultUncaughtExceptionHandler(originalHandler);
    }

    @Override
    public void uncaughtException(@NonNull Thread thread, @NonNull Throwable throwable) {
        try {
            JSONObject jsonObject = new JSONObject();
            jsonObject.put("stacktrace", Arrays.toString(throwable.getStackTrace()));
            jsonObject.put("value", throwable.getMessage());
            StrictMode.ThreadPolicy originalThreadPolicy = StrictMode.getThreadPolicy();
            StrictMode.setThreadPolicy(StrictMode.ThreadPolicy.LAX);
            RumCache rumCache = new RumCache();
            rumCache.writeToCache(jsonObject.toString());
            StrictMode.setThreadPolicy(originalThreadPolicy);
        } catch (Throwable ignored) {
            //  avoid possible unhandled-exception loops
        } finally {
            forwardToOriginalHandler(thread, throwable);
        }
    }

    private void forwardToOriginalHandler(@NonNull Thread thread, @NonNull Throwable throwable) {
        // Pass exception on to original exception handler
        if (originalHandler != null) {
            originalHandler.uncaughtException(thread, throwable);
        } else {
            System.err.printf("Exception in thread \"%s\" ", thread.getName());
        }
    }
}