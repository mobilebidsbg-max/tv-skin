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
)

interface HomeActions {
    fun open(e: AppEntry)
    fun sideBySide()
    fun sleep()
    /** Hide an app from the row (hold-OK menu). */
    fun hide(e: AppEntry)
    /** Move an app [delta] places in the row (hold-OK menu, Move). */
    fun move(e: AppEntry, delta: Int)
    fun settings()
    fun tab(tab: Tab)
}
