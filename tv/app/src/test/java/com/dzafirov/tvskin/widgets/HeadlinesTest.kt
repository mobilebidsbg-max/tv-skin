package com.dzafirov.tvskin.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class HeadlinesTest {
    private fun res(name: String) = javaClass.classLoader!!.getResource(name)!!.readText()

    @Test
    fun `parse an Atom feed (The Verge)`() {
        val items = parseFeed(res("verge-atom.xml"))
        assertEquals(3, items.size)
        assertEquals("NASA hopes the commercial space industry can help save Hubble", items[0].title)
        assertEquals("The Verge", items[0].source)
        assertTrue(items[0].link.startsWith("https://www.theverge.com/science/1024239"))
    }

    @Test
    fun `parse an RSS feed (TechCrunch)`() {
        val items = parseFeed(res("techcrunch-rss.xml"))
        assertEquals(3, items.size)
        assertEquals("AI can make tech CEOs’ lives easier. What about everyone else?", items[0].title)
        assertEquals("TechCrunch", items[0].source)
    }

    @Test
    fun `latest merges feeds, newest first`() {
        val merged = latestHeadlines(listOf(parseFeed(res("verge-atom.xml")), parseFeed(res("techcrunch-rss.xml"))), count = 3)
        assertEquals(
            listOf(
                "NASA hopes the commercial space industry can help save Hubble",
                "AI can make tech CEOs’ lives easier. What about everyone else?",
                "Flock keeps ignoring requests to cancel its contracts",
            ),
            merged.map { it.title },
        )
    }

    @Test
    fun `a broken feed gives nothing`() {
        assertTrue(parseFeed("<rss").isEmpty())
        assertTrue(parseFeed("<!DOCTYPE html><html></html>").isEmpty())
    }
}
