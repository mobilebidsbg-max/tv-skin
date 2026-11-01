package com.dzafirov.tvskin.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.unit.dp
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.tv.material3.Text
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class FrostSnapshotTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun frostOnDune() {
        compose.setContent {
            TvSkinTheme {
                Box(Modifier.fillMaxSize()) {
                    WallpaperImage(Wallpaper.DUNE)
                    Frost(Wallpaper.DUNE, Modifier.offset(60.dp, 300.dp).size(520.dp, 180.dp)) {
                        Text("Good evening", style = TvType.greeting, modifier = Modifier.padding(start = 40.dp, top = 60.dp))
                    }
                }
            }
        }
        compose.onRoot().captureRoboImage(snapshot("frostOnDune"))
    }
}
