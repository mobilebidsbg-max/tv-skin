package com.dzafirov.tvskin.ui

import androidx.compose.runtime.mutableStateOf
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
 * OK handling for a tile, as a remote sends it: a short press (DOWN, UP) calls [onClick]; a hold (DOWN, repeated
 * DOWNs, UP) calls [onHold] when it is released, so the release can't land on whatever the hold opened. An UP whose
 * DOWN this tile didn't see (e.g. the press that ended Move mode) is swallowed.
 */
fun Modifier.okPress(onClick: () -> Unit, onHold: () -> Unit): Modifier = composed {
    val down = remember { mutableStateOf(false) }
    val held = remember { mutableStateOf(false) }
    onPreviewKeyEvent { e ->
        if (e.key !in OK_KEYS) return@onPreviewKeyEvent false
        when (e.type) {
            KeyEventType.KeyDown -> {
                if (e.nativeKeyEvent.repeatCount == 0) {
                    down.value = true
                    held.value = false
                } else if (down.value) {
                    held.value = true
                }
                true
            }
            KeyEventType.KeyUp -> {
                if (down.value) {
                    if (held.value) onHold() else onClick()
                }
                down.value = false
                held.value = false
                true
            }
            else -> false
        }
    }
}
