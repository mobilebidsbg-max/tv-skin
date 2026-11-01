package com.dzafirov.tvskin.home

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppPrefs
import com.dzafirov.tvskin.apps.InstalledApps
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34])
class HomeModelTest {
    private val context = ApplicationProvider.getApplicationContext<Context>()
    private val yt = app("com.google.android.youtube.tv", "YouTube")
    private val nf = app("com.netflix.ninja", "Netflix")
    private val hbo = app("com.wbd.stream", "HBO Max")

    /** Counts how often the TV's package list is read (each read is slow on the TV). */
    private class CountingApps(val list: List<AppEntry>) : InstalledApps {
        var reads = 0
        override fun apps(): List<AppEntry> { reads++; return list }
        override fun tvItems(): List<AppEntry> = emptyList()
    }

    @Test
    fun `move, hide and unhide reuse the loaded app list`() {
        val installed = CountingApps(listOf(yt, nf, hbo))
        val model = HomeModel(context, AppPrefs(context), installed)
        model.refreshApps()
        assertEquals(1, installed.reads)
        assertEquals(listOf(yt, nf, hbo), model.state.value.apps)

        model.move(nf, -1)
        assertEquals(listOf(nf, yt, hbo), model.state.value.apps)

        model.hide(yt)
        assertEquals(listOf(nf, hbo), model.state.value.apps)
        assertTrue(yt in model.state.value.hiddenApps)

        model.unhide(yt)
        assertTrue(yt in model.state.value.apps)
        assertEquals(1, installed.reads)
    }
}
