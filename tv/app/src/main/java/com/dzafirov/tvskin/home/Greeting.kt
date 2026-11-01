package com.dzafirov.tvskin.home

import androidx.annotation.StringRes
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.weather.WeatherNow

/** 5-11 morning, 12-17 afternoon, otherwise evening. */
@StringRes
fun greetingFor(hour: Int): Int = when (hour) {
    in 5..11 -> R.string.greeting_morning
    in 12..17 -> R.string.greeting_afternoon
    else -> R.string.greeting_evening
}

/** What the top bar's status reads, e.g. "9° · Sun 1 Nov · 21:40"; without weather just the date and time. */
fun statusLine(weather: WeatherNow?, date: String, time: String): String =
    listOfNotNull(weather?.let { "${it.tempC}°" }, date, time).joinToString(" · ")
