package com.dzafirov.tvskin.home

import androidx.activity.ComponentActivity
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.test.requestFocus
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** Real key sequences, as the remote sends them: a hold is DOWN, repeated DOWNs, then UP when released. */
@OptIn(ExperimentalTestApi::class)
@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class HoldKeyTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val youtube = "app:com.google.android.youtube.tv"
    private val opened = mutableListOf<String>()
    private val actions = object : HomeActions by NoActions {
        override fun open(e: AppEntry) { opened += e.id }
    }

    private fun show() {
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) { TvSkinTheme { HomeScreen(sampleState(), actions) } }
        }
        compose.onNodeWithTag(youtube).requestFocus()
        compose.waitForIdle()
    }

    private fun holdOk(tag: String) = compose.onNodeWithTag(tag).performKeyInput {
        keyDown(Key.DirectionCenter)
        advanceEventTime(1_200)
        keyUp(Key.DirectionCenter)
    }

    @Test
    fun `holding OK opens the menu and releasing does not open the app`() {
        show()
        holdOk(youtube)
        compose.waitForIdle()
        compose.onNodeWithTag("menu:open").assertIsDisplayed()
        assertEquals(emptyList<String>(), opened)
    }

    @Test
    fun `a short OK press opens the app`() {
        show()
        compose.onNodeWithTag(youtube).performKeyInput { pressKey(Key.DirectionCenter) }
        compose.waitForIdle()
        assertEquals(listOf("com.google.android.youtube.tv"), opened)
        compose.onNodeWithTag("menu:open").assertDoesNotExist()
    }

    @Test
    fun `after the menu is closed a short OK opens the app again`() {
        show()
        holdOk(youtube)
        compose.waitForIdle()
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
        compose.onNodeWithTag(youtube).assertIsFocused()
        compose.onNodeWithTag(youtube).performKeyInput { pressKey(Key.DirectionCenter) }
        compose.waitForIdle()
        assertEquals(listOf("com.google.android.youtube.tv"), opened)
    }

    @Test
    fun `repeats that reach the menu after it opens do not click it on release`() {
        show()
        // The TV's remote: the hold is noticed at the first repeat, the menu opens and takes focus,
        // and the remote keeps sending repeats (now to the menu) until the button is released.
        compose.onNodeWithTag(youtube).performKeyInput {
            keyDown(Key.DirectionCenter)
            advanceEventTime(700)
        }
        compose.waitForIdle()
        compose.onNodeWithTag("menu:open").assertIsFocused()
        compose.onNodeWithTag("menu:open").performKeyInput {
            advanceEventTime(600)
            keyUp(Key.DirectionCenter)
        }
        compose.waitForIdle()
        compose.onNodeWithTag("menu:open").assertIsDisplayed()
        assertEquals(emptyList<String>(), opened)
    }
}
