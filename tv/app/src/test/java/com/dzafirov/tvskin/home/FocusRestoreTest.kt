package com.dzafirov.tvskin.home

import androidx.activity.ComponentActivity
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.requestFocus
import androidx.compose.ui.test.performScrollToIndex
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class FocusRestoreTest {
    @get:Rule
    val compose = createAndroidComposeRule<ComponentActivity>()

    private val state = mutableStateOf(sampleState())
    private val actions = object : HomeActions by NoActions {
        override fun unhide(e: AppEntry) {
            state.value = state.value.copy(hiddenApps = state.value.hiddenApps - e)
        }
    }

    private fun show() {
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) { TvSkinTheme { HomeScreen(state.value, actions) } }
        }
        compose.waitForIdle()
    }

    private fun click(tag: String) {
        compose.onNodeWithTag(tag).performSemanticsAction(SemanticsActions.OnClick)
        compose.waitForIdle()
    }

    private fun back() {
        compose.runOnUiThread { compose.activity.onBackPressedDispatcher.onBackPressed() }
        compose.waitForIdle()
    }

    @Test
    fun `closing the sleep chooser returns focus to the sleep button`() {
        show()
        click("smart:sleep")
        back()
        compose.onNodeWithTag("smart:sleep").assertIsFocused()
    }

    @Test
    fun `a sleep choice from the quick control returns focus there`() {
        show()
        click("widget:sleep")
        click("menu:sleep:30")
        compose.onNodeWithTag("widget:sleep").assertIsFocused()
    }

    @Test
    fun `closing the input chooser returns focus to the input control`() {
        show()
        click("widget:input")
        back()
        compose.onNodeWithTag("widget:input").assertIsFocused()
    }

    @Test
    fun `unhiding a row focuses the next row`() {
        state.value = state.value.copy(hiddenApps = listOf(app("com.iqiyi.i18n.tv", "iQIYI"), app("com.tcl.dashboard", "TCL Channel")))
        show()
        click("tab:settings")
        click("settings:hidden:com.iqiyi.i18n.tv")
        compose.onNodeWithTag("settings:hidden:com.tcl.dashboard").assertIsFocused()
    }

    @Test
    fun `pressing Home again resets to the home row`() {
        show()
        click("tab:apps")
        compose.onNodeWithTag("grid:com.netflix.ninja").assertExists()
        state.value = state.value.copy(resetToken = state.value.resetToken + 1)
        compose.waitForIdle()
        compose.onNodeWithTag("grid:com.netflix.ninja").assertDoesNotExist()
        compose.onNodeWithTag("app:com.google.android.youtube.tv").assertIsFocused()
    }

    @Test
    fun `pressing Home again closes the side by side picker`() {
        show()
        click("smart:split")
        click("menu:pick:com.google.android.youtube.tv")
        compose.onNodeWithTag("menu:pick:com.netflix.ninja").assertExists()
        state.value = state.value.copy(resetToken = state.value.resetToken + 1)
        compose.waitForIdle()
        compose.onNodeWithTag("menu:pick:com.netflix.ninja").assertDoesNotExist()
        compose.onNodeWithTag("app:com.google.android.youtube.tv").assertIsFocused()
        click("smart:split")
        compose.onNodeWithTag("menu:pick:com.google.android.youtube.tv").assertExists() // starts again from the first app
    }

    @Test
    fun `the first app gets focus when the app list arrives after the screen`() {
        val apps = state.value.apps
        state.value = state.value.copy(apps = emptyList(), tvItems = emptyList())
        show()
        state.value = state.value.copy(apps = apps, tvItems = sampleTvItems)
        compose.waitForIdle()
        compose.onNodeWithTag("app:com.google.android.youtube.tv").assertIsFocused()
    }

    @Test
    fun `Home brings focus back to the first app even when the row has scrolled away from it`() {
        val many = sampleApps + (1..8).map { app("com.example.app$it", "App $it") }
        state.value = state.value.copy(apps = many)
        show()
        compose.onNodeWithTag("row:apps").performScrollToIndex(many.size + 2)
        compose.onNodeWithTag("tv:settings").requestFocus()
        compose.waitForIdle()
        compose.onNodeWithTag("app:com.google.android.youtube.tv").assertDoesNotExist() // scrolled out of the row
        state.value = state.value.copy(resetToken = state.value.resetToken + 1)
        compose.waitForIdle()
        compose.onNodeWithTag("app:com.google.android.youtube.tv").assertIsFocused()
    }
}
