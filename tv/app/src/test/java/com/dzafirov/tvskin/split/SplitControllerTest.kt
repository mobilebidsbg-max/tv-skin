package com.dzafirov.tvskin.split

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppEntry.Kind
import com.dzafirov.tvskin.shell.Shell
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pretends to be the TV: windowed launches create tasks (ids from 100), `stack remove` deletes them. */
class FakeShell : Shell {
    val log = mutableListOf<String>()
    val tasks = linkedMapOf<String, Int>() // package -> task id
    private var nextId = 100

    override suspend fun run(cmd: String): String {
        log += cmd
        Regex("""--windowingMode 5 .* -n ([\w.]+)/""").find(cmd)?.let { m -> tasks.getOrPut(m.groupValues[1]) { nextId++ } }
        Regex("""stack remove (\d+)""").find(cmd)?.let { m -> tasks.values.remove(m.groupValues[1].toInt()) }
        if (cmd == SplitCommands.LIST) return tasks.entries.joinToString("\n") { (pkg, id) -> "  taskId=$id: $pkg/$pkg.Main bounds=[0,0][1,1]" }
        return ""
    }
}

class SplitControllerTest {
    private val yt = AppEntry("com.google.android.youtube.tv", "YouTube", Kind.APP)
    private val web = AppEntry("com.internet.tvbrowser", "Browser", Kind.APP)
    private fun comp(e: AppEntry) = "${e.id}/${e.id}.Main"
    private val shell = FakeShell()
    private val c = SplitController(shell, componentOf = ::comp, pause = {})

    private fun actions() = shell.log.filter { it != SplitCommands.LIST }

    @Test
    fun `start opens both windows, gives the left one control and mutes the right`() = runBlocking {
        assertTrue(c.start(yt, web))
        assertEquals(
            listOf(
                SplitCommands.launchWindowed(comp(yt)), SplitCommands.resize(100, paneBounds(Ratio.HALF, 0)),
                SplitCommands.launchWindowed(comp(web)), SplitCommands.resize(101, paneBounds(Ratio.HALF, 1)),
                SplitCommands.unmute(yt.id), SplitCommands.mute(web.id), SplitCommands.bringToFront(comp(yt)),
            ),
            actions(),
        )
        assertEquals(yt, c.state.value?.controlled)
    }

    @Test
    fun `control moves sound and focus to the other side`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.control(Side.RIGHT)
        assertEquals(
            listOf(
                SplitCommands.resize(100, paneBounds(Ratio.HALF, 0)), SplitCommands.resize(101, paneBounds(Ratio.HALF, 1)),
                SplitCommands.unmute(web.id), SplitCommands.mute(yt.id), SplitCommands.bringToFront(comp(web)),
            ),
            actions(),
        )
    }

    @Test
    fun `swap and 70-30 move the windows`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        c.swap()
        assertTrue(SplitCommands.resize(101, paneBounds(Ratio.HALF, 0)) in actions())
        assertTrue(SplitCommands.resize(100, paneBounds(Ratio.HALF, 1)) in actions())
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
                SplitCommands.resize(100, FULL_SCREEN), SplitCommands.remove(101), SplitCommands.bringToFront(comp(yt)),
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
            listOf(SplitCommands.unmute(yt.id), SplitCommands.unmute(web.id), SplitCommands.resize(100, FULL_SCREEN), SplitCommands.resize(101, FULL_SCREEN)),
            actions(),
        )
        assertNull(c.state.value)
    }

    @Test
    fun `an app that closes ends side by side, the other one goes full screen`() = runBlocking {
        c.start(yt, web); shell.log.clear()
        shell.tasks.remove(web.id)
        c.check()
        assertEquals(listOf(SplitCommands.unmute(yt.id), SplitCommands.unmute(web.id), SplitCommands.resize(100, FULL_SCREEN), SplitCommands.bringToFront(comp(yt))), actions())
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
}
