package com.dzafirov.tvskin.lastapp

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LastAppTest {
    private val own = "com.dzafirov.tvskin"
    private val settings = "com.android.tv.settings"
    private val youtube = "com.google.android.youtube.tv"
    private val netflix = "com.netflix.ninja"

    @Test
    fun `lastApp skips own and ignored packages`() {
        assertEquals(youtube, pickLastApp(listOf(own, settings, youtube), own, IGNORED_PACKAGES, setOf(youtube, settings)))
    }

    @Test
    fun `lastApp skips uninstalled`() {
        assertEquals(netflix, pickLastApp(listOf("gone.app", netflix), own, IGNORED_PACKAGES, setOf(netflix)))
    }

    @Test
    fun `lastApp none`() {
        assertNull(pickLastApp(listOf(own), own, IGNORED_PACKAGES, setOf(youtube)))
    }

    @Test
    fun `ignored covers the stock launcher, system UI, remote service and live TV`() {
        listOf("com.google.android.apps.tv.launcherx", "com.android.systemui", "com.google.android.tv.remote.service", "com.tcl.tv", settings)
            .forEach { assertEquals(it, true, it in IGNORED_PACKAGES) }
    }

    @Test
    fun `opened ago wording`() {
        val now = 1_000_000_000_000L
        assertEquals("Opened just now", openedAgo(now, now - 30_000))
        assertEquals("Opened 20 min ago", openedAgo(now, now - 20 * 60_000))
        assertEquals("Opened 2 h ago", openedAgo(now, now - 2 * 3_600_000 - 5 * 60_000))
        assertEquals("Opened yesterday", openedAgo(now, now - 30 * 3_600_000L))
    }

    @Test
    fun `merge keeps the newest time per package, newest first`() {
        val merged = mergeRecent(listOf("a" to 10L, "b" to 30L), listOf("a" to 50L, "c" to 20L))
        assertEquals(listOf("a" to 50L, "b" to 30L, "c" to 20L), merged)
    }
}
