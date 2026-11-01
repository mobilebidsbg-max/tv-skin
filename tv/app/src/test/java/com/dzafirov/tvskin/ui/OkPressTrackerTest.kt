package com.dzafirov.tvskin.ui

import com.dzafirov.tvskin.ui.OkPressTracker.Action
import org.junit.Assert.assertEquals
import org.junit.Test

class OkPressTrackerTest {
    @Test
    fun `a short press clicks`() {
        val t = OkPressTracker()
        assertEquals(Action.NONE, t.down(repeatCount = 0))
        assertEquals(Action.CLICK, t.up(downTime = 1_000, eventTime = 1_120))
    }

    @Test
    fun `a hold without repeats (the phone remote) opens the menu on release`() {
        val t = OkPressTracker()
        t.down(repeatCount = 0)
        assertEquals(Action.HOLD, t.up(downTime = 1_000, eventTime = 2_050))
    }

    @Test
    fun `a hold with repeats (the TV remote) opens the menu while held, and the release does nothing`() {
        val t = OkPressTracker()
        t.down(repeatCount = 0)
        assertEquals(Action.HOLD, t.down(repeatCount = 1))
        assertEquals(Action.NONE, t.down(repeatCount = 2))
        assertEquals(Action.NONE, t.up(downTime = 1_000, eventTime = 2_000))
    }

    @Test
    fun `a release without a press does nothing`() {
        assertEquals(Action.NONE, OkPressTracker().up(downTime = 1_000, eventTime = 1_050))
    }
}
