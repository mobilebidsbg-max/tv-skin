package com.dzafirov.tvskin.split

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.shell.Shell
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Side by side on the TV: two apps in free-form windows (see plan 2 for the commands, all checked on the TV).
 * [componentOf] gives an app's TV launch component; [pause] waits between steps (no-op in tests).
 */
class SplitController(
    private val shell: Shell,
    private val componentOf: (AppEntry) -> String?,
    private val pause: suspend (Long) -> Unit = { delay(it) },
) {
    private val _state = MutableStateFlow<SplitState?>(null)
    val state: StateFlow<SplitState?> = _state
    private val taskIds = mutableMapOf<String, Int>()

    /** Opens [left] and [right] in windows; the left one gets control and sound. False if something failed. */
    suspend fun start(left: AppEntry, right: AppEntry): Boolean {
        val s = SplitState.start(left, right)
        taskIds.clear()
        for (app in listOf(left, right)) {
            val component = componentOf(app) ?: return false
            shell.run(SplitCommands.launchWindowed(component))
            waitForTask(app.id) ?: return false
        }
        // Some apps (YouTube) open a short-lived first screen and move to their real window a moment later.
        pause(SETTLE_MS)
        val list = shell.run(SplitCommands.LIST)
        for (app in listOf(left, right)) {
            val id = taskIdFor(app.id, list) ?: return false
            taskIds[app.id] = id
            shell.run(SplitCommands.resize(id, s.boundsOf(app)))
        }
        _state.value = s
        applySound(s)
        return true
    }

    /** Give [side] control and sound; the other side keeps playing silently. */
    suspend fun control(side: Side) = update { it.control(side) }

    suspend fun swap() = update { it.swap() }
    suspend fun ratio(r: Ratio) = update { it.withRatio(r) }
    suspend fun full() = update { it.toggleFull() }

    /** End: the app in control stays, full screen; the other one is closed. */
    suspend fun end() {
        val s = _state.value ?: return
        restoreSound(s)
        id(s.controlled)?.let { shell.run(SplitCommands.resize(it, FULL_SCREEN)) }
        id(s.other)?.let { shell.run(SplitCommands.remove(it)) }
        shell.run(SplitCommands.tap(FULL_SCREEN))
        _state.value = null
    }

    /** Left with Home: both apps keep running, full size, with their sound back. */
    suspend fun leave() {
        val s = _state.value ?: return
        restoreSound(s)
        listOf(s.left, s.right).forEach { app -> id(app)?.let { shell.run(SplitCommands.resize(it, FULL_SCREEN)) } }
        _state.value = null
    }

    /**
     * Polling: a window that moved or reopened in a new task is put back in its pane; if one of the apps was
     * closed, the other goes full screen and side by side ends.
     */
    suspend fun check() {
        val s = _state.value ?: return
        val list = shell.run(SplitCommands.LIST)
        val alive = listOf(s.left, s.right).filter { taskIdFor(it.id, list) != null }
        if (alive.size == 2) {
            for (app in alive) {
                val id = taskIdFor(app.id, list)!!
                taskIds[app.id] = id
                val want = s.boundsOf(app)
                if (boundsFor(id, list) != want) shell.run(SplitCommands.resize(id, want))
            }
            return
        }
        restoreSound(s)
        alive.firstOrNull()?.let { app ->
            val id = taskIdFor(app.id, list)!!
            shell.run(SplitCommands.resize(id, FULL_SCREEN))
            shell.run(SplitCommands.tap(FULL_SCREEN))
        }
        _state.value = null
    }

    fun openBar() { _state.value = _state.value?.openBar() }
    fun closeBar() { _state.value = _state.value?.closeBar() }
    fun moveBar(delta: Int) { _state.value = _state.value?.moveBar(delta) }

    /** OK on the bar: do what the highlighted item says, then close the bar. */
    suspend fun activateBar() {
        val s = _state.value ?: return
        _state.value = s.closeBar()
        when (s.barItem) {
            BarItem.LEFT -> control(Side.LEFT)
            BarItem.RIGHT -> control(Side.RIGHT)
            BarItem.SWAP -> swap()
            BarItem.HALF -> ratio(Ratio.HALF)
            BarItem.WIDE -> ratio(Ratio.WIDE)
            BarItem.FULL -> full()
            BarItem.END -> end()
        }
    }

    private suspend fun update(change: (SplitState) -> SplitState) {
        val s = change(_state.value ?: return)
        _state.value = s
        listOf(s.left, s.right).forEach { app -> id(app)?.let { shell.run(SplitCommands.resize(it, s.boundsOf(app))) } }
        applySound(s)
    }

    private suspend fun applySound(s: SplitState) {
        shell.run(SplitCommands.unmute(s.controlled.id))
        shell.run(SplitCommands.mute(s.other.id))
        shell.run(SplitCommands.tap(s.boundsOf(s.controlled)))
    }

    private suspend fun restoreSound(s: SplitState) {
        shell.run(SplitCommands.unmute(s.controlled.id))
        shell.run(SplitCommands.unmute(s.other.id))
    }

    private fun id(app: AppEntry) = taskIds[app.id]

    private companion object {
        const val SETTLE_MS = 2_500L
    }

    private suspend fun waitForTask(pkg: String): Int? {
        repeat(20) {
            taskIdFor(pkg, shell.run(SplitCommands.LIST))?.let { return it }
            pause(250)
        }
        return null
    }
}
