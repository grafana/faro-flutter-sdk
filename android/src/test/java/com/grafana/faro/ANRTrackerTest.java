package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.After;
import org.junit.Test;

public class ANRTrackerTest {

    @After
    public void tearDown() {
        ANRTracker.resetANR();
    }

    // --- buildStackTraceString tests ---

    @Test
    public void buildStackTraceString_capsOutputToMaxFrames() {
        int totalFrames = 200;
        int maxFrames = 50;
        StackTraceElement[] elements = createFakeStackTrace(totalFrames);

        String result = ANRTracker.buildStackTraceString(
                elements, maxFrames);

        int lineCount = countLines(result);
        assertTrue(
                "Expected at most " + (maxFrames + 1)
                        + " lines (frames + truncation notice), but got "
                        + lineCount,
                lineCount <= maxFrames + 1);
    }

    @Test
    public void buildStackTraceString_includesAllFramesWhenBelowMax() {
        int totalFrames = 10;
        StackTraceElement[] elements = createFakeStackTrace(totalFrames);

        String result = ANRTracker.buildStackTraceString(
                elements, ANRTracker.MAX_STACK_FRAMES);

        int lineCount = countLines(result);
        assertEquals(totalFrames, lineCount);
    }

    @Test
    public void buildStackTraceString_indicatesTruncation() {
        int totalFrames = 100;
        int maxFrames = 20;
        StackTraceElement[] elements = createFakeStackTrace(totalFrames);

        String result = ANRTracker.buildStackTraceString(
                elements, maxFrames);

        assertTrue(
                "Should indicate frames were truncated",
                result.contains("more frames truncated"));
    }

    @Test
    public void buildStackTraceString_emptyInput() {
        StackTraceElement[] elements = new StackTraceElement[0];

        String result = ANRTracker.buildStackTraceString(
                elements, ANRTracker.MAX_STACK_FRAMES);

        assertEquals("", result);
    }

    @Test
    public void buildStackTraceString_formatsFrameCorrectly() {
        StackTraceElement[] elements = new StackTraceElement[]{
                new StackTraceElement(
                        "com.example.MyClass", "myMethod",
                        "MyClass.java", 42)
        };

        String result = ANRTracker.buildStackTraceString(elements, 10);

        assertEquals(
                "com.example.MyClass.myMethod(MyClass.java:42)\n",
                result);
    }

    // --- anrList bounding tests ---

    @Test
    public void getANRStatus_returnsNullWhenEmpty() {
        assertNull(ANRTracker.getANRStatus());
    }

    // --- helpers ---

    private static StackTraceElement[] createFakeStackTrace(int size) {
        StackTraceElement[] elements = new StackTraceElement[size];
        for (int i = 0; i < size; i++) {
            elements[i] = new StackTraceElement(
                    "com.example.pkg.Class" + i,
                    "method" + i,
                    "Class" + i + ".java",
                    i + 1);
        }
        return elements;
    }

    private static int countLines(String s) {
        if (s == null || s.isEmpty()) {
            return 0;
        }
        return s.split("\n", -1).length - (s.endsWith("\n") ? 1 : 0);
    }
}
