package com.dzafirov.tvskin.dream

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.assertIsDisplayed
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dzafirov.tvskin.ui.TV_QUALIFIERS
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.ui.snapshot
import com.dzafirov.tvskin.weather.WeatherNow
import com.github.takahirom.roborazzi.captureRoboImage
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = TV_QUALIFIERS)
class SaverFaceSnapshotTest {
    @get:Rule
    val compose = createComposeRule()

    @Test
    fun `saver 21_40 on dune`() {
        compose.setContent {
            TvSkinTheme { SaverFace(Wallpaper.DUNE, "21:40", "Sunday 1 November", WeatherNow(9, "clear", 0), night = true, offset = 0 to 0) }
        }
        compose.onNodeWithText("21:40").assertIsDisplayed()
        compose.onNodeWithText("Clear · Sofia").assertIsDisplayed()
        compose.onRoot().captureRoboImage(snapshot("saver"))
    }

    @Test
    fun `saver without weather shows only the clock`() {
        compose.setContent {
            TvSkinTheme { SaverFace(Wallpaper.DUNE, "07:05", "Monday 2 November", weather = null, night = false, offset = 0 to 0) }
        }
        compose.onNodeWithText("07:05").assertIsDisplayed()
        compose.onNodeWithText("Clear · Sofia").assertDoesNotExist()
    }
}
