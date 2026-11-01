package com.dzafirov.tvskin.media

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NowPlayingTest {
    private fun s(pkg: String, title: String?, playing: Boolean, artist: String? = "Artist") = SessionInfo(pkg, title, artist, playing)

    @Test
    fun `a playing session wins over a paused one`() {
        val picked = pickNowPlaying(listOf(s("paused.app", "Old song", false), s("com.google.android.youtube.tvmusic", "Midnight City", true, "M83")))
        assertEquals("Midnight City", picked?.title)
        assertEquals("M83", picked?.artist)
        assertEquals("com.google.android.youtube.tvmusic", picked?.packageName)
        assertEquals(true, picked?.playing)
    }

    @Test
    fun `a paused session still shows when nothing plays`() {
        assertEquals("Old song", pickNowPlaying(listOf(s("paused.app", "Old song", false)))?.title)
    }

    @Test
    fun `sessions without a title are ignored`() {
        assertNull(pickNowPlaying(listOf(s("a", null, true), s("b", "  ", true))))
        assertNull(pickNowPlaying(emptyList()))
    }
}
