package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

/**
 * Unit tests for bounded ANR stack string building (#174).
 *
 * <p>TDD-style: these assert the caps that prevent unbounded allocation; if
 * {@link AnrStackTraceFormatter} regresses to dumping the full stack without
 * limits, the max-frames and max-chars cases fail.
 */
public class AnrStackTraceFormatterTest {

    @Test
    public void buildBoundedStackTraceString_empty_returnsEmpty() {
        AnrStackTraceFormatter.Result r =
                AnrStackTraceFormatter.buildBoundedStackTraceString(
                        new StackTraceElement[0], 128, 64 * 1024);
        assertEquals("", r.text);
        assertFalse(r.truncated);
        assertEquals(0, r.includedFrames);
    }

    @Test
    public void buildBoundedStackTraceString_smallStack_notTruncated() {
        StackTraceElement[] trace =
                new StackTraceElement[] {
                    new StackTraceElement("a.A", "m", "A.java", 1),
                    new StackTraceElement("b.B", "n", "B.java", 2),
                };
        AnrStackTraceFormatter.Result r =
                AnrStackTraceFormatter.buildBoundedStackTraceString(
                        trace, 128, 64 * 1024);
        assertFalse(r.truncated);
        assertEquals(2, r.includedFrames);
        assertTrue(r.text.contains("a.A.m"));
        assertTrue(r.text.contains("b.B.n"));
    }

    @Test
    public void buildBoundedStackTraceString_respectsMaxFrames() {
        StackTraceElement[] trace = new StackTraceElement[20];
        for (int i = 0; i < trace.length; i++) {
            trace[i] = new StackTraceElement("pkg.C", "run", "C.java", i);
        }
        AnrStackTraceFormatter.Result r =
                AnrStackTraceFormatter.buildBoundedStackTraceString(
                        trace, 5, 64 * 1024);
        assertTrue(r.truncated);
        assertEquals(5, r.includedFrames);
        assertTrue(r.text.contains("truncated"));
    }

    @Test
    public void buildBoundedStackTraceString_respectsMaxChars() {
        StackTraceElement[] trace =
                new StackTraceElement[] {
                    new StackTraceElement(
                            "very.long.package.name.ClassName",
                            "veryLongMethodName",
                            "VeryLongFileName.java",
                            999),
                };
        AnrStackTraceFormatter.Result r =
                AnrStackTraceFormatter.buildBoundedStackTraceString(
                        trace, 128, 40);
        assertTrue(r.truncated);
        assertEquals(0, r.includedFrames);
        assertTrue(r.text.contains("truncated"));
        assertTrue(
                "output must stay within maxChars to limit allocation",
                r.text.length() <= 40);
    }

    @Test
    public void buildBoundedStackTraceString_outputNeverExceedsMaxChars() {
        StackTraceElement[] trace = new StackTraceElement[200];
        for (int i = 0; i < trace.length; i++) {
            trace[i] =
                    new StackTraceElement(
                            "some.pkg.DeepClassNameNumber" + i,
                            "method" + i,
                            "SourceFile.java",
                            i);
        }
        int maxChars = 500;
        AnrStackTraceFormatter.Result r =
                AnrStackTraceFormatter.buildBoundedStackTraceString(
                        trace, 128, maxChars);
        assertTrue(
                "bounded formatter must not grow past maxChars",
                r.text.length() <= maxChars);
    }
}
