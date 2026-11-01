package com.dzafirov.tvskin.home

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.requestFocus
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.ui.snapshot
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class HomeSnapshotTest {
    @get:Rule
    val compose = createComposeRule()

    private fun show(state: HomeState) = compose.setContent {
        CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
            TvSkinTheme { HomeScreen(state, NoActions) }
        }
    }

    @Test
    fun home() {
        show(sampleState())
        compose.onRoot().captureRoboImage(snapshot("home"))
    }

    @Test
    fun `home with long labels`() {
        val apps = sampleApps.toMutableList().also { it[6] = app("com.google.android.youtube.tvmusic", "YouTube Music for TV with a very long name") }
        show(sampleState(apps = apps))
        compose.onNodeWithTag("app:com.google.android.youtube.tvmusic").requestFocus()
        compose.onRoot().captureRoboImage(snapshot("home_long_labels"))
    }

    @Test
    fun `home with sleep running`() {
        show(sampleState(sleepLeftMinutes = 42))
        compose.onNodeWithTag("smart:sleep").assertTextContains("42 min")
        compose.onRoot().captureRoboImage(snapshot("home_sleep_running"))
    }

    @Test
    fun `home scrolled to widgets`() {
        show(sampleState())
        compose.onNodeWithTag("widget:weather").requestFocus()
        compose.waitForIdle()
        compose.onRoot().captureRoboImage(snapshot("home_widgets"))
    }
}
