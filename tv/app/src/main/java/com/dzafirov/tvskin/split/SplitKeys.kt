package com.dzafirov.tvskin.split

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import android.view.KeyEvent
import android.view.accessibility.AccessibilityEvent
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.shell.AdbShell
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

enum class KeyAction { NONE, OPEN_BAR, CLOSE_BAR, PREVIOUS, NEXT, ACTIVATE }

/** Whether the key is kept from the apps ([consume]) and what it does to the side-by-side bar. */
data class Routed(val consume: Boolean, val action: KeyAction)

/**
 * Keys while side by side is on. Home opens the control bar instead of leaving. While the bar is open it takes
 * the arrows, OK, Back and Home (the apps get nothing); otherwise the app in control gets every key but Home.
 */
fun routeKey(splitActive: Boolean, barOpen: Boolean, keyCode: Int, action: Int): Routed {
    if (!splitActive) return Routed(false, KeyAction.NONE)
    val up = action == KeyEvent.ACTION_UP
    val down = action == KeyEvent.ACTION_DOWN
    if (!barOpen) {
        return if (keyCode == KeyEvent.KEYCODE_HOME) Routed(true, if (up) KeyAction.OPEN_BAR else KeyAction.NONE)
        else Routed(false, KeyAction.NONE)
    }
    return when (keyCode) {
        KeyEvent.KEYCODE_DPAD_LEFT -> Routed(true, if (down) KeyAction.PREVIOUS else KeyAction.NONE)
        KeyEvent.KEYCODE_DPAD_RIGHT -> Routed(true, if (down) KeyAction.NEXT else KeyAction.NONE)
        KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER ->
            Routed(true, if (up) KeyAction.ACTIVATE else KeyAction.NONE)
        KeyEvent.KEYCODE_BACK, KeyEvent.KEYCODE_HOME -> Routed(true, if (up) KeyAction.CLOSE_BAR else KeyAction.NONE)
        KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN -> Routed(true, KeyAction.NONE)
        else -> Routed(false, KeyAction.NONE)
    }
}

/** The one side-by-side controller in the app, shared by the home screen and [SplitKeys]. */
object SplitHub {
    private var controller: SplitController? = null
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var poll: Job? = null

    @Synchronized
    fun get(context: Context): SplitController = controller ?: run {
        val app = context.applicationContext
        SplitController(AdbShell(app), componentOf = { componentOf(app.packageManager, it) }).also { controller = it }
    }

    fun peek(): SplitController? = controller

    /** While side by side is on, check every 3 s whether one of the apps was closed. */
    fun watch(c: SplitController) {
        poll?.cancel()
        poll = scope.launch {
            while (isActive && c.state.value != null) {
                delay(3_000)
                runCatching { c.check() }
            }
        }
    }

    private fun componentOf(pm: PackageManager, e: AppEntry): String? =
        (pm.getLeanbackLaunchIntentForPackage(e.id) ?: pm.getLaunchIntentForPackage(e.id))?.component?.flattenToShortString()
}

/**
 * Sees keys before the apps (switched on once over adb). Does nothing unless side by side is on.
 * Turn on: `settings put secure enabled_accessibility_services com.dzafirov.tvskin/com.dzafirov.tvskin.split.SplitKeys`
 * and `settings put secure accessibility_enabled 1`.
 */
class SplitKeys : AccessibilityService() {
    override fun onKeyEvent(event: KeyEvent): Boolean {
        val c = SplitHub.peek() ?: return false
        val s = c.state.value
        val routed = routeKey(s != null, s?.barOpen == true, event.keyCode, event.action)
        if (s != null) Log.d(TAG, "key ${event.keyCode} action ${event.action} -> $routed")
        when (routed.action) {
            KeyAction.OPEN_BAR -> c.openBar()
            KeyAction.CLOSE_BAR -> c.closeBar()
            KeyAction.PREVIOUS -> c.moveBar(-1)
            KeyAction.NEXT -> c.moveBar(+1)
            KeyAction.ACTIVATE -> SplitHub.scope.launch { runCatching { c.activateBar() } }
            KeyAction.NONE -> Unit
        }
        return routed.consume
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) = Unit
    override fun onInterrupt() = Unit

    private companion object {
        const val TAG = "SplitKeys"
    }
}
