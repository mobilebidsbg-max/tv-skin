package com.dzafirov.tvskin.home

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.ext.junit.runners.AndroidJUnit4
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
class AppsPageTest {
    @get:Rule
    val compose = createComposeRule()

    private val manyApps = sampleApps + (1..8).map { app("com.example.app$it", "App $it") }

    private fun show(actions: HomeActions = NoActions) = compose.setContent {
        CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
            TvSkinTheme { HomeScreen(sampleState(apps = manyApps), actions) }
        }
    }

    @Test
    fun `apps page grid`() {
        show()
        compose.onNodeWithTag("tab:apps").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("grid:com.example.app8").assertIsDisplayed()
        compose.onNodeWithTag("grid:com.google.android.youtube.tv").assertIsFocused()
        compose.onRoot().captureRoboImage(snapshot("apps_page"))
    }

    @Test
    fun `other tabs go to the activity`() {
        val tabs = mutableListOf<Tab>()
        show(object : HomeActions by NoActions { override fun tab(tab: Tab) { tabs += tab } })
        compose.onNodeWithTag("tab:music").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("tab:photos").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("tab:ask").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf(Tab.MUSIC, Tab.PHOTOS, Tab.ASK), tabs)
    }
}
