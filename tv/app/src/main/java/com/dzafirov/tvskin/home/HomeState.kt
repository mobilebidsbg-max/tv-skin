package com.dzafirov.tvskin.home

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.weather.HourWeather
import com.dzafirov.tvskin.weather.WeatherNow
import com.dzafirov.tvskin.widgets.AirNow
import com.dzafirov.tvskin.widgets.Headline

/** What is playing right now (from the TV's media sessions); null hides the pill. */
data class NowPlaying(
    val title: String,
    val artist: String,
    val packageName: String = "",
    val playing: Boolean = true,
    val art: android.graphics.Bitmap? = null,
)

enum class Tab { ASK, HOME, APPS, MUSIC, PHOTOS, SETTINGS }

data class HomeState(
    val wallpaper: Wallpaper,
    val greeting: String,
    val date: String,
    val time: String,
    val weather: WeatherNow?,
    val hours: List<HourWeather>,
    val nowPlaying: NowPlaying?,
    /** The last song YouTube Music played (kept across restarts), shown when nothing plays. */
    val lastMusic: NowPlaying? = null,
    val lastApp: AppEntry?,
    val lastAppSubtitle: String?,
    val sleepLeftMinutes: Int?,
    val apps: List<AppEntry>,
    val tvItems: List<AppEntry>,
    val promos: List<AppEntry>,
    val air: AirNow? = null,
    val headlines: List<Headline> = emptyList(),
    /** Popular series on Netflix and HBO Max in Bulgaria (TMDB); empty shows the two apps' own banners. */
    val titles: List<com.dzafirov.tvskin.widgets.Promo> = emptyList(),
    val hiddenApps: List<AppEntry> = emptyList(),
    /** Every installed app for the Apps tab: his order first, hidden ones included. */
    val allApps: List<AppEntry> = emptyList(),
    val sleepDefaultMinutes: Int = 60,
    val version: String = "",
    /** Bumped when Home is pressed while this screen is already open: back to the home row, menus closed. */
    val resetToken: Int = 0,
)

interface HomeActions {
    fun open(e: AppEntry)
    /** Open [left] and [right] side by side. */
    fun startSplit(left: AppEntry, right: AppEntry)
    /** Start the sleep timer for [minutes], or switch it off (null). */
    fun setSleep(minutes: Int?)
    /** Hide an app from the row (hold-OK menu). */
    fun hide(e: AppEntry)
    /** Move an app [delta] places in the row (hold-OK menu, Move). */
    fun move(e: AppEntry, delta: Int)
    fun unhide(e: AppEntry)
    fun setWallpaper(w: Wallpaper)
    fun setSleepDefault(minutes: Int)
    fun tab(tab: Tab)
    /** Open a web page (a headline) in the TV's browser. */
    fun openUrl(url: String)
    /** The TV's own picture and sound settings. */
    fun openDisplaySound()
}
