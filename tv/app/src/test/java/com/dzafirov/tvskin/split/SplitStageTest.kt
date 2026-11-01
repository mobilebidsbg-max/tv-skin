package com.dzafirov.tvskin.split

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.home.FakeAppArt
import com.dzafirov.tvskin.home.HomeActions
import com.dzafirov.tvskin.home.HomeScreen
import com.dzafirov.tvskin.home.NoActions
import com.dzafirov.tvskin.home.sampleApps
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
class SplitStageTest {
    @get:Rule
    val compose = createComposeRule()

    private val yt = sampleApps[0]
    private val nf = sampleApps[1]

    private fun stage(s: SplitState) = compose.setContent {
        CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
            TvSkinTheme { SplitStage(s, Wallpaper.DUNE, time = "21:40") }
        }
    }

    @Test
    fun `stage with the bar closed`() {
        stage(SplitState.start(yt, nf))
        compose.onNodeWithTag("split:hint").assertExists()
        compose.onRoot().captureRoboImage(snapshot("split_stage"))
    }

    @Test
    fun `stage with the bar open on Swap, 70-30`() {
        stage(SplitState.start(yt, nf).withRatio(Ratio.WIDE).openBar().moveBar(+2))
        compose.onNodeWithTag("split:bar:SWAP").assertExists()
        compose.onRoot().captureRoboImage(snapshot("split_bar_open"))
    }

    @Test
    fun `the Side by side button asks for two apps`() {
        val started = mutableListOf<String>()
        compose.setContent {
            CompositionLocalProvider(LocalAppArt provides FakeAppArt) {
                TvSkinTheme {
                    HomeScreen(sampleState(), object : HomeActions by NoActions {
                        override fun startSplit(left: AppEntry, right: AppEntry) { started += "${left.label}+${right.label}" }
                    })
                }
            }
        }
        compose.onNodeWithTag("smart:split").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("menu:pick:com.google.android.youtube.tv").performSemanticsAction(SemanticsActions.OnClick)
        compose.onNodeWithTag("menu:pick:com.google.android.youtube.tv").assertDoesNotExist() // the first app isn't offered twice
        compose.onNodeWithTag("menu:pick:com.netflix.ninja").performSemanticsAction(SemanticsActions.OnClick)
        assertEquals(listOf("YouTube+Netflix"), started)
    }
}
