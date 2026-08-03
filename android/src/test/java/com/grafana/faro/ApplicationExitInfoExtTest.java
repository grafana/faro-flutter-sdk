package com.grafana.faro;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import android.app.ActivityManager;
import android.app.ApplicationExitInfo;

import org.junit.Test;

public class ApplicationExitInfoExtTest {
    private static final int SIGKILL = 9;

    @Test
    public void lowMemory_serviceExitIsFiltered() {
        assertTrue(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_LOW_MEMORY,
                0,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_SERVICE));
    }

    @Test
    public void lowMemory_cachedSigkillIsFiltered() {
        assertTrue(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_LOW_MEMORY,
                SIGKILL,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED));
    }

    @Test
    public void lowMemory_foregroundServiceExitIsReported() {
        assertFalse(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_LOW_MEMORY,
                0,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND_SERVICE));
    }

    @Test
    public void lowMemory_perceptibleExitIsReported() {
        assertFalse(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_LOW_MEMORY,
                0,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_PERCEPTIBLE));
    }

    @Test
    public void excessiveResourceUsageFilteringRemainsUnchanged() {
        assertTrue(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
                0,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED));
        assertFalse(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE,
                SIGKILL,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED));
    }

    @Test
    public void crashIsNotFiltered() {
        assertFalse(ApplicationExitInfoExt.shouldBeFilteredOut(
                ApplicationExitInfo.REASON_CRASH,
                0,
                ActivityManager.RunningAppProcessInfo.IMPORTANCE_CACHED));
    }
}
