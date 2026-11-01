package com.dzafirov.tvskin.sleep

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SleepTimerTest {
    private val now = 1_000_000_000_000L

    @Test
    fun `minutes left rounds up`() {
        val timer = SleepTimer(endsAtMillis = now + 41 * 60_000 + 10_000)
        assertEquals(42, timer.minutesLeft(now))
    }

    @Test
    fun `timer in the past is not running`() {
        assertNull(SleepTimer(endsAtMillis = now - 1).minutesLeft(now))
        assertNull(SleepTimer(endsAtMillis = now).minutesLeft(now))
    }

    @Test
    fun `cancel clears`() {
        assertNull(SleepTimer(null).start(now, 30).cancel().minutesLeft(now))
    }

    @Test
    fun `start sets the end`() {
        assertEquals(now + 30 * 60_000, SleepTimer(null).start(now, 30).endsAtMillis)
        assertEquals(30, SleepTimer(null).start(now, 30).minutesLeft(now))
    }
}
