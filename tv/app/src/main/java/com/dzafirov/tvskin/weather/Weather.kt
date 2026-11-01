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

/** Plain words for a WMO weather code, as the home screen and screensaver show them. */
fun describe(code: Int): String = when (code) {
    0 -> "clear"
    1, 2, 3 -> "partly cloudy"
    45, 48 -> "fog"
    in 51..67 -> "rain"
    in 71..77 -> "snow"
    in 80..82 -> "showers"
    in 95..99 -> "storms"
    else -> "cloudy"
}

/** `current` from an Open-Meteo forecast response, or null on any problem. */
fun parseOpenMeteo(json: String): WeatherNow? = runCatching {
    val current = org.json.JSONObject(json).getJSONObject("current")
    val code = current.getInt("weather_code")
    WeatherNow(Math.round(current.getDouble("temperature_2m")).toInt(), describe(code), code)
}.getOrNull()

/** `hourly` from an Open-Meteo response, in time order; empty on any problem. */
fun parseHours(json: String): List<HourWeather> = runCatching {
    val hourly = org.json.JSONObject(json).getJSONObject("hourly")
    val times = hourly.getJSONArray("time")
    val temps = hourly.getJSONArray("temperature_2m")
    val codes = hourly.getJSONArray("weather_code")
    (0 until times.length()).map { i ->
        val hour = times.getString(i).substringAfter('T').substringBefore(':').toInt()
        HourWeather(hour, Math.round(temps.getDouble(i)).toInt(), codes.getInt(i))
    }
}.getOrDefault(emptyList())
