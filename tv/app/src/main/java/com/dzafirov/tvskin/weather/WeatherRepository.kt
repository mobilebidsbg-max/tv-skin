package com.dzafirov.tvskin.weather

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

data class Forecast(val now: WeatherNow, val hours: List<HourWeather>)

/** Weather for Sofia from Open-Meteo (no key). Cached for 30 minutes; null on any failure, never throws. */
class WeatherRepository(private val clock: () -> Long = System::currentTimeMillis) {
    private var cached: Forecast? = null
    private var fetchedAt = 0L

    suspend fun forecast(): Forecast? {
        cached?.let { if (clock() - fetchedAt < CACHE_MS) return it }
        val json = withContext(Dispatchers.IO) { runCatching { fetch() }.getOrNull() } ?: return cached
        val now = parseOpenMeteo(json) ?: return cached
        return Forecast(now, parseHours(json)).also { cached = it; fetchedAt = clock() }
    }

    private fun fetch(): String {
        val connection = URL(URL_SOFIA).openConnection() as HttpURLConnection
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        return try {
            connection.inputStream.bufferedReader().use { it.readText() }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        private const val CACHE_MS = 30 * 60 * 1000L
        private const val TIMEOUT_MS = 5_000
        const val URL_SOFIA = "https://api.open-meteo.com/v1/forecast?latitude=42.6977&longitude=23.3219" +
            "&current=temperature_2m,weather_code&hourly=temperature_2m,weather_code&forecast_hours=5&timezone=Europe%2FSofia"
    }
}
