package com.grafana.faro;

import androidx.annotation.NonNull;

/**
 * Formats main-thread stack traces for ANR reporting with bounded allocation.
 */
public final class AnrStackTraceFormatter {

    private AnrStackTraceFormatter() {}

    /** Result of {@link #buildBoundedStackTraceString}. */
    public static final class Result {
        public final @NonNull String text;
        public final boolean truncated;
        public final int includedFrames;

        public Result(@NonNull String text, boolean truncated, int includedFrames) {
            this.text = text;
            this.truncated = truncated;
            this.includedFrames = includedFrames;
        }
    }

    /**
     * Builds a stack trace string capped by {@code maxFrames} and {@code maxChars}
     * to limit peak allocation on ANR paths.
     */
    @NonNull
    public static Result buildBoundedStackTraceString(
            @NonNull StackTraceElement[] stackTrace, int maxFrames, int maxChars) {
        int total = stackTrace.length;
        if (total == 0) {
            return new Result("", false, 0);
        }

        StringBuilder sb = new StringBuilder(Math.min(total, maxFrames) * 80);
        int included = 0;
        boolean truncated = false;

        for (int i = 0; i < total && included < maxFrames; i++) {
            String line = formatStackFrameLine(stackTrace[i]);
            int nextLen = sb.length() + line.length();
            if (nextLen > maxChars) {
                truncated = true;
                break;
            }
            sb.append(line);
            included++;
        }

        if (included < total) {
            truncated = true;
        }

        if (truncated) {
            String note =
                    "... (truncated: "
                            + included
                            + " of "
                            + total
                            + " frames, maxFrames="
                            + maxFrames
                            + ", maxChars="
                            + maxChars
                            + ")\n";
            if (sb.length() + note.length() > maxChars) {
                sb.setLength(Math.max(0, maxChars - note.length()));
            }
            sb.append(note);
        }

        String out = sb.toString();
        if (out.length() > maxChars) {
            out = out.substring(0, maxChars);
        }
        return new Result(out, truncated, included);
    }

    @NonNull
    private static String formatStackFrameLine(@NonNull StackTraceElement element) {
        return element.getClassName()
                + "."
                + element.getMethodName()
                + "("
                + element.getFileName()
                + ":"
                + element.getLineNumber()
                + ")\n";
    }
}
