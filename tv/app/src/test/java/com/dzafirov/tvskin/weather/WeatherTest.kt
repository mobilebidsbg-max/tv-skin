package com.dzafirov.tvskin.weather

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class WeatherTest {
    /** A real Open-Meteo response for Sofia, 2026-11-01 22:15 (light rain). */
    private val fixture = javaClass.classLoader!!.getResource("open-meteo-sofia.json")!!.readText()

    @Test
    fun `parse current weather`() {
        assertEquals(WeatherNow(9, "rain", 61), parseOpenMeteo(fixture))
    }

    @Test
    fun `parse returns null on bad json`() {
        assertNull(parseOpenMeteo("{"))
        assertNull(parseOpenMeteo("{}"))
        assertNull(parseOpenMeteo("""{"current":{"temperature_2m":"warm"}}"""))
    }

    @Test
    fun `parse next hours`() {
        val hours = parseHours(fixture)
        assertEquals(5, hours.size)
        assertEquals(listOf(22, 23, 0, 1, 2), hours.map { it.hour })
        assertEquals(listOf(3, 61, 3, 61, 61), hours.map { it.code })
        assertEquals(9, hours.first().tempC)
    }

    @Test
    fun `parse hours returns empty on bad json`() {
        assertTrue(parseHours("{").isEmpty())
        assertTrue(parseHours("""{"hourly":{"time":["x"]}}""").isEmpty())
    }

    @Test
    fun `describe codes`() {
        assertEquals("clear", describe(0))
        assertEquals("partly cloudy", describe(2))
        assertEquals("fog", describe(45))
        assertEquals("rain", describe(63))
        assertEquals("snow", describe(73))
        assertEquals("showers", describe(81))
        assertEquals("storms", describe(95))
        assertEquals("cloudy", describe(4))
    }
}
