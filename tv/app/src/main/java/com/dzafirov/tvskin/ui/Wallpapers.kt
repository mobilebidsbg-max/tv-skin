package com.dzafirov.tvskin.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.dzafirov.tvskin.R

/** The still wallpapers (1920x1080) and their pre-blurred, darkened copies (tools/make_blur.py). */
enum class Wallpaper(@DrawableRes val sharp: Int, @DrawableRes val blurred: Int) {
    DUNE(R.drawable.wall_dune, R.drawable.wall_dune_blur),
    DUNES(R.drawable.wall_dunes, R.drawable.wall_dunes_blur),
    RIDGES(R.drawable.wall_ridges, R.drawable.wall_ridges_blur),
    GOLDEN(R.drawable.wall_golden, R.drawable.wall_golden_blur);

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
