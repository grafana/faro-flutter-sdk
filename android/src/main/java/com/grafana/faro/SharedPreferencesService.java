package com.grafana.faro;

import android.content.Context;
import android.content.SharedPreferences;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;
import java.util.concurrent.locks.ReadWriteLock;
import java.util.concurrent.locks.ReentrantReadWriteLock;

/**
 * Service for managing shared preferences related to the SDK.
 * This class provides thread-safe access to shared preferences for storing
 * and retrieving application exit information.
 */
public class SharedPreferencesService {
    private static final String TAG = "SharedPreferencesService";
    private static final String PREFS_NAME = "faro_lib_prefs";
    private static final String HANDLED_EXIT_INFO_KEY = "handled_exit_info";
    
    private final SharedPreferences sharedPreferences;
    private final ReadWriteLock lock = new ReentrantReadWriteLock();

    /**
     * Constructor for SharedPreferencesService
     * @param context Application context used to access SharedPreferences
     */
    public SharedPreferencesService(@NonNull Context context) {
        this.sharedPreferences = context.getApplicationContext()
                .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
    }

    /**
     * Get the set of handled exit information IDs
     * @return Set of handled exit information IDs, empty set if none found
     */
    @NonNull
    public Set<String> getHandledExitInfos() {
        lock.readLock().lock();
        try {
            Set<String> result = sharedPreferences.getStringSet(HANDLED_EXIT_INFO_KEY, null);
            return result != null ? new HashSet<>(result) : new HashSet<>();
        } catch (Exception e) {
            Log.e(TAG, "Error retrieving handled exit infos", e);
            return new HashSet<>();
        } finally {
            lock.readLock().unlock();
        }
    }

    /**
     * Set the handled exit information IDs
     * @param handledExitInfos Set of exit information IDs to store
     * @return true if the operation was successful, false otherwise
     */
    public boolean setHandledExitInfos(@Nullable Set<String> handledExitInfos) {
        if (handledExitInfos == null) {
            Log.w(TAG, "Attempted to store null exit info set");
            return false;
        }
        
        lock.writeLock().lock();
        try {
            SharedPreferences.Editor editor = sharedPreferences.edit();
            // Create a defensive copy to avoid potential concurrent modification
            Set<String> copy = Collections.unmodifiableSet(new HashSet<>(handledExitInfos));
            editor.putStringSet(HANDLED_EXIT_INFO_KEY, copy);
            return editor.commit(); // Using commit() for synchronous write
        } catch (Exception e) {
            Log.e(TAG, "Error storing handled exit infos", e);
            return false;
        } finally {
            lock.writeLock().unlock();
        }
    }
    
    /**
     * Clear all handled exit information
     * @return true if the operation was successful, false otherwise
     */
    public boolean clearHandledExitInfos() {
        lock.writeLock().lock();
        try {
            SharedPreferences.Editor editor = sharedPreferences.edit();
            editor.remove(HANDLED_EXIT_INFO_KEY);
            return editor.commit();
        } catch (Exception e) {
            Log.e(TAG, "Error clearing handled exit infos", e);
            return false;
        } finally {
            lock.writeLock().unlock();
        }
    }
}