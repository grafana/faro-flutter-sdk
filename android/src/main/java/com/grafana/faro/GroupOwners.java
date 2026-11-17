package com.grafana.faro;

import androidx.annotation.NonNull;

import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

/**
 * Tracks which owner (one per Flutter engine) wants which groups. A group runs while at least
 * one owner wants it, so the last owner to leave stops it.
 */
final class GroupOwners {
    /** The groups that began or ended running after a change. */
    static final class Change {
        final Set<String> started;
        final Set<String> stopped;

        Change(@NonNull Set<String> started, @NonNull Set<String> stopped) {
            this.started = started;
            this.stopped = stopped;
        }

        boolean isEmpty() {
            return started.isEmpty() && stopped.isEmpty();
        }
    }

    private final Map<Object, Set<String>> groupsByOwner = new HashMap<>();

    /** Replaces the groups {@code owner} wants. */
    synchronized Change set(@NonNull Object owner, @NonNull Collection<String> groups) {
        Set<String> before = running();
        if (groups.isEmpty()) {
            groupsByOwner.remove(owner);
        } else {
            groupsByOwner.put(owner, new HashSet<>(groups));
        }
        return changeFrom(before);
    }

    /** Removes {@code owner}, which wants no group any more. */
    synchronized Change release(@NonNull Object owner) {
        Set<String> before = running();
        groupsByOwner.remove(owner);
        return changeFrom(before);
    }

    /** The groups at least one owner wants. */
    synchronized Set<String> running() {
        Set<String> running = new HashSet<>();
        for (Set<String> groups : groupsByOwner.values()) {
            running.addAll(groups);
        }
        return running;
    }

    private Change changeFrom(Set<String> before) {
        Set<String> after = running();
        Set<String> started = new HashSet<>(after);
        started.removeAll(before);
        Set<String> stopped = new HashSet<>(before);
        stopped.removeAll(after);
        return new Change(started, stopped);
    }
}
