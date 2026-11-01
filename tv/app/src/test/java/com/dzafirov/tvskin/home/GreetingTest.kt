package com.dzafirov.tvskin.home

import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.weather.WeatherNow
import org.junit.Assert.assertEquals
import org.junit.Test

class GreetingTest {
    @Test
    fun `greeting by hour`() {
        assertEquals(R.string.greeting_morning, greetingFor(7))
        assertEquals(R.string.greeting_morning, greetingFor(5))
        assertEquals(R.string.greeting_afternoon, greetingFor(13))
        assertEquals(R.string.greeting_evening, greetingFor(21))
        assertEquals(R.string.greeting_evening, greetingFor(2))
    }

    @Test
    fun `statusLine without weather`() {
        assertEquals("Sun 1 Nov · 21:40", statusLine(null, "Sun 1 Nov", "21:40"))
    }

    @Test
    fun `statusLine with weather`() {
        assertEquals("9° · Sun 1 Nov · 21:40", statusLine(WeatherNow(9, "clear"), "Sun 1 Nov", "21:40"))
    }
}
