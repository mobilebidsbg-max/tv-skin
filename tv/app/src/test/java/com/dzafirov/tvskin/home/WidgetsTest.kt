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

    @Test
    fun `now playing shows in the top bar and opens its app`() {
        val opened = mutableListOf<String>()
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
                TvSkinTheme {
                    HomeScreen(
                        sampleState().copy(nowPlaying = NowPlaying("Midnight City", "M83", "com.google.android.youtube.tvmusic", playing = true)),
                        object : HomeActions by NoActions { override fun open(e: com.dzafirov.tvskin.apps.AppEntry) { opened += e.id } },
                    )
                }
            }
        }
        compose.onNodeWithText("Midnight City").assertIsDisplayed()
        compose.onNodeWithTag("nowplaying").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("com.google.android.youtube.tvmusic"), opened)
    }

    @Test
    fun `title cards show the series and open their app`() {
        val opened = mutableListOf<String>()
        val titles = listOf(
            com.dzafirov.tvskin.widgets.Promo("Wednesday", "https://image.tmdb.org/t/p/w780/x.jpg", "Series · 2022", com.dzafirov.tvskin.widgets.Brand.NETFLIX),
            com.dzafirov.tvskin.widgets.Promo("The Last of Us", "https://image.tmdb.org/t/p/w780/y.jpg", "Series · 2023", com.dzafirov.tvskin.widgets.Brand.HBO),
        )
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
                TvSkinTheme {
                    HomeScreen(sampleState().copy(titles = titles), object : HomeActions by NoActions {
                        override fun open(e: com.dzafirov.tvskin.apps.AppEntry) { opened += e.id }
                    })
                }
            }
        }
        compose.onNodeWithText("The Last of Us").assertExists()
        compose.onNodeWithTag("title:1").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("com.wbd.stream"), opened)
    }
}
