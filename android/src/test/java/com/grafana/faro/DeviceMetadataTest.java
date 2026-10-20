package com.grafana.faro;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import java.util.HashMap;
import java.util.Map;

import org.junit.Test;

public class DeviceMetadataTest {
    @Test
    public void reportsScreenDensityAndMemory() {
        Map<String, Object> expected = new HashMap<>();
        expected.put(DeviceMetadata.SCREEN_WIDTH_KEY, 1080);
        expected.put(DeviceMetadata.SCREEN_HEIGHT_KEY, 2400);
        expected.put(DeviceMetadata.SCREEN_DENSITY_KEY, 2.625);
        expected.put(DeviceMetadata.MEMORY_TOTAL_KEY, 7_981_822_976L);

        assertEquals(expected, DeviceMetadata.build(1080, 2400, 420, 7_981_822_976L));
    }

    @Test
    public void keepsDensityExactForTvDpi() {
        Map<String, Object> metadata = DeviceMetadata.build(0, 0, 213, 0);

        assertEquals(1.33125, metadata.get(DeviceMetadata.SCREEN_DENSITY_KEY));
    }

    // A failed read leaves zeros, which are not real values.
    @Test
    public void omitsUnreadValues() {
        assertTrue(DeviceMetadata.build(0, 0, 0, 0).isEmpty());
    }

    @Test
    public void omitsScreenSizeWhenOneSideIsMissing() {
        Map<String, Object> metadata = DeviceMetadata.build(1080, 0, 0, 0);

        assertTrue(metadata.isEmpty());
    }

    @Test
    public void reportsNothingWithoutContext() {
        assertTrue(DeviceMetadata.current(null).isEmpty());
    }

    // The Dart side reads these keys by name and ignores any other key.
    @Test
    public void usesTheKeysTheDartSideReads() {
        assertEquals("screenWidth", DeviceMetadata.SCREEN_WIDTH_KEY);
        assertEquals("screenHeight", DeviceMetadata.SCREEN_HEIGHT_KEY);
        assertEquals("screenDensity", DeviceMetadata.SCREEN_DENSITY_KEY);
        assertEquals("memoryTotal", DeviceMetadata.MEMORY_TOTAL_KEY);
    }
}
