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

    @Test
    fun `the Apps tab lists every app, hidden ones too`() {
        val installed = CountingApps(listOf(yt, nf, hbo))
        val model = HomeModel(context, AppPrefs(context), installed)
        model.refreshApps()
        model.hide(yt)
        assertEquals(setOf(yt, nf, hbo), model.state.value.allApps.toSet())
        assertEquals(listOf(nf, hbo), model.state.value.apps)
    }

    @Test
    fun `A1 Xplore hidden by an older version is shown once`() {
        val old = AppPrefs(context)
        old.hidden = setOf("xploretv.android.tv", "com.iqiyi.i18n.tv")
        context.getSharedPreferences("tvskin", Context.MODE_PRIVATE).edit().remove("a1_shown").commit()
        assertEquals(setOf("com.iqiyi.i18n.tv"), AppPrefs(context).hidden)
    }

    @Test
    fun `updates from other threads never lose the app list`() {
        val model = HomeModel(context, AppPrefs(context), CountingApps(listOf(yt, nf, hbo)))
        val weather = Thread { repeat(3_000) { i -> model.update { it.copy(greeting = "g$i") } } }
        val apps = Thread { repeat(300) { model.refreshApps() } }
        weather.start(); apps.start(); weather.join(); apps.join()
        assertEquals(listOf(yt, nf, hbo), model.state.value.apps)
        assertEquals("g2999", model.state.value.greeting)
    }

    @Test
    fun `an empty app list right after an update is read again`() = kotlinx.coroutines.runBlocking {
        var calls = 0
        val flaky = object : InstalledApps {
            override fun apps(): List<AppEntry> { calls++; return if (calls < 3) emptyList() else listOf(yt, nf) }
            override fun tvItems(): List<AppEntry> = emptyList()
        }
        val model = HomeModel(context, AppPrefs(context), flaky)
        model.loadApps(pause = {})
        assertEquals(3, calls)
        assertEquals(listOf(yt, nf), model.state.value.apps)
    }
}
