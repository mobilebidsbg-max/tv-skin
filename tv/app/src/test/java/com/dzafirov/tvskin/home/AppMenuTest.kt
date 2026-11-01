package com.dzafirov.tvskin.home

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
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
class AppMenuTest {
    @get:Rule
    val compose = createComposeRule()

    private val youtube = "app:com.google.android.youtube.tv"

    /** Records what the menu asked for, and applies hide/move to the state like the real model. */
    private inner class Recorder : HomeActions by NoActions {
        val state = mutableStateOf(sampleState())
        val calls = mutableListOf<String>()
        override fun hide(e: AppEntry) {
            calls += "hide ${e.id}"
            state.value = state.value.copy(apps = state.value.apps - e)
        }
        override fun move(e: AppEntry, delta: Int) { calls += "move ${e.id} $delta" }
    }

    private fun show(rec: Recorder) = compose.setContent {
        CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
            TvSkinTheme { HomeScreen(rec.state.value, rec) }
        }
    }

    @Test
    fun `app menu open on YouTube`() {
        show(Recorder())
        compose.onNodeWithTag(youtube).performSemanticsAction(SemanticsActions.OnLongClick)
        compose.onNodeWithTag("menu:open").assertIsDisplayed().assertIsFocused()
        compose.onRoot().captureRoboImage(snapshot("app_menu_youtube"))
    }

    @Test
    fun `hide removes the app and closes the menu`() {
        val rec = Recorder()
        show(rec)
        compose.onNodeWithTag(youtube).performSemanticsAction(SemanticsActions.OnLongClick)
        compose.onNodeWithTag("menu:hide").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("hide com.google.android.youtube.tv"), rec.calls)
        compose.onNodeWithTag("menu:open").assertDoesNotExist()
        compose.onNodeWithTag("app:com.netflix.ninja").assertIsFocused()
    }

    @Test
    fun `input chooser lists the TV inputs`() {
        show(Recorder())
        compose.onNodeWithTag("widget:input").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("menu:tv:live-tv").assertIsDisplayed()
        compose.onNodeWithTag("menu:tv:tv-input:hdmi1").assertIsDisplayed()
    }
}
