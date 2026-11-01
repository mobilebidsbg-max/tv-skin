package com.dzafirov.tvskin.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AirTest {
    /** A real Open-Meteo air-quality response for Sofia, 2026-11-01 23:00. */
    private val fixture = javaClass.classLoader!!.getResource("open-meteo-air-sofia.json")!!.readText()

    @Test
    fun `parse current air quality`() {
        assertEquals(AirNow(aqi = 47, pm25 = 26.8), parseAir(fixture))
    }

    @Test
    fun `parse returns null on bad json`() {
        assertNull(parseAir("{"))
        assertNull(parseAir("{}"))
    }

    @Test
    fun `verdict follows the European AQI bands`() {
        assertEquals("Good", airVerdict(15))
        assertEquals("Fair", airVerdict(30))
        assertEquals("Moderate", airVerdict(47))
        assertEquals("Poor", airVerdict(70))
        assertEquals("Very poor", airVerdict(90))
        assertEquals("Extremely poor", airVerdict(120))
    }

    @Test
    fun `tip says whether to air the room`() {
        assertEquals("Good time to air the room", airTip(30))
        assertEquals("Air the room briefly", airTip(47))
        assertEquals("Keep the windows closed", airTip(70))
    }
}
