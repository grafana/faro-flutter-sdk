package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;

import org.junit.Test;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.StandardMethodCodec;

public class FaroPluginTest {
    @Test
    public void firstFrameIsOnlyABaselineWithoutChangingFiveFrameLimit() throws Exception {
        RecordingMessenger messenger = new RecordingMessenger();
        FaroPlugin plugin = monitoringPlugin(messenger);
        Method checkFrameDuration = frameMethod();

        checkFrameDuration.invoke(plugin, 1_000_000_000L);
        assertTrue(messenger.calls.isEmpty());

        checkFrameDuration.invoke(plugin, 1_016_000_000L);
        checkFrameDuration.invoke(plugin, 1_032_000_000L);
        checkFrameDuration.invoke(plugin, 1_132_000_001L);
        checkFrameDuration.invoke(plugin, 1_148_000_001L);

        assertEquals(4, messenger.count("onRefreshRate"));
        assertEquals(1, messenger.count("onSlowFrames"));
        assertEquals(1, messenger.count("onFrozenFrame"));
    }

    @Test
    public void nonIncreasingFrameTimestampDoesNotEmitInvalidRate() throws Exception {
        RecordingMessenger messenger = new RecordingMessenger();
        FaroPlugin plugin = monitoringPlugin(messenger);
        Method checkFrameDuration = frameMethod();

        checkFrameDuration.invoke(plugin, 1_000_000_000L);
        checkFrameDuration.invoke(plugin, 1_000_000_000L);
        checkFrameDuration.invoke(plugin, 999_000_000L);
        assertTrue(messenger.calls.isEmpty());

        checkFrameDuration.invoke(plugin, 1_016_000_000L);
        assertEquals(1, messenger.count("onRefreshRate"));
        assertEquals(0, messenger.count("onSlowFrames"));
    }

    @Test
    public void eachFrameWindowStopsAfterFiveCallbacks() throws Exception {
        RecordingMessenger messenger = new RecordingMessenger();
        FaroPlugin plugin = monitoringPlugin(messenger);
        Method checkFrameDuration = frameMethod();

        for (int frame = 0; frame < 5; frame++) {
            checkFrameDuration.invoke(plugin, 1_000_000_000L + frame * 16_000_000L);
        }

        Field running = FaroPlugin.class.getDeclaredField("isFrameMonitoringRunning");
        running.setAccessible(true);
        assertFalse(running.getBoolean(plugin));
        Field count = FaroPlugin.class.getDeclaredField("count");
        count.setAccessible(true);
        assertEquals(0, count.getInt(plugin));
        assertEquals(4, messenger.count("onRefreshRate"));

        checkFrameDuration.invoke(plugin, 1_100_000_000L);
        assertEquals(4, messenger.count("onRefreshRate"));

        // The JVM Android stub cannot schedule a Choreographer callback. Simulate
        // startFrameMonitoring after the next visible-app polling call.
        running.setBoolean(plugin, true);
        for (int frame = 0; frame < 5; frame++) {
            checkFrameDuration.invoke(plugin, 2_000_000_000L + frame * 16_000_000L);
        }

        assertFalse(running.getBoolean(plugin));
        assertEquals(0, count.getInt(plugin));
        assertEquals(8, messenger.count("onRefreshRate"));
    }

    @Test
    public void headlessPeriodicInitDoesNotStartFrameMonitoring() throws Exception {
        FaroPlugin plugin = new FaroPlugin();
        final boolean[] succeeded = {false};
        plugin.onMethodCall(new MethodCall("initRefreshRate", null), new MethodChannel.Result() {
            @Override
            public void success(Object result) {
                succeeded[0] = true;
            }

            @Override
            public void error(String code, String message, Object details) {}

            @Override
            public void notImplemented() {}
        });

        assertTrue(succeeded[0]);
        Field running = FaroPlugin.class.getDeclaredField("isFrameMonitoringRunning");
        running.setAccessible(true);
        assertFalse(running.getBoolean(plugin));
    }

    @Test
    public void periodicInitDoesNotExtendAnActiveFrameWindow() throws Exception {
        FaroPlugin plugin = monitoringPlugin(new RecordingMessenger());
        Field resumed = FaroPlugin.class.getDeclaredField("isActivityResumed");
        resumed.setAccessible(true);
        resumed.setBoolean(plugin, true);
        Field count = FaroPlugin.class.getDeclaredField("count");
        count.setAccessible(true);
        count.setInt(plugin, 3);

        plugin.onMethodCall(new MethodCall("initRefreshRate", null), new MethodChannel.Result() {
            @Override
            public void success(Object result) {}

            @Override
            public void error(String code, String message, Object details) {
                throw new AssertionError(message);
            }

            @Override
            public void notImplemented() {
                throw new AssertionError("initRefreshRate was not handled");
            }
        });

        assertEquals(3, count.getInt(plugin));
    }

    @Test
    public void engineDetachStopsFrameMonitoring() throws Exception {
        FaroPlugin plugin = monitoringPlugin(new RecordingMessenger());
        Field running = FaroPlugin.class.getDeclaredField("isFrameMonitoringRunning");
        running.setAccessible(true);

        plugin.onDetachedFromEngine(null);

        assertFalse(running.getBoolean(plugin));
    }

    private static FaroPlugin monitoringPlugin(RecordingMessenger messenger) throws Exception {
        FaroPlugin plugin = new FaroPlugin();
        Field channel = FaroPlugin.class.getDeclaredField("channel");
        channel.setAccessible(true);
        channel.set(plugin, new MethodChannel(messenger, "faro"));
        Field running = FaroPlugin.class.getDeclaredField("isFrameMonitoringRunning");
        running.setAccessible(true);
        running.setBoolean(plugin, true);
        return plugin;
    }

    private static Method frameMethod() throws Exception {
        Method method = FaroPlugin.class.getDeclaredMethod("checkFrameDuration", long.class);
        method.setAccessible(true);
        return method;
    }

    private static final class RecordingMessenger implements BinaryMessenger {
        final List<MethodCall> calls = new ArrayList<>();

        @Override
        public void send(String channel, ByteBuffer message) {
            ByteBuffer copy = message.duplicate();
            copy.flip();
            calls.add(StandardMethodCodec.INSTANCE.decodeMethodCall(copy));
        }

        @Override
        public void send(String channel, ByteBuffer message, BinaryReply callback) {
            send(channel, message);
        }

        @Override
        public void setMessageHandler(String channel, BinaryMessageHandler handler) {}

        int count(String method) {
            int matching = 0;
            for (MethodCall call : calls) {
                if (call.method.equals(method)) {
                    matching++;
                }
            }
            return matching;
        }
    }

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
