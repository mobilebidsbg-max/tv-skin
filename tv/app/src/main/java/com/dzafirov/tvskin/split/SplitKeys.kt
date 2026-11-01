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

enum class KeyAction { NONE, OPEN_BAR, CLOSE_BAR, PREVIOUS, NEXT, ACTIVATE, BACK }

/** Whether the key is kept from the apps ([consume]) and what it does. */
data class Routed(val consume: Boolean, val action: KeyAction)

/**
 * Keys while side by side is on. Home can't be caught on this TV (the system takes it first), so **holding Back**
 * opens the control bar: at the first repeat (TV remote) or on a release after [holdMillis] (phone remote, which
 * sends no repeats). A short Back is given back to the app ([KeyAction.BACK]). While the bar is open it takes the
 * arrows, OK and Back; the apps get nothing.
 */
class SplitKeyRouter(private val holdMillis: Long = 500) {
    private var backDown = false
    private var openedByHold = false

    fun route(splitActive: Boolean, barOpen: Boolean, keyCode: Int, action: Int, repeatCount: Int, downTime: Long, eventTime: Long): Routed {
        if (!splitActive) {
            backDown = false
            openedByHold = false
            return Routed(false, KeyAction.NONE)
        }
        val down = action == KeyEvent.ACTION_DOWN
        val up = action == KeyEvent.ACTION_UP
        if (keyCode == KeyEvent.KEYCODE_BACK) {
            if (down && repeatCount == 0) {
                backDown = true
                return Routed(true, KeyAction.NONE)
            }
            if (down) {
                if (backDown && !barOpen && !openedByHold) {
                    openedByHold = true
                    return Routed(true, KeyAction.OPEN_BAR)
                }
                return Routed(true, KeyAction.NONE)
            }
            if (up) {
                val wasDown = backDown
                backDown = false
                if (openedByHold) {
                    openedByHold = false
                    return Routed(true, KeyAction.NONE)
                }
                if (!wasDown) return Routed(true, KeyAction.NONE)
                if (barOpen) return Routed(true, KeyAction.CLOSE_BAR)
                return Routed(true, if (eventTime - downTime >= holdMillis) KeyAction.OPEN_BAR else KeyAction.BACK)
            }
            return Routed(true, KeyAction.NONE)
        }
        if (!barOpen) return Routed(false, KeyAction.NONE)
        return when (keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> Routed(true, if (down) KeyAction.PREVIOUS else KeyAction.NONE)
            KeyEvent.KEYCODE_DPAD_RIGHT -> Routed(true, if (down) KeyAction.NEXT else KeyAction.NONE)
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER ->
                Routed(true, if (up) KeyAction.ACTIVATE else KeyAction.NONE)
            KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN -> Routed(true, KeyAction.NONE)
            else -> Routed(false, KeyAction.NONE)
        }
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
 * Sees keys before the apps (switched on once over adb). Does nothing unless side by side is on; then holding
 * Back opens the control bar (see [SplitKeyRouter]).
 * Turn on: `settings put secure enabled_accessibility_services com.dzafirov.tvskin/com.dzafirov.tvskin.split.SplitKeys`
 * and `settings put secure accessibility_enabled 1`.
 */
class SplitKeys : AccessibilityService() {
    private val router = SplitKeyRouter()

    override fun onKeyEvent(event: KeyEvent): Boolean {
        val c = SplitHub.peek() ?: return false
        val s = c.state.value
        val routed = router.route(s != null, s?.barOpen == true, event.keyCode, event.action, event.repeatCount, event.downTime, event.eventTime)
        if (s != null) Log.d(TAG, "key ${event.keyCode} action ${event.action} -> $routed")
        when (routed.action) {
            KeyAction.OPEN_BAR -> c.openBar()
            KeyAction.CLOSE_BAR -> c.closeBar()
            KeyAction.PREVIOUS -> c.moveBar(-1)
            KeyAction.NEXT -> c.moveBar(+1)
            KeyAction.ACTIVATE -> SplitHub.scope.launch { runCatching { c.activateBar() } }
            KeyAction.BACK -> performGlobalAction(GLOBAL_ACTION_BACK)
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
