package com.dzafirov.tvskin.home

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class WidgetsTest {
    @get:Rule
    val compose = createComposeRule()

    private val calls = mutableListOf<String>()

    private fun show() = compose.setContent {
        CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
            TvSkinTheme {
                HomeScreen(sampleState(), object : HomeActions by NoActions {
                    override fun openUrl(url: String) { calls += "url $url" }
                    override fun openDisplaySound() { calls += "display" }
                })
            }
        }
    }

    @Test
    fun `air card shows the verdict and the tip`() {
        show()
        compose.onNodeWithText("Moderate").assertIsDisplayed()
        compose.onNodeWithText("Air the room briefly").assertIsDisplayed()
    }

    @Test
    fun `a headline opens its article, picture and sound open the TV settings`() {
        show()
        compose.onNodeWithTag("headline:0").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("widget:picture").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("widget:sound").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("url https://www.theverge.com/science/1024239", "display", "display"), calls)
    }
}
