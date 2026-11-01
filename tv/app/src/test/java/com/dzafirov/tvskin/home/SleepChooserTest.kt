package com.dzafirov.tvskin.home

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsFocused
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
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
class SleepChooserTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `sleep button offers off 30 60 90 and sets the choice`() {
        val set = mutableListOf<Int?>()
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
                TvSkinTheme { HomeScreen(sampleState(), object : HomeActions by NoActions { override fun setSleep(minutes: Int?) { set += minutes } }) }
            }
        }
        compose.onNodeWithTag("smart:sleep").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("menu:sleep:off").assertIsFocused()
        compose.onNodeWithTag("menu:sleep:60").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("widget:sleep").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("menu:sleep:off").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf(60, null), set)
    }
}
