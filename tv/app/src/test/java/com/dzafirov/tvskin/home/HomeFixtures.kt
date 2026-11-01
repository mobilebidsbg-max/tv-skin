package com.dzafirov.tvskin.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppEntry.Kind
import com.dzafirov.tvskin.ui.AppArt
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.weather.HourWeather
import com.dzafirov.tvskin.weather.WeatherNow

/** Stand-in banners for snapshots: Robolectric has no real apps installed. */
object FakeAppArt : AppArt {
    private val colors = mapOf(
        "youtube" to Color.White, "netflix" to Color.Black, "hbo" to Color(0xFF3A2BE0),
        "prime" to Color(0xFF0F171E), "disney" to Color(0xFF0B2F6B), "apple" to Color(0xFF0B0B0D), "music" to Color(0xFF0F0F0F),
    )

    @Composable
    override fun Art(entry: AppEntry, modifier: Modifier) {
        val key = colors.keys.firstOrNull { entry.id.contains(it) || entry.label.lowercase().contains(it) }
        val bg = colors[key] ?: Color.DarkGray
        Box(modifier.fillMaxSize().background(bg), contentAlignment = Alignment.Center) {
            Text(entry.label, color = if (bg == Color.White) Color.Red else Color.White, fontSize = 13.sp, fontWeight = FontWeight.Bold)
        }
    }
}

fun app(pkg: String, label: String) = AppEntry(pkg, label, Kind.APP)

val sampleApps = listOf(
    app("com.google.android.youtube.tv", "YouTube"),
    app("com.netflix.ninja", "Netflix"),
    app("com.wbd.stream", "HBO Max"),
    app("com.amazon.amazonvideo.livingroom", "Prime Video"),
    app("com.disney.disneyplus", "Disney+"),
    app("com.apple.atve.androidtv.appletv", "Apple TV"),
    app("com.google.android.youtube.tvmusic", "YouTube Music"),
)

val sampleTvItems = listOf(
    AppEntry(AppEntry.LIVE_TV_ID, "Live TV", Kind.LIVE_TV),
    AppEntry(AppEntry.INPUT_PREFIX + "hdmi1", "HDMI 1", Kind.INPUT),
    AppEntry(AppEntry.SETTINGS_ID, "Settings", Kind.SETTINGS),
)

fun sampleState(
    apps: List<AppEntry> = sampleApps,
    sleepLeftMinutes: Int? = null,
) = HomeState(
    wallpaper = Wallpaper.DUNE,
    greeting = "Good evening",
    date = "Sun 1 Nov",
    time = "21:40",
    weather = WeatherNow(9, "clear", code = 0),
    hours = listOf(HourWeather(21, 9, 0), HourWeather(22, 8, 0), HourWeather(23, 7, 3), HourWeather(0, 7, 3), HourWeather(1, 6, 0)),
    nowPlaying = null,
    lastApp = sampleApps.first(),
    lastAppSubtitle = "Opened 20 min ago",
    sleepLeftMinutes = sleepLeftMinutes,
    apps = apps,
    tvItems = sampleTvItems,
    promos = listOf(sampleApps[1], sampleApps[2]),
)

object NoActions : HomeActions {
    override fun open(e: AppEntry) {}
    override fun sideBySide() {}
    override fun sleep() {}
    override fun hold(e: AppEntry) {}
    override fun settings() {}
    override fun tab(tab: Tab) {}
    override fun inputs() {}
}
