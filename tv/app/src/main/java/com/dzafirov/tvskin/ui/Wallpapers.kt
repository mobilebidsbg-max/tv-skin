package com.dzafirov.tvskin.ui

import androidx.annotation.DrawableRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import com.dzafirov.tvskin.R

/** The still wallpapers (1920x1080), their pre-blurred, darkened copies and 240x135 thumbnails (tools/make_blur.py). */
enum class Wallpaper(@DrawableRes val sharp: Int, @DrawableRes val blurred: Int, @DrawableRes val thumb: Int) {
    DUNE(R.drawable.wall_dune, R.drawable.wall_dune_blur, R.drawable.wall_dune_thumb),
    DUNES(R.drawable.wall_dunes, R.drawable.wall_dunes_blur, R.drawable.wall_dunes_thumb),
    RIDGES(R.drawable.wall_ridges, R.drawable.wall_ridges_blur, R.drawable.wall_ridges_thumb),
    GOLDEN(R.drawable.wall_golden, R.drawable.wall_golden_blur, R.drawable.wall_golden_thumb);

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
