package com.dzafirov.tvskin.split

import android.accessibilityservice.AccessibilityServiceInfo.FLAG_REQUEST_FILTER_KEY_EVENTS
import android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS
import org.junit.Assert.assertEquals
import org.junit.Test

/** Keys pass through the service (and wait for it) only while side by side is on. */
class KeyFilterTest {
    @Test
    fun `filtering is on only while side by side is on, other flags stay`() {
        assertEquals(FLAG_REPORT_VIEW_IDS or FLAG_REQUEST_FILTER_KEY_EVENTS, keyFilterFlags(FLAG_REPORT_VIEW_IDS, splitActive = true))
        assertEquals(FLAG_REPORT_VIEW_IDS, keyFilterFlags(FLAG_REPORT_VIEW_IDS or FLAG_REQUEST_FILTER_KEY_EVENTS, splitActive = false))
        assertEquals(0, keyFilterFlags(0, splitActive = false))
    }
}
