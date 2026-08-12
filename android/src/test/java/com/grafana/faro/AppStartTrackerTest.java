package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

import java.util.Map;

public class AppStartTrackerTest {

    // --- resolveUserVisible tests ---
    //
    // Only a launch that was already foreground when the process came up should
    // count as a cold start. Anything else means Android forked the process for
    // background work, and the time since then says nothing about how long
    // anyone waited.

    private static final int API_MARSHMALLOW = 23;
    private static final int API_NOUGAT = 24;
    private static final int API_R = 30;
    private static final int API_VANILLA_ICE_CREAM = 35;

    @Test
    public void resolveUserVisible_neverReportsBelowApi24() {
        // Nothing to measure from: there is no process start time.
        assertFalse(AppStartTracker.resolveUserVisible(API_MARSHMALLOW, true));
        assertFalse(AppStartTracker.resolveUserVisible(API_MARSHMALLOW, false));
    }

    @Test
    public void resolveUserVisible_reportsAForegroundStart() {
        assertTrue(AppStartTracker.resolveUserVisible(API_NOUGAT, true));
        assertTrue(AppStartTracker.resolveUserVisible(API_R, true));
        assertTrue(AppStartTracker.resolveUserVisible(API_VANILLA_ICE_CREAM, true));
    }

    @Test
    public void resolveUserVisible_rejectsABackgroundStart() {
        assertFalse(AppStartTracker.resolveUserVisible(API_NOUGAT, false));
        assertFalse(AppStartTracker.resolveUserVisible(API_R, false));
        assertFalse(AppStartTracker.resolveUserVisible(API_VANILLA_ICE_CREAM, false));
    }

    // --- getColdStartMetrics tests ---
    //
    // The Dart side looks these keys up by name and returns early when one is
    // missing or holds the wrong type, without logging. A rename on either side
    // therefore stops cold start reporting silently.

    @Test
    public void getColdStartMetrics_usesTheKeysTheDartSideReads() {
        final Map<String, Object> metrics = AppStartTracker.getColdStartMetrics();

        assertTrue(metrics.get("appStartDurationMillis") instanceof Long);
        assertTrue(metrics.get("isUserVisibleColdStart") instanceof Boolean);
        assertEquals(Boolean.FALSE, metrics.get("prewarmed"));
    }
}
