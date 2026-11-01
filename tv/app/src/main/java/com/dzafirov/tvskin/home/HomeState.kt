package com.dzafirov.tvskin.home

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.Wallpaper
import com.dzafirov.tvskin.weather.HourWeather
import com.dzafirov.tvskin.weather.WeatherNow

/** What is playing right now (filled in plan 2; null hides the pill). */
data class NowPlaying(val title: String, val artist: String)

enum class Tab { ASK, HOME, APPS, MUSIC, PHOTOS, SETTINGS }

data class HomeState(
    val wallpaper: Wallpaper,
    val greeting: String,
    val date: String,
    val time: String,
    val weather: WeatherNow?,
    val hours: List<HourWeather>,
    val nowPlaying: NowPlaying?,
    val lastApp: AppEntry?,
    val lastAppSubtitle: String?,
    val sleepLeftMinutes: Int?,
    val apps: List<AppEntry>,
    val tvItems: List<AppEntry>,
    val promos: List<AppEntry>,
    val hiddenApps: List<AppEntry> = emptyList(),
    val sleepDefaultMinutes: Int = 60,
    val version: String = "",
    /** Bumped when Home is pressed while this screen is already open: back to the home row, menus closed. */
    val resetToken: Int = 0,
)

interface HomeActions {
    fun open(e: AppEntry)
    fun sideBySide()
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
}
