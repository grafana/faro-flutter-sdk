package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class ProcessVitalsTest {
    // Fields 14-17 are utime=250, stime=150, cutime=4000, cstime=3000.
    private static final String STAT =
            "1234 (com.example.app) S 1 1234 0 0 -1 4194624 5000 0 0 0 250 150 4000 3000 "
                    + "20 0 30 0 12345 1000000 5000 18446744073709551615\n";

    @Test
    public void cpuTimeIsUserPlusSystemWithoutChildTime() {
        assertEquals(4.0, ProcessVitals.cpuTimeSeconds(STAT, 100), 0.0);
    }

    @Test
    public void cpuTimeKeepsFractionsOfASecond() {
        String stat = STAT.replace(" 250 150 ", " 3 2 ");
        assertEquals(0.05, ProcessVitals.cpuTimeSeconds(stat, 100), 1e-12);
    }

    @Test
    public void cpuTimeHandlesSpacesAndParenthesesInTheCommandName() {
        String stat = STAT.replace("(com.example.app)", "(my (odd) app)");
        assertEquals(4.0, ProcessVitals.cpuTimeSeconds(stat, 100), 0.0);
    }

    @Test
    public void cpuTimeIsNullForUnreadableInput() {
        assertNull(ProcessVitals.cpuTimeSeconds(null, 100));
        assertNull(ProcessVitals.cpuTimeSeconds("", 100));
        assertNull(ProcessVitals.cpuTimeSeconds("1234 (app) S 1 2", 100));
        assertNull(ProcessVitals.cpuTimeSeconds(STAT.replace(" 250 ", " x "), 100));
        assertNull(ProcessVitals.cpuTimeSeconds(STAT, 0));
    }

    @Test
    public void vmRssIsConvertedFromKibibytesToBytes() {
        String status = "Name:\tapp\nVmHWM:\t  300000 kB\nVmRSS:\t  217497 kB\nRssAnon:\t 100 kB\n";
        assertEquals(Long.valueOf(217497L * 1024L), ProcessVitals.vmRssBytes(status));
    }

    @Test
    public void vmRssIsNullWhenMissingOrZero() {
        assertNull(ProcessVitals.vmRssBytes(null));
        assertNull(ProcessVitals.vmRssBytes("Name:\tapp\nVmHWM:\t 1 kB\n"));
        assertNull(ProcessVitals.vmRssBytes("VmRSS:\t 0 kB\n"));
    }

    @Test
    public void memoryBasisIsRss() {
        assertEquals("rss", ProcessVitals.MEMORY_BASIS);
    }

    @Test
    public void cpuTimeUsesProcStatFromApi21AndElapsedCpuTimeBelow() {
        assertFalse(ProcessVitals.readsProcStat(19));
        assertFalse(ProcessVitals.readsProcStat(20));
        assertTrue(ProcessVitals.readsProcStat(21));
        assertTrue(ProcessVitals.readsProcStat(35));
    }

    @Test
    public void elapsedCpuTimeIsConvertedFromMillisecondsToSeconds() {
        assertEquals(1.234, ProcessVitals.elapsedCpuSeconds(1234L), 1e-12);
        assertEquals(0.0, ProcessVitals.elapsedCpuSeconds(0L), 0.0);
        assertNull(ProcessVitals.elapsedCpuSeconds(-1L));
    }

    @Test
    public void readAlwaysIncludesTheWallClockCaptureTime() {
        long before = System.currentTimeMillis();
        java.util.Map<String, Object> vitals = ProcessVitals.read(false, false);
        long after = System.currentTimeMillis();

        Object timestamp = vitals.get("timestampMillis");
        assertTrue(timestamp instanceof Long);
        assertTrue((Long) timestamp >= before && (Long) timestamp <= after);
        assertTrue(vitals.containsKey("monotonicNanos"));
        assertFalse(vitals.containsKey("cpuTimeSeconds"));
        assertFalse(vitals.containsKey("memoryBytes"));
    }
}
