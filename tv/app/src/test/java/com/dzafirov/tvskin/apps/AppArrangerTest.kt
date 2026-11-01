package com.dzafirov.tvskin.apps

import com.dzafirov.tvskin.apps.AppEntry.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppArrangerTest {
    private fun app(id: String, label: String = id) = AppEntry(id, label, Kind.APP)

    @Test
    fun `arrange follows order then label`() {
        val installed = listOf(app("a", "A"), app("b", "B"), app("c", "C"))
        assertEquals(listOf("b", "a", "c"), AppArranger.arrange(installed, order = listOf("b", "a"), hidden = emptySet()).map { it.id })
    }

    @Test
    fun `apps not in the order are sorted by label ignoring case`() {
        val installed = listOf(app("z", "zebra"), app("y", "Apple"), app("x", "banana"))
        assertEquals(listOf("y", "x", "z"), AppArranger.arrange(installed, order = emptyList(), hidden = emptySet()).map { it.id })
    }

    @Test
    fun `arrange drops missing and appends new apps`() {
        val installed = listOf(app("a"), app("z"))
        assertEquals(listOf("a", "z"), AppArranger.arrange(installed, order = listOf("x", "a"), hidden = emptySet()).map { it.id })
    }

    @Test
    fun `arrange removes hidden`() {
        val installed = listOf(app("a"), app("b"))
        assertEquals(listOf("b"), AppArranger.arrange(installed, order = listOf("a", "b"), hidden = setOf("a")).map { it.id })
    }

    @Test
    fun `default hidden covers tcl bloat but not live tv`() {
        assertTrue(AppArranger.isHiddenByDefault("com.tcl.dashboard"))
        assertTrue(AppArranger.isHiddenByDefault("com.tcl.waterfall.overseas"))
        assertTrue(AppArranger.isHiddenByDefault("com.iqiyi.i18n.tv"))
        assertTrue(AppArranger.isHiddenByDefault("xploretv.android.tv"))
        assertTrue(AppArranger.isHiddenByDefault("com.android.tv.settings"))
        assertFalse(AppArranger.isHiddenByDefault("com.tcl.tv"))
        assertFalse(AppArranger.isHiddenByDefault("com.google.android.youtube.tv"))
    }

    @Test
    fun `move clamps at the ends`() {
        assertEquals(listOf("a", "b", "c"), AppArranger.move(listOf("a", "b", "c"), "a", -1))
        assertEquals(listOf("b", "a", "c"), AppArranger.move(listOf("a", "b", "c"), "a", +1))
        assertEquals(listOf("a", "b", "c"), AppArranger.move(listOf("a", "b", "c"), "c", +1))
    }

    @Test
    fun `move adds an app missing from the order at the end first`() {
        assertEquals(listOf("a", "n", "b"), AppArranger.move(listOf("a", "b"), "n", -1))
    }

    @Test
    fun `default order starts with YouTube, Netflix and HBO Max`() {
        assertEquals(listOf("com.google.android.youtube.tv", "com.netflix.ninja", "com.wbd.stream"), AppArranger.DEFAULT_ORDER.take(3))
    }
}
