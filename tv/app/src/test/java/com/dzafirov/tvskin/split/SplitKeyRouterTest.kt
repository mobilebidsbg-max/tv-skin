package com.dzafirov.tvskin.split

import android.view.KeyEvent.ACTION_DOWN
import android.view.KeyEvent.ACTION_UP
import android.view.KeyEvent.KEYCODE_BACK
import android.view.KeyEvent.KEYCODE_DPAD_CENTER
import android.view.KeyEvent.KEYCODE_DPAD_LEFT
import android.view.KeyEvent.KEYCODE_DPAD_RIGHT
import android.view.KeyEvent.KEYCODE_DPAD_UP
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import com.dzafirov.tvskin.split.KeyAction.ACTIVATE
import com.dzafirov.tvskin.split.KeyAction.BACK
import com.dzafirov.tvskin.split.KeyAction.CLOSE_BAR
import com.dzafirov.tvskin.split.KeyAction.NEXT
import com.dzafirov.tvskin.split.KeyAction.NONE
import com.dzafirov.tvskin.split.KeyAction.OPEN_BAR
import com.dzafirov.tvskin.split.KeyAction.PREVIOUS
import org.junit.Assert.assertEquals
import org.junit.Test

/** Keys as remotes send them: the TV remote repeats a held key; the phone sends one DOWN and a late UP. */
class SplitKeyRouterTest {
    private val router = SplitKeyRouter()
    private fun key(active: Boolean, bar: Boolean, code: Int, action: Int, repeat: Int = 0, held: Long = 0) =
        router.route(active, bar, code, action, repeat, downTime = 1_000, eventTime = 1_000 + held)

    @Test
    fun `without side by side every key goes to the apps`() {
        assertEquals(Routed(false, NONE), key(false, false, KEYCODE_BACK, ACTION_DOWN))
        assertEquals(Routed(false, NONE), key(false, false, KEYCODE_BACK, ACTION_UP, held = 900))
    }

    @Test
    fun `a short Back still goes back in the app`() {
        assertEquals(Routed(true, NONE), key(true, false, KEYCODE_BACK, ACTION_DOWN))
        assertEquals(Routed(true, BACK), key(true, false, KEYCODE_BACK, ACTION_UP, held = 120))
    }

    @Test
    fun `holding Back on the phone remote opens the bar on release`() {
        key(true, false, KEYCODE_BACK, ACTION_DOWN)
        assertEquals(Routed(true, OPEN_BAR), key(true, false, KEYCODE_BACK, ACTION_UP, held = 1_000))
    }

    @Test
    fun `holding Back on the TV remote opens the bar at the first repeat, and its release does not close it`() {
        key(true, false, KEYCODE_BACK, ACTION_DOWN)
        assertEquals(Routed(true, OPEN_BAR), key(true, false, KEYCODE_BACK, ACTION_DOWN, repeat = 1, held = 450))
        assertEquals(Routed(true, NONE), key(true, true, KEYCODE_BACK, ACTION_DOWN, repeat = 2, held = 500))
        assertEquals(Routed(true, NONE), key(true, true, KEYCODE_BACK, ACTION_UP, held = 700))
        // the next Back closes it
        key(true, true, KEYCODE_BACK, ACTION_DOWN)
        assertEquals(Routed(true, CLOSE_BAR), key(true, true, KEYCODE_BACK, ACTION_UP, held = 100))
    }

    @Test
    fun `with the bar closed the arrows and OK go to the app in control`() {
        assertEquals(Routed(false, NONE), key(true, false, KEYCODE_DPAD_LEFT, ACTION_DOWN))
        assertEquals(Routed(false, NONE), key(true, false, KEYCODE_DPAD_CENTER, ACTION_UP))
    }

    @Test
    fun `with the bar open the bar takes the arrows and OK`() {
        assertEquals(Routed(true, PREVIOUS), key(true, true, KEYCODE_DPAD_LEFT, ACTION_DOWN))
        assertEquals(Routed(true, NEXT), key(true, true, KEYCODE_DPAD_RIGHT, ACTION_DOWN))
        assertEquals(Routed(true, NONE), key(true, true, KEYCODE_DPAD_RIGHT, ACTION_UP))
        assertEquals(Routed(true, NONE), key(true, true, KEYCODE_DPAD_CENTER, ACTION_DOWN))
        assertEquals(Routed(true, ACTIVATE), key(true, true, KEYCODE_DPAD_CENTER, ACTION_UP))
        assertEquals(Routed(true, NONE), key(true, true, KEYCODE_DPAD_UP, ACTION_DOWN))
    }

    @Test
    fun `volume always goes through`() {
        assertEquals(Routed(false, NONE), key(true, true, KEYCODE_VOLUME_UP, ACTION_DOWN))
    }
}
