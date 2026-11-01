package com.dzafirov.tvskin.ui

import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type

/** The keys that mean OK on a TV remote. */
val OK_KEYS = setOf(Key.DirectionCenter, Key.Enter, Key.NumPadEnter)

/**
 * Tells a short OK press from a hold, as remotes really send them:
 * - the TV's own remote sends DOWN, repeated DOWNs while held, then UP: the hold counts at the first repeat;
 * - the phone remote (Android TV Remote protocol) sends DOWN and, a second later, UP with no repeats: the hold
 *   counts from the press length.
 * An UP whose DOWN wasn't seen here (e.g. the press that ended Move mode) does nothing.
 */
class OkPressTracker(private val holdMillis: Long = HOLD_MS) {
    enum class Action { NONE, CLICK, HOLD }

    private var down = false
    private var held = false

    fun down(repeatCount: Int): Action {
        if (repeatCount == 0) {
            down = true
            held = false
            return Action.NONE
        }
        if (down && !held) {
            held = true
            return Action.HOLD
        }
        return Action.NONE
    }

    fun up(downTime: Long, eventTime: Long): Action {
        val action = when {
            !down || held -> Action.NONE
            eventTime - downTime >= holdMillis -> Action.HOLD
            else -> Action.CLICK
        }
        down = false
        held = false
        return action
    }

    companion object {
        const val HOLD_MS = 500L
    }
}

/**
 * OK handling for a tile: a short press calls [onClick], a hold calls [onHold] (see [OkPressTracker]). Other keys,
 * and clicks from accessibility, still go to the Surface underneath.
 */
fun Modifier.okPress(onClick: () -> Unit, onHold: () -> Unit): Modifier = composed {
    val tracker = remember { OkPressTracker() }
    onPreviewKeyEvent { e ->
        if (e.key !in OK_KEYS) return@onPreviewKeyEvent false
        val native = e.nativeKeyEvent
        val action = when (e.type) {
            KeyEventType.KeyDown -> tracker.down(native.repeatCount)
            KeyEventType.KeyUp -> tracker.up(native.downTime, native.eventTime)
            else -> return@onPreviewKeyEvent false
        }
        when (action) {
            OkPressTracker.Action.CLICK -> onClick()
            OkPressTracker.Action.HOLD -> onHold()
            OkPressTracker.Action.NONE -> Unit
        }
        true
    }
}
