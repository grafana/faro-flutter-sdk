package com.grafana.faro;

import static org.junit.Assert.assertEquals;

import org.junit.Test;

public class FaroPluginTest {
    @Test
    public void engineRoleTracksActivityAttachment() {
        FaroPlugin.EngineRoleTracker tracker = new FaroPlugin.EngineRoleTracker();

        assertEquals("headless", tracker.getEngineRole());

        tracker.onActivityAttached();
        assertEquals("main", tracker.getEngineRole());

        tracker.onActivityDetached();
        assertEquals("main", tracker.getEngineRole());
    }
}
