package com.dzafirov.tvskin.widgets

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.net.HttpURLConnection
import java.net.URL

/** Air quality in Sofia now: the European AQI and PM2.5 (µg/m³). */
data class AirNow(val aqi: Int, val pm25: Double)

/** `current` from an Open-Meteo air-quality response, or null on any problem. */
fun parseAir(json: String): AirNow? = runCatching {
    val current = org.json.JSONObject(json).getJSONObject("current")
    AirNow(Math.round(current.getDouble("european_aqi")).toInt(), current.getDouble("pm2_5"))
}.getOrNull()

/** The European AQI bands in plain words. */
fun airVerdict(aqi: Int): String = when {
    aqi <= 20 -> "Good"
    aqi <= 40 -> "Fair"
    aqi <= 60 -> "Moderate"
    aqi <= 80 -> "Poor"
    aqi <= 100 -> "Very poor"
    else -> "Extremely poor"
}

/** What to do about it: Sofia's winter smog makes this the useful part. */
fun airTip(aqi: Int): String = when {
    aqi <= 40 -> "Good time to air the room"
    aqi <= 60 -> "Air the room briefly"
    else -> "Keep the windows closed"
}

/** The dot colour for the verdict (ARGB). */
fun airColor(aqi: Int): Long = when {
    aqi <= 20 -> 0xFF50D890
    aqi <= 40 -> 0xFFB4DC5A
    aqi <= 60 -> 0xFFFFD60A
    aqi <= 80 -> 0xFFFF9F0A
    aqi <= 100 -> 0xFFFF453A
    else -> 0xFFBF5AF2
}

/** Air quality for Sofia from Open-Meteo (no key). Cached 30 minutes; keeps the last value on failure. */
class AirRepository(private val clock: () -> Long = System::currentTimeMillis) {
    private var cached: AirNow? = null
    private var fetchedAt = 0L

    suspend fun now(): AirNow? {
        cached?.let { if (clock() - fetchedAt < 30 * 60_000L) return it }
        val json = withContext(Dispatchers.IO) { runCatching { fetch(URL_SOFIA) }.getOrNull() } ?: return cached
        return (parseAir(json) ?: return cached).also { cached = it; fetchedAt = clock() }
    }

    companion object {
        const val URL_SOFIA = "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=42.6977&longitude=23.3219" +
            "&current=european_aqi,pm2_5,pm10&timezone=Europe%2FSofia"
    }
}

internal fun fetch(url: String, userAgent: String? = null): String {
    val connection = URL(url).openConnection() as HttpURLConnection
    connection.connectTimeout = 5_000
    connection.readTimeout = 5_000
    userAgent?.let { connection.setRequestProperty("User-Agent", it) }
    return try {
        connection.inputStream.bufferedReader().use { it.readText() }
    } finally {
        connection.disconnect()
    }
}
