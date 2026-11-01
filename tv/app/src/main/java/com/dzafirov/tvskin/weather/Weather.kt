package com.dzafirov.tvskin.weather

import androidx.annotation.DrawableRes
import com.dzafirov.tvskin.R

/** The weather now in Sofia. [code] is the WMO weather code (Open-Meteo). */
data class WeatherNow(val tempC: Int, val text: String, val code: Int = 0)

/** One hour of the forecast: [hour] 0-23. */
data class HourWeather(val hour: Int, val tempC: Int, val code: Int)

/** Night is 20:00 to 05:59, when clear skies show a moon. */
fun isNight(hour: Int): Boolean = hour >= 20 || hour < 6

@DrawableRes
fun weatherIcon(code: Int, night: Boolean): Int = when (code) {
    0 -> if (night) R.drawable.wx_moon else R.drawable.wx_sun
    1, 2, 3 -> if (night) R.drawable.wx_cloud else R.drawable.wx_cloudsun
    in 51..67, in 80..82 -> R.drawable.wx_rain
    in 71..77, 85, 86 -> R.drawable.wx_snow
    in 95..99 -> R.drawable.wx_storm
    else -> R.drawable.wx_cloud
}
