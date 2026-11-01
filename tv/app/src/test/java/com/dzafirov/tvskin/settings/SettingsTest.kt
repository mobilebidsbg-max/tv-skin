package com.dzafirov.tvskin.settings

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.home.FakeAppArt
import com.dzafirov.tvskin.home.HomeActions
import com.dzafirov.tvskin.home.HomeScreen
import com.dzafirov.tvskin.home.NoActions
import com.dzafirov.tvskin.home.app
import com.dzafirov.tvskin.home.sampleState
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.ui.snapshot
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class SettingsTest {
    @get:Rule
    val compose = createComposeRule()

    private val hidden = listOf(app("com.iqiyi.i18n.tv", "iQIYI"), app("com.tcl.dashboard", "TCL Channel"))
    private val calls = mutableListOf<String>()
    private val actions = object : HomeActions by NoActions {
        override fun unhide(e: AppEntry) { calls += "unhide ${e.id}" }
        override fun setWallpaper(w: Wallpaper) { calls += "wallpaper $w" }
        override fun setSleepDefault(minutes: Int) { calls += "sleep $minutes" }
    }

    private fun openSettings() {
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
                TvSkinTheme { HomeScreen(sampleState().copy(hiddenApps = hidden, sleepDefaultMinutes = 60, version = "0.1"), actions) }
            }
        }
        compose.onNodeWithTag("tab:settings").performSemanticsAction(SemanticsActions.OnClick)
    }

    @Test
    fun `settings with two hidden apps`() {
        openSettings()
        compose.onNodeWithText("TCL Channel").assertIsDisplayed()
        compose.onNodeWithText("Changes to the TV: see docs/TV-INSTALL.md on the Mac").assertIsDisplayed()
        compose.onRoot().captureRoboImage(snapshot("settings"))
    }

    @Test
    fun `choices go to the activity`() {
        openSettings()
        compose.onNodeWithTag("settings:hidden:com.iqiyi.i18n.tv").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("settings:wallpaper:RIDGES").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("settings:sleep:90").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("unhide com.iqiyi.i18n.tv", "wallpaper RIDGES", "sleep 90"), calls)
    }
}
