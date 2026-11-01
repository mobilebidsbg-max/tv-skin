package com.dzafirov.tvskin

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Modifier
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.ui.WallpaperImage

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            TvSkinTheme {
                Box(Modifier.fillMaxSize()) {
                    WallpaperImage(Wallpaper.DEFAULT)
                }
            }
        }
    }
}
