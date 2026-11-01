package com.dzafirov.tvskin.split

import android.view.KeyEvent.ACTION_DOWN
import android.view.KeyEvent.ACTION_UP
import android.view.KeyEvent.KEYCODE_BACK
import android.view.KeyEvent.KEYCODE_DPAD_CENTER
import android.view.KeyEvent.KEYCODE_DPAD_LEFT
import android.view.KeyEvent.KEYCODE_DPAD_RIGHT
import android.view.KeyEvent.KEYCODE_DPAD_UP
import android.view.KeyEvent.KEYCODE_HOME
import android.view.KeyEvent.KEYCODE_VOLUME_UP
import com.dzafirov.tvskin.split.KeyAction.ACTIVATE
import com.dzafirov.tvskin.split.KeyAction.CLOSE_BAR
import com.dzafirov.tvskin.split.KeyAction.NEXT
import com.dzafirov.tvskin.split.KeyAction.NONE
import com.dzafirov.tvskin.split.KeyAction.OPEN_BAR
import com.dzafirov.tvskin.split.KeyAction.PREVIOUS
import org.junit.Assert.assertEquals
import org.junit.Test

class SplitKeyRouterTest {
    private fun r(active: Boolean, bar: Boolean, key: Int, action: Int) = routeKey(active, bar, key, action)

    @Test
    fun `without side by side every key goes to the apps`() {
        assertEquals(Routed(false, NONE), r(false, false, KEYCODE_HOME, ACTION_DOWN))
        assertEquals(Routed(false, NONE), r(false, false, KEYCODE_DPAD_CENTER, ACTION_UP))
    }

    @Test
    fun `Home opens the bar on release and never reaches the system`() {
        assertEquals(Routed(true, NONE), r(true, false, KEYCODE_HOME, ACTION_DOWN))
        assertEquals(Routed(true, OPEN_BAR), r(true, false, KEYCODE_HOME, ACTION_UP))
    }

    @Test
    fun `with the bar closed, the app in control gets the other keys`() {
        assertEquals(Routed(false, NONE), r(true, false, KEYCODE_DPAD_LEFT, ACTION_DOWN))
        assertEquals(Routed(false, NONE), r(true, false, KEYCODE_BACK, ACTION_UP))
    }

    @Test
    fun `with the bar open, the bar takes the arrows, OK, Back and Home`() {
        assertEquals(Routed(true, PREVIOUS), r(true, true, KEYCODE_DPAD_LEFT, ACTION_DOWN))
        assertEquals(Routed(true, NEXT), r(true, true, KEYCODE_DPAD_RIGHT, ACTION_DOWN))
        assertEquals(Routed(true, NONE), r(true, true, KEYCODE_DPAD_RIGHT, ACTION_UP))
        assertEquals(Routed(true, NONE), r(true, true, KEYCODE_DPAD_CENTER, ACTION_DOWN))
        assertEquals(Routed(true, ACTIVATE), r(true, true, KEYCODE_DPAD_CENTER, ACTION_UP))
        assertEquals(Routed(true, CLOSE_BAR), r(true, true, KEYCODE_BACK, ACTION_UP))
        assertEquals(Routed(true, CLOSE_BAR), r(true, true, KEYCODE_HOME, ACTION_UP))
        assertEquals(Routed(true, NONE), r(true, true, KEYCODE_DPAD_UP, ACTION_DOWN))
    }

    @Test
    fun `volume always goes through`() {
        assertEquals(Routed(false, NONE), r(true, true, KEYCODE_VOLUME_UP, ACTION_DOWN))
    }
}
