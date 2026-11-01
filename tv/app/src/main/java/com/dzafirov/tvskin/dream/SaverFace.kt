package com.dzafirov.tvskin.dream

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.ui.Inter
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.ui.LocalUhdWallpaper
import com.dzafirov.tvskin.ui.UhdWallpaperSurface
import com.dzafirov.tvskin.ui.WallpaperImage
import com.dzafirov.tvskin.weather.WeatherNow
import com.dzafirov.tvskin.weather.weatherIcon

private val shadow = Shadow(Color.Black.copy(alpha = 0.35f), Offset(0f, 2f), blurRadius = 22f)
private val big = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 56.sp, letterSpacing = (-2).sp, color = Color.White, shadow = shadow)
private val small = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Medium, fontSize = 14.sp, color = Color.White.copy(alpha = 0.92f), shadow = shadow)

/**
 * The screensaver (v5): the still wallpaper, a soft dark gradient at the bottom, a small solid-white clock with the
 * date bottom left, and the weather bottom right. [offset] (dp) drifts both corners against burn-in.
 */
@Composable
fun SaverFace(wallpaper: Wallpaper, time: String, dateLine: String, weather: WeatherNow?, night: Boolean, offset: Pair<Int, Int>) {
    Box(Modifier.fillMaxSize()) {
        if (LocalUhdWallpaper.current) {
            UhdWallpaperSurface(wallpaper, glass = false)
        } else {
            WallpaperImage(wallpaper)
            Box(Modifier.fillMaxSize().background(Brush.verticalGradient(0.66f to Color.Transparent, 1f to Color.Black.copy(alpha = 0.38f))))
        }
        val drift = Modifier.offset(offset.first.dp, offset.second.dp)
        Column(Modifier.align(Alignment.BottomStart).padding(start = 55.dp, bottom = 42.dp).then(drift)) {
            Text(time, style = big)
            Text(dateLine, style = small, modifier = Modifier.padding(top = 8.dp))
        }
        weather?.let { w ->
            Column(Modifier.align(Alignment.BottomEnd).padding(end = 55.dp, bottom = 42.dp).then(drift), horizontalAlignment = Alignment.End) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(9.dp)) {
                    Image(painterResource(weatherIcon(w.code, night)), null, Modifier.size(42.dp))
                    Text("${w.tempC}°", style = big)
                }
                Text("${w.text.replaceFirstChar { it.uppercase() }} · Sofia", style = small, textAlign = TextAlign.End, modifier = Modifier.padding(top = 8.dp))
            }
        }
    }
}
