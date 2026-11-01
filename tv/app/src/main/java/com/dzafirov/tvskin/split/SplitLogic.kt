package com.dzafirov.tvskin.split

import com.dzafirov.tvskin.apps.AppEntry

/** A window rectangle in the TV's 1920x1080 coordinates (what `am task resize` takes). */
data class PxRect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width get() = right - left
    val height get() = bottom - top
}

enum class Ratio { HALF, WIDE }
enum class Side { LEFT, RIGHT }

val FULL_SCREEN = PxRect(0, 0, 1920, 1080)

/** The two panes of mockup v3: 50/50 side by side, or 70/30 with the small one top right. Both 16:9. */
fun paneBounds(ratio: Ratio, slot: Int): PxRect = when (ratio) {
    Ratio.HALF -> if (slot == 0) PxRect(48, 196, 948, 702) else PxRect(972, 196, 1872, 702)
    Ratio.WIDE -> if (slot == 0) PxRect(48, 118, 1288, 816) else PxRect(1312, 118, 1872, 558) // min height 440 px on this TV
}

/** Shell commands (run through adb on the TV itself). */
object SplitCommands {
    const val LIST = "cmd activity stack list"

    /** The activity dump: the only place that says which tasks are free-form windows. */
    const val WINDOWS = "dumpsys activity activities"

    /** The app's own TV launch intent in a free-form window; launching it again brings that window to the front. */
    fun launchWindowed(component: String) =
        "am start --windowingMode 5 -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER -n $component"

    fun bringToFront(component: String) =
        "am start -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER -n $component"

    /** A tap just inside the window's top-left corner: the TV moves key focus to that window (checked on the TV). */
    fun tap(r: PxRect) = "input tap ${r.left + 4} ${r.top + 4}"

    fun resize(taskId: Int, r: PxRect) = "am task resize $taskId ${r.left} ${r.top} ${r.right} ${r.bottom}"
    fun mute(pkg: String) = "appops set $pkg PLAY_AUDIO ignore"
    fun unmute(pkg: String) = "appops set $pkg PLAY_AUDIO default"
    fun remove(taskId: Int) = "cmd activity stack remove $taskId"
}

private val TASK_LINE = Regex("""taskId=(\d+): ([\w.]+)/\S*(?: bounds=\[(\d+),(\d+)\]\[(\d+),(\d+)\])?""")

/**
 * The task id of [pkg] in `cmd activity stack list` output (exact package match), or null. The newest one wins:
 * apps like YouTube start in one task and hand over to another.
 */
fun taskIdFor(pkg: String, stackList: String): Int? =
    TASK_LINE.findAll(stackList).filter { it.groupValues[2] == pkg }.map { it.groupValues[1].toInt() }.maxOrNull()

private val FREEFORM_TASK = Regex("""\* Task\{\w+ #(\d+) type=standard .* mode=freeform""")

/** The ids of all free-form (windowed) app tasks in `dumpsys activity activities` output. */
fun freeformTaskIds(dump: String): List<Int> =
    FREEFORM_TASK.findAll(dump).map { it.groupValues[1].toInt() }.distinct().toList()

/** The window bounds of task [taskId] in `cmd activity stack list` output. */
fun boundsFor(taskId: Int, stackList: String): PxRect? =
    TASK_LINE.findAll(stackList).firstOrNull { it.groupValues[1].toInt() == taskId && it.groupValues[3].isNotEmpty() }
        ?.groupValues?.let { g -> PxRect(g[3].toInt(), g[4].toInt(), g[5].toInt(), g[6].toInt()) }

enum class BarItem { LEFT, RIGHT, SWAP, HALF, WIDE, FULL, END }

val BAR_ITEMS = BarItem.entries.toList()

/** Side by side: which app is where, which one has control (and sound), the layout, and the control bar. */
data class SplitState(
    val left: AppEntry,
    val right: AppEntry,
    val active: Side = Side.LEFT,
    val ratio: Ratio = Ratio.HALF,
    val full: Boolean = false,
    val barOpen: Boolean = false,
    val barIndex: Int = 0,
) {
    val controlled: AppEntry get() = if (active == Side.LEFT) left else right
    val other: AppEntry get() = if (active == Side.LEFT) right else left
    val barItem: BarItem get() = BAR_ITEMS[barIndex]

    fun swap() = copy(left = right, right = left, active = if (active == Side.LEFT) Side.RIGHT else Side.LEFT)
    fun control(side: Side) = copy(active = side, full = false)
    fun withRatio(r: Ratio) = copy(ratio = r, full = false)
    fun toggleFull() = copy(full = !full)
    fun openBar() = copy(barOpen = true, barIndex = BAR_ITEMS.indexOf(if (active == Side.LEFT) BarItem.LEFT else BarItem.RIGHT))
    fun closeBar() = copy(barOpen = false)
    fun moveBar(delta: Int) = copy(barIndex = (barIndex + delta).coerceIn(0, BAR_ITEMS.lastIndex))

    /** Where [app]'s window goes: its pane, or the whole screen when it is in control and full screen is on. */
    fun boundsOf(app: AppEntry): PxRect {
        if (full && app == controlled) return FULL_SCREEN
        return paneBounds(ratio, if (app == left) 0 else 1)
    }

    companion object {
        fun start(left: AppEntry, right: AppEntry) = SplitState(left, right)
    }
}
