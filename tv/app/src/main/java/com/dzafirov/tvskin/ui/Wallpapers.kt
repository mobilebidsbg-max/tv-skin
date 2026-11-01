package com.dzafirov.tvskin.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.dzafirov.tvskin.R

/**
 * The still wallpapers: 1920x1080 for the UI layer, a pre-blurred darkened copy and a 240x135 thumbnail
 * (tools/make_blur.py), and a 3840x2160 version (AI-upscaled with Real-ESRGAN x4plus) for the TV's 4K panel.
 */
enum class Wallpaper(@DrawableRes val sharp: Int, @DrawableRes val blurred: Int, @DrawableRes val thumb: Int, @DrawableRes val uhd: Int) {
    DUNE(R.drawable.wall_dune, R.drawable.wall_dune_blur, R.drawable.wall_dune_thumb, R.drawable.wall_dune_4k),
    DUNES(R.drawable.wall_dunes, R.drawable.wall_dunes_blur, R.drawable.wall_dunes_thumb, R.drawable.wall_dunes_4k),
    RIDGES(R.drawable.wall_ridges, R.drawable.wall_ridges_blur, R.drawable.wall_ridges_thumb, R.drawable.wall_ridges_4k),
    GOLDEN(R.drawable.wall_golden, R.drawable.wall_golden_blur, R.drawable.wall_golden_thumb, R.drawable.wall_golden_4k);

    companion object {
        val DEFAULT = DUNE
    }
}

/** The sharp wallpaper filling the screen. It never changes when focus moves. */
@Composable
fun WallpaperImage(wallpaper: Wallpaper, modifier: Modifier = Modifier) {
    Image(
        painter = painterResource(wallpaper.sharp),
        contentDescription = null,
        contentScale = ContentScale.Crop,
        modifier = modifier.fillMaxSize(),
    )
}
