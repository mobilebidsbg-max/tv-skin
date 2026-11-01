package com.dzafirov.tvskin.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.GlassPanel
import com.dzafirov.tvskin.ui.Sizes
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.weather.isNight
import com.dzafirov.tvskin.weather.weatherIcon

/** v5 top bar: now playing (left), glass tabs (centre), weather · date · time · avatar (right). */
@Composable
fun TopBar(state: HomeState, selected: Tab, onTab: (Tab) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(Sizes.topBarHeight)) {
        state.nowPlaying?.let { NowPlayingPill(it, state.wallpaper, Modifier.align(Alignment.CenterStart)) }
        Tabs(state.wallpaper, selected, onTab, Modifier.align(Alignment.Center))
        Status(state, Modifier.align(Alignment.CenterEnd))
    }
}

@Composable
private fun NowPlayingPill(np: NowPlaying, wallpaper: Wallpaper, modifier: Modifier) {
    GlassPanel(wallpaper, modifier.height(32.dp), radius = 16.dp) {
        Row(Modifier.padding(horizontal = 12.dp).align(Alignment.Center), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            Text(np.title, style = TvType.body.copy(fontWeight = FontWeight.SemiBold, fontSize = 11.sp), color = Color.White)
            Text(np.artist, style = TvType.body.copy(fontSize = 11.sp), color = TvColors.Dim)
        }
    }
}

@Composable
private fun Tabs(wallpaper: Wallpaper, selected: Tab, onTab: (Tab) -> Unit, modifier: Modifier) {
    GlassPanel(wallpaper, modifier.height(Sizes.topBarHeight), radius = 19.dp) {
        Row(Modifier.padding(4.dp), horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
            IconTab(R.drawable.ic_spark, Tab.ASK, onTab, tint = false)
            TextTab(R.string.tab_home, Tab.HOME, onTab, selected = selected == Tab.HOME)
            TextTab(R.string.tab_apps, Tab.APPS, onTab, selected = selected == Tab.APPS)
            TextTab(R.string.tab_music, Tab.MUSIC, onTab, selected = selected == Tab.MUSIC)
            TextTab(R.string.tab_photos, Tab.PHOTOS, onTab, selected = selected == Tab.PHOTOS)
            IconTab(R.drawable.ic_gear, Tab.SETTINGS, onTab)
        }
    }
}

@Composable
private fun TextTab(label: Int, tab: Tab, onTab: (Tab) -> Unit, selected: Boolean = false) {
    FocusSurface(
        onClick = { onTab(tab) },
        modifier = Modifier.height(30.dp).testTag("tab:${tab.name.lowercase()}"),
        radius = 15.dp,
        container = if (selected) TvColors.FocusFill else Color.Transparent,
        content = if (selected) TvColors.Ink else Color.White.copy(alpha = 0.84f),
        focusedContainer = if (selected) Color.White else Color.White.copy(alpha = 0.26f),
        focusedContent = if (selected) TvColors.Ink else Color.White,
    ) {
        Text(stringResource(label), style = TvType.tab, modifier = Modifier.align(Alignment.Center).padding(horizontal = 14.dp))
    }
}

@Composable
private fun IconTab(icon: Int, tab: Tab, onTab: (Tab) -> Unit, tint: Boolean = true) {
    FocusSurface(
        onClick = { onTab(tab) },
        modifier = Modifier.size(width = 34.dp, height = 30.dp).testTag("tab:${tab.name.lowercase()}"),
        radius = 15.dp,
        container = Color.Transparent,
        focusedContainer = Color.White.copy(alpha = 0.26f),
        focusedContent = Color.White,
    ) {
        if (tint) Icon(painterResource(icon), null, Modifier.size(15.dp).align(Alignment.Center))
        else Image(painterResource(icon), null, Modifier.size(15.dp).align(Alignment.Center))
    }
}

@Composable
private fun Status(state: HomeState, modifier: Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        state.weather?.let { w ->
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                val hour = state.time.substringBefore(':').toIntOrNull() ?: 12
                Image(painterResource(weatherIcon(w.code, isNight(hour))), null, Modifier.size(17.dp))
                Text("${w.tempC}°", style = TvType.status.copy(fontWeight = FontWeight.Medium), color = Color.White.copy(alpha = 0.9f))
            }
        }
        Text(state.date, style = TvType.status.copy(fontWeight = FontWeight.Medium), color = Color.White.copy(alpha = 0.72f))
        Text(state.time, style = TvType.status, color = Color.White)
        Box(
            Modifier.size(28.dp).clip(CircleShape).background(Brush.linearGradient(listOf(Color(0xFFFFC27A), Color(0xFFD9944A)))),
            contentAlignment = Alignment.Center,
        ) {
            Text(stringResource(R.string.avatar_letter), style = TvType.status.copy(fontSize = 12.sp), color = Color(0xFF2A1806))
        }
    }
}

/** Keeps a composable in layout but invisible (the hero while the rows are scrolled up). */
fun Modifier.visible(alpha: Float) = this.alpha(alpha)
