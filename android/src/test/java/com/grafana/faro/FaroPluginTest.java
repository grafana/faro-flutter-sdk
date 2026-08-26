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
    public void crashRecoveryClaimDoesNotTakeSessionPersistenceOwnership() {
        FaroPlugin crashOwner = new FaroPlugin();
        FaroPlugin persistenceOwner = new FaroPlugin();

        try {
            assertTrue(crashOwner.claimCrashRecoveryOwnership());
            assertTrue(persistenceOwner.claimSessionPersistenceOwnership());
            assertFalse(crashOwner.claimSessionPersistenceOwnership());
        } finally {
            crashOwner.releaseCrashRecoveryOwnership();
            crashOwner.releaseSessionPersistenceOwnership();
            persistenceOwner.releaseCrashRecoveryOwnership();
            persistenceOwner.releaseSessionPersistenceOwnership();
        }
    }

    @Test
    public void persistenceOwnerExcludesSecondaryCrashRecovery() {
        FaroPlugin owner = new FaroPlugin();
        FaroPlugin secondary = new FaroPlugin();

        try {
            assertTrue(owner.claimSessionPersistenceOwnership());
            assertTrue(owner.claimCrashRecoveryOwnership());
            assertFalse(secondary.claimCrashRecoveryOwnership());
        } finally {
            owner.releaseCrashRecoveryOwnership();
            owner.releaseSessionPersistenceOwnership();
            secondary.releaseCrashRecoveryOwnership();
            secondary.releaseSessionPersistenceOwnership();
        }
    }
}
