package com.grafana.faro_example;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;

import android.app.Activity;
import android.content.Context;

import androidx.annotation.Nullable;
import androidx.test.core.app.ActivityScenario;
import androidx.test.core.app.ApplicationProvider;
import androidx.test.ext.junit.runners.AndroidJUnit4;
import androidx.test.platform.app.InstrumentationRegistry;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;

import io.flutter.FlutterInjector;
import io.flutter.embedding.android.ExclusiveAppComponent;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.MethodChannel;

@RunWith(AndroidJUnit4.class)
public final class SecondaryEngineSessionTest {
    private static final String REPORT_CHANNEL = "faro_example/session_engine_harness";
    private static final long ENGINE_START_TIMEOUT_SECONDS = 45;

    private final List<EngineHandle> engines = new ArrayList<>();
    private Context context;
    private File sessionDirectory;

    @Before
    public void setUp() {
        context = ApplicationProvider.getApplicationContext();
        sessionDirectory = new File(context.getFilesDir(), "faro/sessions");
        deleteRecursively(sessionDirectory);
    }

    @After
    public void tearDown() {
        for (int index = engines.size() - 1; index >= 0; index--) {
            destroyEngine(engines.get(index));
        }
        engines.clear();
        deleteRecursively(sessionDirectory);
    }

    @Test
    public void secondaryEngineCannotMutateTheDurableSessionChain() throws Exception {
        try (ActivityScenario<SessionEngineHarnessActivity> scenario =
                 ActivityScenario.launch(SessionEngineHarnessActivity.class)) {
            AtomicReference<SessionEngineHarnessActivity> activity = new AtomicReference<>();
            scenario.onActivity(activity::set);

            EngineHandle owner = startEngine("owner", activity.get());
            EngineHandle secondary = startEngine("secondary", null);

            assertTrue(owner.report.ownsSessionPersistence);
            assertEquals("main", owner.report.engineRole);
            assertEquals("main", owner.report.isolateName);
            assertNull(owner.report.previousSession);

            assertFalse(secondary.report.ownsSessionPersistence);
            assertEquals("headless", secondary.report.engineRole);
            assertEquals("headless", secondary.report.isolateName);
            assertNull(secondary.report.previousSession);
            assertEquals(owner.report.processName, secondary.report.processName);
            assertNotEquals(owner.report.sessionId, secondary.report.sessionId);
            assertTelemetryMatchesEngine(owner);
            assertTelemetryMatchesEngine(secondary);

            List<PersistedRecord> whileSecondaryIsRunning = readPersistedRecords();
            assertEquals(1, whileSecondaryIsRunning.size());
            assertEquals(owner.report.sessionId, whileSecondaryIsRunning.get(0).sessionId);
            assertNull(whileSecondaryIsRunning.get(0).previousSessionId);

            destroyEngine(owner);

            EngineHandle replacement = startEngine("replacement", null);
            assertTrue(replacement.report.ownsSessionPersistence);
            assertEquals("headless", replacement.report.engineRole);
            assertEquals("headless", replacement.report.isolateName);
            assertEquals(owner.report.processName, replacement.report.processName);
            assertEquals(owner.report.sessionId, replacement.report.previousSession);
            assertNotEquals(owner.report.sessionId, replacement.report.sessionId);
            assertNotEquals(secondary.report.sessionId, replacement.report.sessionId);
            assertTelemetryMatchesEngine(replacement);

            List<PersistedRecord> afterOwnershipTransfer = readPersistedRecords();
            assertEquals(2, afterOwnershipTransfer.size());
            assertEquals(owner.report.sessionId, afterOwnershipTransfer.get(0).sessionId);
            assertNull(afterOwnershipTransfer.get(0).previousSessionId);
            assertEquals(replacement.report.sessionId, afterOwnershipTransfer.get(1).sessionId);
            assertEquals(owner.report.sessionId, afterOwnershipTransfer.get(1).previousSessionId);

            Set<String> persistedSessionIds = new HashSet<>();
            for (PersistedRecord record : afterOwnershipTransfer) {
                assertTrue("duplicate persisted session", persistedSessionIds.add(record.sessionId));
            }
            assertFalse(persistedSessionIds.contains(secondary.report.sessionId));

            Map<String, Object> crashResult = reportRecoveredCrash(
                replacement,
                afterOwnershipTransfer,
                owner.report.sessionId,
                owner.report.processName
            );
            assertEquals(owner.report.sessionId, crashResult.get("payloadSessionId"));
            assertNull(crashResult.get("payloadPreviousSession"));
            assertEquals(owner.report.sessionId, crashResult.get("crashedSessionId"));
            assertEquals(Boolean.TRUE, crashResult.get("fatal"));
            assertEquals(replacement.report.sessionId, crashResult.get("liveSessionIdAfter"));
            assertEquals(1, ((Number) crashResult.get("crashPayloadCount")).intValue());
            assertNotEquals(secondary.report.sessionId, crashResult.get("payloadSessionId"));
            assertNotEquals(replacement.report.sessionId, crashResult.get("payloadSessionId"));

            System.out.println(
                "Faro session engine harness: process=" + owner.report.processName
                    + ", owner=" + owner.report.sessionId
                    + ", secondary=" + secondary.report.sessionId
                    + ", replacement=" + replacement.report.sessionId
                    + ", replacement.previous=" + replacement.report.previousSession
            );
        }
    }

    private static void assertTelemetryMatchesEngine(EngineHandle engine) {
        assertEquals(engine.report.sessionId, engine.report.telemetrySessionId);
        assertEquals(engine.report.previousSession, engine.report.telemetryPreviousSession);
        assertEquals(engine.report.processName, engine.report.telemetryProcessName);
        assertEquals(engine.report.isolateName, engine.report.telemetryIsolateName);
        assertEquals(engine.report.label, engine.report.telemetryProbeLabel);
        assertEquals(1, engine.report.telemetryProbeCount);
    }

    private EngineHandle startEngine(
        String label,
        @Nullable SessionEngineHarnessActivity activity
    ) throws InterruptedException {
        CountDownLatch reportReceived = new CountDownLatch(1);
        AtomicReference<FlutterEngine> engineReference = new AtomicReference<>();
        AtomicReference<EngineReport> reportReference = new AtomicReference<>();
        AtomicReference<MethodChannel> channelReference = new AtomicReference<>();
        AtomicReference<Throwable> startFailure = new AtomicReference<>();

        InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
            try {
                FlutterEngine engine = new FlutterEngine(context);
                engineReference.set(engine);
                if (activity != null) {
                    engine.getActivityControlSurface().attachToActivity(
                        new TestActivityComponent(activity),
                        activity.getLifecycle()
                    );
                }

                MethodChannel reportChannel = new MethodChannel(
                    engine.getDartExecutor().getBinaryMessenger(),
                    REPORT_CHANNEL
                );
                channelReference.set(reportChannel);
                reportChannel.setMethodCallHandler((call, result) -> {
                    if (!"report".equals(call.method) || !(call.arguments instanceof Map)) {
                        result.notImplemented();
                        return;
                    }
                    reportReference.set(EngineReport.from(call.arguments));
                    reportReceived.countDown();
                    result.success(null);
                });

                DartExecutor.DartEntrypoint entrypoint = new DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    "faroSessionEngineHarnessMain"
                );
                engine.getDartExecutor().executeDartEntrypoint(
                    entrypoint,
                    Collections.singletonList(label)
                );
            } catch (Throwable error) {
                startFailure.set(error);
                reportReceived.countDown();
            }
        });

        if (!reportReceived.await(ENGINE_START_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            fail("Timed out waiting for the " + label + " engine report");
        }
        if (startFailure.get() != null) {
            throw new AssertionError("Failed to start the " + label + " engine", startFailure.get());
        }

        FlutterEngine engine = engineReference.get();
        EngineReport report = reportReference.get();
        MethodChannel reportChannel = channelReference.get();
        assertNotNull(engine);
        assertNotNull(report);
        assertNotNull(reportChannel);
        if (report.error != null) {
            fail(label + " engine failed: " + report.error + "\n" + report.stackTrace);
        }

        EngineHandle handle = new EngineHandle(
            engine,
            reportChannel,
            activity != null,
            report
        );
        engines.add(handle);
        return handle;
    }

    @SuppressWarnings("unchecked")
    private Map<String, Object> reportRecoveredCrash(
        EngineHandle engine,
        List<PersistedRecord> records,
        String crashedSessionId,
        String processName
    ) throws InterruptedException {
        CountDownLatch resultReceived = new CountDownLatch(1);
        AtomicReference<Object> resultReference = new AtomicReference<>();
        AtomicReference<Throwable> errorReference = new AtomicReference<>();
        List<Map<String, Object>> encodedRecords = new ArrayList<>();
        for (PersistedRecord record : records) {
            encodedRecords.add(record.toMap());
        }
        Map<String, Object> arguments = new HashMap<>();
        arguments.put("recoveredSessions", encodedRecords);
        arguments.put("crashedSessionId", crashedSessionId);
        arguments.put("processName", processName);

        InstrumentationRegistry.getInstrumentation().runOnMainSync(() ->
            engine.reportChannel.invokeMethod(
                "reportRecoveredCrash",
                arguments,
                new MethodChannel.Result() {
                    @Override
                    public void success(@Nullable Object result) {
                        resultReference.set(result);
                        resultReceived.countDown();
                    }

                    @Override
                    public void error(
                        String code,
                        @Nullable String message,
                        @Nullable Object details
                    ) {
                        errorReference.set(
                            new AssertionError(code + ": " + message + " " + details)
                        );
                        resultReceived.countDown();
                    }

                    @Override
                    public void notImplemented() {
                        errorReference.set(
                            new AssertionError("Harness method not implemented")
                        );
                        resultReceived.countDown();
                    }
                }
            )
        );

        if (!resultReceived.await(ENGINE_START_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            fail("Timed out waiting for the recovered crash report");
        }
        if (errorReference.get() != null) {
            throw new AssertionError(
                "Failed to report recovered crash",
                errorReference.get()
            );
        }
        assertTrue(resultReference.get() instanceof Map);
        return (Map<String, Object>) resultReference.get();
    }

    private void destroyEngine(EngineHandle handle) {
        if (handle.destroyed) {
            return;
        }
        InstrumentationRegistry.getInstrumentation().runOnMainSync(() -> {
            if (handle.attachedToActivity) {
                handle.engine.getActivityControlSurface().detachFromActivity();
            }
            handle.engine.destroy();
        });
        handle.destroyed = true;
    }

    private List<PersistedRecord> readPersistedRecords() throws Exception {
        File[] files = sessionDirectory.listFiles(
            (directory, name) -> name.endsWith(".json")
        );
        assertNotNull("session directory was not created", files);
        assertEquals("expected one process-scoped session file", 1, files.length);

        StringBuilder contents = new StringBuilder();
        try (BufferedReader reader = new BufferedReader(
            new InputStreamReader(
                new FileInputStream(files[0]),
                StandardCharsets.UTF_8
            )
        )) {
            String line;
            while ((line = reader.readLine()) != null) {
                contents.append(line);
            }
        }

        JSONArray records = new JSONObject(contents.toString()).getJSONArray("records");
        List<PersistedRecord> decoded = new ArrayList<>();
        for (int index = 0; index < records.length(); index++) {
            JSONObject record = records.getJSONObject(index);
            decoded.add(new PersistedRecord(
                record.getString("currentSessionId"),
                record.isNull("previousSessionId")
                    ? null
                    : record.getString("previousSessionId"),
                record.getString("startedAt"),
                record.getString("lastActivityAt"),
                record.getBoolean("isSampled")
            ));
        }
        return decoded;
    }

    private static void deleteRecursively(File file) {
        if (!file.exists()) {
            return;
        }
        File[] children = file.listFiles();
        if (children != null) {
            for (File child : children) {
                deleteRecursively(child);
            }
        }
        assertTrue("failed to delete " + file, file.delete());
    }

    private static final class TestActivityComponent
        implements ExclusiveAppComponent<Activity> {
        private final Activity activity;

        private TestActivityComponent(Activity activity) {
            this.activity = activity;
        }

        @Override
        public void detachFromFlutterEngine() {}

        @Override
        public Activity getAppComponent() {
            return activity;
        }
    }

    private static final class EngineHandle {
        private final FlutterEngine engine;
        private final MethodChannel reportChannel;
        private final boolean attachedToActivity;
        private final EngineReport report;
        private boolean destroyed;

        private EngineHandle(
            FlutterEngine engine,
            MethodChannel reportChannel,
            boolean attachedToActivity,
            EngineReport report
        ) {
            this.engine = engine;
            this.reportChannel = reportChannel;
            this.attachedToActivity = attachedToActivity;
            this.report = report;
        }
    }

    private static final class EngineReport {
        private final String label;
        private final String sessionId;
        private final @Nullable String previousSession;
        private final String processName;
        private final String isolateName;
        private final boolean ownsSessionPersistence;
        private final String engineRole;
        private final String telemetrySessionId;
        private final @Nullable String telemetryPreviousSession;
        private final String telemetryProcessName;
        private final String telemetryIsolateName;
        private final String telemetryProbeLabel;
        private final int telemetryProbeCount;
        private final @Nullable String error;
        private final @Nullable String stackTrace;

        private EngineReport(
            String label,
            String sessionId,
            @Nullable String previousSession,
            String processName,
            String isolateName,
            boolean ownsSessionPersistence,
            String engineRole,
            String telemetrySessionId,
            @Nullable String telemetryPreviousSession,
            String telemetryProcessName,
            String telemetryIsolateName,
            String telemetryProbeLabel,
            int telemetryProbeCount,
            @Nullable String error,
            @Nullable String stackTrace
        ) {
            this.label = label;
            this.sessionId = sessionId;
            this.previousSession = previousSession;
            this.processName = processName;
            this.isolateName = isolateName;
            this.ownsSessionPersistence = ownsSessionPersistence;
            this.engineRole = engineRole;
            this.telemetrySessionId = telemetrySessionId;
            this.telemetryPreviousSession = telemetryPreviousSession;
            this.telemetryProcessName = telemetryProcessName;
            this.telemetryIsolateName = telemetryIsolateName;
            this.telemetryProbeLabel = telemetryProbeLabel;
            this.telemetryProbeCount = telemetryProbeCount;
            this.error = error;
            this.stackTrace = stackTrace;
        }

        @SuppressWarnings("unchecked")
        private static EngineReport from(Object arguments) {
            Map<String, Object> values = (Map<String, Object>) arguments;
            return new EngineReport(
                (String) values.get("label"),
                (String) values.get("sessionId"),
                (String) values.get("previousSession"),
                (String) values.get("processName"),
                (String) values.get("isolateName"),
                Boolean.TRUE.equals(values.get("ownsSessionPersistence")),
                (String) values.get("engineRole"),
                (String) values.get("telemetrySessionId"),
                (String) values.get("telemetryPreviousSession"),
                (String) values.get("telemetryProcessName"),
                (String) values.get("telemetryIsolateName"),
                (String) values.get("telemetryProbeLabel"),
                values.get("telemetryProbeCount") instanceof Number
                    ? ((Number) values.get("telemetryProbeCount")).intValue()
                    : 0,
                (String) values.get("error"),
                (String) values.get("stackTrace")
            );
        }
    }

    private static final class PersistedRecord {
        private final String sessionId;
        private final @Nullable String previousSessionId;
        private final String startedAt;
        private final String lastActivityAt;
        private final boolean isSampled;

        private PersistedRecord(
            String sessionId,
            @Nullable String previousSessionId,
            String startedAt,
            String lastActivityAt,
            boolean isSampled
        ) {
            this.sessionId = sessionId;
            this.previousSessionId = previousSessionId;
            this.startedAt = startedAt;
            this.lastActivityAt = lastActivityAt;
            this.isSampled = isSampled;
        }

        private Map<String, Object> toMap() {
            Map<String, Object> result = new HashMap<>();
            result.put("schemaVersion", 1);
            result.put("currentSessionId", sessionId);
            result.put("previousSessionId", previousSessionId);
            result.put("startedAt", startedAt);
            result.put("lastActivityAt", lastActivityAt);
            result.put("isSampled", isSampled);
            return result;
        }
    }
}
