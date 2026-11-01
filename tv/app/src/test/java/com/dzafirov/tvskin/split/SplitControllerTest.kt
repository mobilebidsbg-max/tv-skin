package com.dzafirov.tvskin.split

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppEntry.Kind
import com.dzafirov.tvskin.shell.Shell
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Pretends to be the TV: windowed launches create tasks (ids from 100), `stack remove` deletes them. Packages in
 * [trampolines] hand over to a new task when the launcher waits ([settle]), like YouTube does.
 */
class FakeShell(private val trampolines: Set<String> = emptySet()) : Shell {
    val log = mutableListOf<String>()
    val tasks = linkedMapOf<String, Int>() // package -> task id
    val bounds = mutableMapOf<Int, PxRect>()
    private var nextId = 100

    fun settle() {
        trampolines.filter { it in tasks }.forEach { tasks[it] = nextId++ }
    }

    override suspend fun run(cmd: String): String {
        log += cmd
        Regex("""--windowingMode 5 .* -n ([\w.]+)/""").find(cmd)?.let { m -> tasks.getOrPut(m.groupValues[1]) { nextId++ } }
        Regex("""stack remove (\d+)""").find(cmd)?.let { m -> tasks.values.remove(m.groupValues[1].toInt()) }
        Regex("""task resize (\d+) (\d+) (\d+) (\d+) (\d+)""").find(cmd)?.let { m ->
            val v = m.groupValues.drop(1).map { it.toInt() }
            bounds[v[0]] = PxRect(v[1], v[2], v[3], v[4])
        }
        if (cmd == SplitCommands.LIST) return tasks.entries.joinToString("\n") { (pkg, id) ->
            val b = bounds[id] ?: PxRect(690, 454, 1770, 1061)
            "  taskId=$id: $pkg/$pkg.Main bounds=[${b.left},${b.top}][${b.right},${b.bottom}] userId=0 visible=true"
        }
        return ""
    }
}

class SplitControllerTest {
    private val yt = AppEntry("com.google.android.youtube.tv", "YouTube", Kind.APP)
    private val web = AppEntry("com.internet.tvbrowser", "Browser", Kind.APP)
    private fun comp(e: AppEntry) = "${e.id}/${e.id}.Main"
    private val shell = FakeShell(trampolines = setOf(yt.id))
    private val c = SplitController(shell, componentOf = ::comp, pause = { shell.settle() })

    private fun actions() = shell.log.filter { it != SplitCommands.LIST }

    @Test
    fun `start opens both windows, waits for YouTube's real window, gives the left one control`() = runBlocking {
        assertTrue(c.start(yt, web))
        // YouTube's launch task (100) hands over to 102 while the launcher waits; 102 is the one that gets placed.
        assertEquals(paneBounds(Ratio.HALF, 0), shell.bounds[102])
        assertEquals(paneBounds(Ratio.HALF, 1), shell.bounds[101])
        assertEquals(
            listOf(SplitCommands.unmute(yt.id), SplitCommands.mute(web.id), SplitCommands.tap(paneBounds(Ratio.HALF, 0))),
            actions().takeLast(3),
        )
        assertEquals(yt, c.state.value?.controlled)
    }

    @Test
    fun `the check puts a window that moved back in its pane`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        shell.bounds[101] = PxRect(10, 10, 500, 300)
        c.check()
        assertEquals(listOf(SplitCommands.resize(101, paneBounds(Ratio.HALF, 1))), actions())
    }

    @Test
    fun `control moves sound and focus to the other side`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.control(Side.RIGHT)
        assertEquals(
            listOf(
                SplitCommands.resize(102, paneBounds(Ratio.HALF, 0)), SplitCommands.resize(101, paneBounds(Ratio.HALF, 1)),
                SplitCommands.unmute(web.id), SplitCommands.mute(yt.id), SplitCommands.tap(paneBounds(Ratio.HALF, 1)),
            ),
            actions(),
        )
    }

    @Test
    fun `swap and 70-30 move the windows`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.swap()
        assertTrue(SplitCommands.resize(101, paneBounds(Ratio.HALF, 0)) in actions())
        assertTrue(SplitCommands.resize(102, paneBounds(Ratio.HALF, 1)) in actions())
        shell.log.clear()
        c.ratio(Ratio.WIDE)
        assertTrue(SplitCommands.resize(101, paneBounds(Ratio.WIDE, 0)) in actions())
    }

    @Test
    fun `end keeps the app in control full screen and closes the other`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.end()
        assertEquals(
            listOf(
                SplitCommands.unmute(yt.id), SplitCommands.unmute(web.id),
                SplitCommands.resize(102, FULL_SCREEN), SplitCommands.remove(101), SplitCommands.tap(FULL_SCREEN),
            ),
            actions(),
        )
        assertNull(c.state.value)
    }

    @Test
    fun `leaving with Home restores sound and leaves both apps full size`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.leave()
        assertEquals(
            listOf(SplitCommands.unmute(yt.id), SplitCommands.unmute(web.id), SplitCommands.resize(102, FULL_SCREEN), SplitCommands.resize(101, FULL_SCREEN)),
            actions(),
        )
        assertNull(c.state.value)
    }

    @Test
    fun `an app that closes ends side by side, the other one goes full screen`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        shell.tasks.remove(web.id)
        c.check()
        assertEquals(listOf(SplitCommands.unmute(yt.id), SplitCommands.unmute(web.id), SplitCommands.resize(102, FULL_SCREEN), SplitCommands.tap(FULL_SCREEN)), actions())
        assertNull(c.state.value)
    }

    @Test
    fun `the bar acts on the item it is on`() = runBlocking {
        c.start(yt, web)
        c.openBar(); c.moveBar(+1) // RIGHT
        c.activateBar()
        assertEquals(web, c.state.value?.controlled)
        assertEquals(false, c.state.value?.barOpen)
    }

    @Test
    fun `start switches the key service back on when an update turned it off`() = runBlocking {
        val withKeys = SplitController(shell, componentOf = ::comp, pause = { shell.settle() }, keyService = "a.b/a.b.Keys")
        withKeys.start(yt, web)
        assertEquals(
            listOf(
                "settings get secure enabled_accessibility_services",
                "settings get secure accessibility_enabled",
                "settings put secure enabled_accessibility_services a.b/a.b.Keys",
                "settings put secure accessibility_enabled 1",
            ),
            shell.log.take(4),
        )
    }

    @Test
    fun `start switches accessibility back on when the service is listed but the switch is off`() = runBlocking {
        val tv = object : Shell {
            val log = mutableListOf<String>()
            override suspend fun run(cmd: String): String {
                log += cmd
                return when (cmd) {
                    "settings get secure enabled_accessibility_services" -> "a.b/a.b.Keys"
                    "settings get secure accessibility_enabled" -> "0"
                    else -> shell.run(cmd)
                }
            }
        }
        SplitController(tv, componentOf = ::comp, pause = { shell.settle() }, keyService = "a.b/a.b.Keys").start(yt, web)
        assertTrue("settings put secure accessibility_enabled 1" in tv.log)
    }

    @Test
    fun `left-over small windows from a session that was cut off are made full size`() = runBlocking {
        shell.tasks[yt.id] = 200
        shell.bounds[200] = PxRect(48, 196, 948, 702)
        shell.tasks["com.dzafirov.tvskin"] = 201
        shell.bounds[201] = FULL_SCREEN
        c.tidyUp(ownPackage = "com.dzafirov.tvskin")
        assertEquals(listOf(SplitCommands.resize(200, FULL_SCREEN)), actions())
    }

    @Test
    fun `no tidying while side by side is on`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.tidyUp(ownPackage = "com.dzafirov.tvskin")
        assertTrue(shell.log.isEmpty())
    }
}
