package com.grafana.faro;

import android.content.ContentProvider;
import android.content.ContentValues;
import android.database.Cursor;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

/**
 * Runs at process init so the SDK can tell a user-initiated launch apart from a
 * process Android started in the background.
 *
 * <p>The platform creates every manifest-declared ContentProvider before
 * {@code Application.onCreate()}. That is the only moment where
 * {@link android.app.ActivityManager#getMyMemoryState} still reveals why the
 * process came up: once an Activity exists, every process reports foreground
 * importance. This provider exists solely to take that sample. It stores no
 * data, answers no queries, and is never addressed by anyone.
 *
 * <p>It is merged into the host app's manifest automatically. An app that does
 * not want it can drop it with
 * {@code <provider android:name="com.grafana.faro.FaroStartupProvider"
 * tools:node="remove" />}. This is the SDK's only way to prove a launch was
 * user-visible, so without it no cold start is reported on any Android version.
 */
public final class FaroStartupProvider extends ContentProvider {

    @Override
    public boolean onCreate() {
        AppStartTracker.recordProcessInit();
        return true;
    }

    @Nullable
    @Override
    public Cursor query(
            @NonNull Uri uri,
            @Nullable String[] projection,
            @Nullable String selection,
            @Nullable String[] selectionArgs,
            @Nullable String sortOrder) {
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(@NonNull Uri uri, @Nullable ContentValues values) {
        return null;
    }

    @Override
    public int delete(
            @NonNull Uri uri, @Nullable String selection, @Nullable String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(
            @NonNull Uri uri,
            @Nullable ContentValues values,
            @Nullable String selection,
            @Nullable String[] selectionArgs) {
        return 0;
    }
}
