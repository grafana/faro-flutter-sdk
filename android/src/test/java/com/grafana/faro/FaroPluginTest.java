package com.grafana.faro;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class FaroPluginTest {
    @Test
    public void attachedActivityIdentifiesUiEngine() {
        assertEquals("ui", FaroPlugin.getEngineRole(true));
    }

    @Test
    public void missingActivityIdentifiesHeadlessEngine() {
        assertEquals("headless", FaroPlugin.getEngineRole(false));
    }
}
