package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class FaroPluginTest {
    @Test
    public void engineRoleTracksActivityAttachment() {
        FaroPlugin.EngineRoleTracker tracker = new FaroPlugin.EngineRoleTracker();

        assertEquals("headless", tracker.getEngineRole());

        tracker.onActivityAttached();
        assertEquals("main", tracker.getEngineRole());
    }

    @Test
    public void crashRecoveryRequiresSessionPersistenceOwnership() {
        FaroPlugin unidentifiedEngine = new FaroPlugin();
        FaroPlugin persistenceOwner = new FaroPlugin();

        try {
            assertFalse(unidentifiedEngine.canRecoverCrashReports());
            assertTrue(persistenceOwner.claimSessionPersistenceOwnership());
            assertTrue(persistenceOwner.canRecoverCrashReports());
            assertFalse(unidentifiedEngine.canRecoverCrashReports());
        } finally {
            unidentifiedEngine.releaseSessionPersistenceOwnership();
            persistenceOwner.releaseSessionPersistenceOwnership();
        }
    }

    @Test
    public void crashRecoveryTransfersWithSessionPersistenceOwnership() {
        FaroPlugin firstOwner = new FaroPlugin();
        FaroPlugin replacement = new FaroPlugin();

        try {
            assertTrue(firstOwner.claimSessionPersistenceOwnership());
            assertTrue(firstOwner.canRecoverCrashReports());
            assertFalse(replacement.claimSessionPersistenceOwnership());
            assertFalse(replacement.canRecoverCrashReports());

            firstOwner.releaseSessionPersistenceOwnership();

            assertTrue(replacement.claimSessionPersistenceOwnership());
            assertTrue(replacement.canRecoverCrashReports());
            assertFalse(firstOwner.canRecoverCrashReports());
        } finally {
            firstOwner.releaseSessionPersistenceOwnership();
            replacement.releaseSessionPersistenceOwnership();
        }
    }
}
