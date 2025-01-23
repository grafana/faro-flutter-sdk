package com.example.rum_sdk;

import android.content.Context;
import android.content.SharedPreferences;

import java.util.HashSet;
import java.util.Set;

public class SharedPreferencesService {
    private static final String PREFS_NAME = "rum_sdk_lib_prefs";
    private static final String HANDLED_EXIT_INFO_KEY = "handled_exit_info";
    private final SharedPreferences prefs;

    public SharedPreferencesService(Context context) {
        this.prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    public Set<String> getHandledExitInfos() {
        return new HashSet<>(prefs.getStringSet(HANDLED_EXIT_INFO_KEY, new HashSet<>()));
    }

    public void setHandledExitInfos(Set<String> handledExitInfos) {
        prefs.edit().putStringSet(HANDLED_EXIT_INFO_KEY, new HashSet<>(handledExitInfos)).apply();
    }
}