package com.dzafirov.tvskin.split

import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppEntry.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SplitLogicTest {
    private val yt = AppEntry("com.google.android.youtube.tv", "YouTube", Kind.APP)
    private val web = AppEntry("com.internet.tvbrowser", "Browser", Kind.APP)
    private val stackList = javaClass.classLoader!!.getResource("stack-list-split.txt")!!.readText()

    @Test
    fun `pane bounds follow the v3 layout`() {
        assertEquals(PxRect(48, 196, 948, 702), paneBounds(Ratio.HALF, slot = 0))
        assertEquals(PxRect(972, 196, 1872, 702), paneBounds(Ratio.HALF, slot = 1))
        assertEquals(PxRect(48, 118, 1288, 816), paneBounds(Ratio.WIDE, slot = 0))
        assertEquals(PxRect(1312, 118, 1872, 433), paneBounds(Ratio.WIDE, slot = 1))
        assertEquals(PxRect(0, 0, 1920, 1080), FULL_SCREEN)
    }

    @Test
    fun `commands`() {
        assertEquals(
            "am start --windowingMode 5 -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER -n com.google.android.youtube.tv/com.google.android.apps.youtube.tv.activity.ShellActivity",
            SplitCommands.launchWindowed("com.google.android.youtube.tv/com.google.android.apps.youtube.tv.activity.ShellActivity"),
        )
        assertEquals("am task resize 333 48 196 948 702", SplitCommands.resize(333, PxRect(48, 196, 948, 702)))
        assertEquals("appops set com.internet.tvbrowser PLAY_AUDIO ignore", SplitCommands.mute("com.internet.tvbrowser"))
        assertEquals("appops set com.internet.tvbrowser PLAY_AUDIO default", SplitCommands.unmute("com.internet.tvbrowser"))
        assertEquals("cmd activity stack remove 334", SplitCommands.remove(334))
        assertEquals("cmd activity stack list", SplitCommands.LIST)
    }

    @Test
    fun `task ids are read from the real stack list`() {
        assertEquals(333, taskIdFor("com.google.android.youtube.tv", stackList))
        assertEquals(334, taskIdFor("com.internet.tvbrowser", stackList))
        assertNull(taskIdFor("com.netflix.ninja", stackList))
        assertNull(taskIdFor("com.google.android.youtube", stackList)) // a prefix is not a match
    }

    @Test
    fun `starting controls the left app with the bar closed`() {
        val s = SplitState.start(yt, web)
        assertEquals(yt, s.controlled)
        assertEquals(web, s.other)
        assertEquals(Ratio.HALF, s.ratio)
        assertFalse(s.barOpen)
    }

    @Test
    fun `swap keeps control on the same app`() {
        val s = SplitState.start(yt, web).swap()
        assertEquals(listOf(web, yt), listOf(s.left, s.right))
        assertEquals(yt, s.controlled)
    }

    @Test
    fun `bar items and moving through them`() {
        val s = SplitState.start(yt, web).openBar()
        assertEquals(listOf(BarItem.LEFT, BarItem.RIGHT, BarItem.SWAP, BarItem.HALF, BarItem.WIDE, BarItem.FULL, BarItem.END), BAR_ITEMS)
        assertTrue(s.barOpen)
        assertEquals(BarItem.LEFT, s.barItem) // opens on the side in control
        assertEquals(BarItem.RIGHT, s.moveBar(+1).barItem)
        assertEquals(BarItem.LEFT, s.moveBar(-1).barItem) // clamps at the start
        assertEquals(BarItem.END, s.moveBar(+99).barItem)
        assertFalse(s.closeBar().barOpen)
    }

    @Test
    fun `controlling the right side, ratio and full screen`() {
        val s = SplitState.start(yt, web).control(Side.RIGHT)
        assertEquals(web, s.controlled)
        assertEquals(Ratio.WIDE, s.withRatio(Ratio.WIDE).ratio)
        assertTrue(s.toggleFull().full)
        assertFalse(s.toggleFull().toggleFull().full)
    }

    @Test
    fun `window bounds for each app`() {
        val s = SplitState.start(yt, web)
        assertEquals(paneBounds(Ratio.HALF, 0), s.boundsOf(yt))
        assertEquals(paneBounds(Ratio.HALF, 1), s.boundsOf(web))
        assertEquals(FULL_SCREEN, s.toggleFull().boundsOf(yt)) // full screen enlarges the app in control
        assertEquals(paneBounds(Ratio.HALF, 1), s.toggleFull().boundsOf(web))
    }
}
