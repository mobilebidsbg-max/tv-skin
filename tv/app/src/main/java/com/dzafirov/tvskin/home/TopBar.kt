package com.dzafirov.tvskin.home

import androidx.compose.foundation.Image
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextOverflow
import com.dzafirov.tvskin.ui.Frost
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.apps.AppEntry
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
fun TopBar(state: HomeState, selected: Tab, onTab: (Tab) -> Unit, onOpenApp: (String) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth().height(Sizes.topBarHeight)) {
        // YouTube Music, always here by design: what it plays now, else its last song, else an invitation.
        val music = state.nowPlaying?.takeIf { it.packageName == YT_MUSIC } ?: state.lastMusic
        NowPlayingPill(music, state.wallpaper, onOpen = { onOpenApp(YT_MUSIC) }, modifier = Modifier.align(Alignment.CenterStart))
        Tabs(state.wallpaper, selected, onTab, Modifier.align(Alignment.Center))
        Status(state, Modifier.align(Alignment.CenterEnd))
    }
}

/** What's playing (v5 top-left): cover, title, artist and moving bars while it plays; OK opens that app. */
@Composable
private fun NowPlayingPill(np: NowPlaying?, wallpaper: Wallpaper, onOpen: () -> Unit, modifier: Modifier) {
    FocusSurface(
        onClick = onOpen,
        modifier = modifier.height(32.dp).testTag("nowplaying"),
        radius = 16.dp,
        focusedScale = 1.05f,
        container = Color.Transparent,
        focusedContainer = Color.White.copy(alpha = 0.22f),
        focusedContent = Color.White,
        edge = TvColors.GlassEdge,
    ) {
        Frost(wallpaper, Modifier.matchParentSize(), feather = 0.dp, darken = 0.05f)
        Box(Modifier.matchParentSize().background(TvColors.GlassFill))
        Row(Modifier.padding(start = 5.dp, end = 12.dp).align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
            val art = np?.art
            if (art != null) {
                Image(art.asImageBitmap(), null, Modifier.size(22.dp).clip(RoundedCornerShape(6.dp)), contentScale = ContentScale.Crop)
            } else {
                Box(Modifier.size(22.dp).clip(RoundedCornerShape(6.dp))) {
                    LocalAppArt.current.Art(AppEntry(YT_MUSIC, "YouTube Music", AppEntry.Kind.APP), Modifier)
                }
            }
            Text(np?.title ?: "YouTube Music", style = TvType.body.copy(fontWeight = FontWeight.SemiBold, fontSize = 11.sp), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 150.dp))
            val artist = np?.artist ?: "Play something"
            if (artist.isNotEmpty()) {
                Text(artist, style = TvType.body.copy(fontSize = 11.sp), color = TvColors.Dim, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 90.dp))
            }
            if (np != null) EqBars(np.playing)
        }
    }
}

/** Three little bars that move while something plays and rest when it is paused. */
@Composable
private fun EqBars(playing: Boolean) {
    val transition = rememberInfiniteTransition(label = "eq")
    Row(Modifier.height(10.dp), horizontalArrangement = Arrangement.spacedBy(1.5.dp), verticalAlignment = Alignment.Bottom) {
        listOf(0, 250, 500).forEach { delay ->
            val h by transition.animateFloat(
                initialValue = 0.3f, targetValue = 1f,
                animationSpec = infiniteRepeatable(tween(500, delayMillis = delay), RepeatMode.Reverse), label = "bar",
            )
            Box(Modifier.size(width = 2.dp, height = 10.dp * (if (playing) h else 0.3f)).clip(RoundedCornerShape(1.dp)).background(Color.White))
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
            IconTab(R.drawable.ic_gear, Tab.SETTINGS, onTab, selected = selected == Tab.SETTINGS)
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
private fun IconTab(icon: Int, tab: Tab, onTab: (Tab) -> Unit, tint: Boolean = true, selected: Boolean = false) {
    FocusSurface(
        onClick = { onTab(tab) },
        modifier = Modifier.size(width = 34.dp, height = 30.dp).testTag("tab:${tab.name.lowercase()}"),
        radius = 15.dp,
        container = if (selected) TvColors.FocusFill else Color.Transparent,
        content = if (selected) TvColors.Ink else Color.White,
        focusedContainer = if (selected) Color.White else Color.White.copy(alpha = 0.26f),
        focusedContent = if (selected) TvColors.Ink else Color.White,
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

/** YouTube Music for Android TV. */
const val YT_MUSIC = "com.google.android.youtube.tvmusic"
