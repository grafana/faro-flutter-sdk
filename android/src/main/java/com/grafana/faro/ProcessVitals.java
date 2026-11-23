package com.grafana.faro;

import android.os.Build;
import android.os.SystemClock;
import android.system.Os;
import android.system.OsConstants;

import androidx.annotation.Nullable;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads raw app process counters for the Dart CPU and memory sampler.
 *
 * <p>Only reads counters. Windows, the CPU formula and the cadence live in
 * Dart. Reads touch {@code /proc}, so call {@link #read} off the main thread.
 */
final class ProcessVitals {
    static final String MEMORY_BASIS = "rss";

    private static final String STAT_PATH = "/proc/self/stat";
    private static final String STATUS_PATH = "/proc/self/status";
    private static final Pattern VM_RSS = Pattern.compile("^VmRSS:\\s+(\\d+)\\s+kB", Pattern.MULTILINE);

    // Fields after the parenthesised command name in /proc/<pid>/stat start at
    // field 3 (state). utime and stime are fields 14 and 15.
    private static final int UTIME_INDEX_AFTER_COMM = 14 - 3;
    private static final int STIME_INDEX_AFTER_COMM = 15 - 3;

    private ProcessVitals() {}

    /**
     * Returns {@code monotonicNanos}, {@code timestampMillis} and, when
     * requested and readable, CPU and memory counters. A counter that cannot
     * be read is left out.
     */
    static Map<String, Object> read(boolean cpu, boolean memory) {
        Map<String, Object> result = new HashMap<>();
        if (cpu) {
            Double cpuTimeSeconds = readsProcStat(Build.VERSION.SDK_INT)
                    ? cpuTimeSeconds(readFile(STAT_PATH), Os.sysconf(OsConstants._SC_CLK_TCK))
                    : elapsedCpuSeconds(android.os.Process.getElapsedCpuTime());
            if (cpuTimeSeconds != null) {
                result.put("cpuTimeSeconds", cpuTimeSeconds);
                result.put("cpuCount", Runtime.getRuntime().availableProcessors());
            }
        }
        if (memory) {
            Long memoryBytes = vmRssBytes(readFile(STATUS_PATH));
            if (memoryBytes != null) {
                result.put("memoryBytes", memoryBytes);
                result.put("memoryBasis", MEMORY_BASIS);
            }
        }
        result.put("monotonicNanos", SystemClock.elapsedRealtimeNanos());
        result.put("timestampMillis", System.currentTimeMillis());
        return result;
    }

    /**
     * Whether CPU time comes from {@code /proc/self/stat}. Below API 21
     * {@code Os.sysconf} is missing, so the clock tick rate is unknown and
     * {@link android.os.Process#getElapsedCpuTime()} is used instead.
     */
    static boolean readsProcStat(int sdkInt) {
        return sdkInt >= Build.VERSION_CODES.LOLLIPOP;
    }

    /**
     * Process CPU time from {@link android.os.Process#getElapsedCpuTime()},
     * which has millisecond precision and no child time, in seconds.
     */
    @Nullable
    static Double elapsedCpuSeconds(long elapsedCpuMillis) {
        return elapsedCpuMillis >= 0 ? elapsedCpuMillis / 1000.0 : null;
    }

    /**
     * User plus system CPU time from a {@code /proc/<pid>/stat} line, in
     * seconds. Child time ({@code cutime}, {@code cstime}) is not included.
     */
    @Nullable
    static Double cpuTimeSeconds(@Nullable String statLine, long clockTicksPerSecond) {
        if (statLine == null || clockTicksPerSecond <= 0) {
            return null;
        }
        // The command name can contain spaces and parentheses; it ends at the
        // last ')'.
        int commEnd = statLine.lastIndexOf(')');
        if (commEnd < 0 || commEnd + 2 > statLine.length()) {
            return null;
        }
        String[] fields = statLine.substring(commEnd + 2).trim().split("\\s+");
        if (fields.length <= STIME_INDEX_AFTER_COMM) {
            return null;
        }
        try {
            long utime = Long.parseLong(fields[UTIME_INDEX_AFTER_COMM]);
            long stime = Long.parseLong(fields[STIME_INDEX_AFTER_COMM]);
            if (utime < 0 || stime < 0) {
                return null;
            }
            return (utime + stime) / (double) clockTicksPerSecond;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    /** Resident set size from {@code /proc/<pid>/status}, in bytes. */
    @Nullable
    static Long vmRssBytes(@Nullable String status) {
        if (status == null) {
            return null;
        }
        Matcher matcher = VM_RSS.matcher(status);
        if (!matcher.find()) {
            return null;
        }
        try {
            long kibibytes = Long.parseLong(matcher.group(1));
            return kibibytes > 0 ? kibibytes * 1024L : null;
        } catch (NumberFormatException e) {
            return null;
        }
    }

    @Nullable
    private static String readFile(String path) {
        try (BufferedReader reader = new BufferedReader(new FileReader(path))) {
            StringBuilder builder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                builder.append(line).append('\n');
            }
            return builder.toString();
        } catch (IOException | SecurityException e) {
            return null;
        }
    }
}
