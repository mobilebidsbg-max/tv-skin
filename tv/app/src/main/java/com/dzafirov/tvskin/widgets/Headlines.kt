package com.dzafirov.tvskin.widgets

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import org.w3c.dom.Element
import java.time.OffsetDateTime
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import javax.xml.parsers.DocumentBuilderFactory

data class Headline(val title: String, val link: String, val source: String, val publishedEpochSecond: Long)

/** The stories in an RSS 2.0 or Atom feed; empty for anything that isn't one (a dead feed often returns HTML). */
fun parseFeed(xml: String): List<Headline> = runCatching {
    val factory = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = false
        runCatching { setFeature("http://apache.org/xml/features/disallow-doctype-decl", true) }
    }
    val doc = factory.newDocumentBuilder().parse(xml.byteInputStream())
    val root = doc.documentElement
    when (root.tagName) {
        "feed" -> {
            val source = root.child("title")?.textContent?.trim().orEmpty()
            root.children("entry").mapNotNull { e ->
                val title = e.child("title")?.textContent?.trim() ?: return@mapNotNull null
                val link = e.children("link").firstOrNull { it.getAttribute("rel").isEmpty() || it.getAttribute("rel") == "alternate" }
                    ?.getAttribute("href") ?: return@mapNotNull null
                val date = (e.child("published") ?: e.child("updated"))?.textContent?.trim()
                Headline(title, link, source, date?.let { OffsetDateTime.parse(it).toEpochSecond() } ?: 0)
            }
        }
        "rss" -> {
            val channel = root.child("channel") ?: return@runCatching emptyList()
            val source = channel.child("title")?.textContent?.trim().orEmpty()
            channel.children("item").mapNotNull { i ->
                val title = i.child("title")?.textContent?.trim() ?: return@mapNotNull null
                val link = i.child("link")?.textContent?.trim() ?: return@mapNotNull null
                val date = i.child("pubDate")?.textContent?.trim()
                Headline(title, link, source, date?.let { ZonedDateTime.parse(it, DateTimeFormatter.RFC_1123_DATE_TIME).toEpochSecond() } ?: 0)
            }
        }
        else -> emptyList()
    }
}.getOrDefault(emptyList())

/** All feeds merged, newest first. */
fun latestHeadlines(feeds: List<List<Headline>>, count: Int): List<Headline> =
    feeds.flatten().sortedByDescending { it.publishedEpochSecond }.distinctBy { it.link }.take(count)

private fun Element.children(tag: String): List<Element> =
    (0 until childNodes.length).map { childNodes.item(it) }.filterIsInstance<Element>().filter { it.tagName == tag }

private fun Element.child(tag: String): Element? = children(tag).firstOrNull()

/** Tech, AI and marketing headlines from feeds checked for Euribia's news radar. Cached for an hour. */
class HeadlinesRepository(private val clock: () -> Long = System::currentTimeMillis) {
    private var cached: List<Headline> = emptyList()
    private var fetchedAt = 0L

    suspend fun latest(): List<Headline> {
        if (cached.isNotEmpty() && clock() - fetchedAt < 60 * 60_000L) return cached
        val feeds = coroutineScope {
            FEEDS.map { url -> async(Dispatchers.IO) { runCatching { parseFeed(fetch(url, USER_AGENT)) }.getOrDefault(emptyList()) } }.awaitAll()
        }
        val merged = latestHeadlines(feeds, 3)
        if (merged.isNotEmpty()) { cached = merged; fetchedAt = clock() }
        return cached
    }

    companion object {
        val FEEDS = listOf(
            "https://www.theverge.com/rss/index.xml",
            "https://techcrunch.com/feed/",
            "https://www.technologyreview.com/feed/",
            "https://martech.org/feed/",
        )
        /** Some feeds refuse a bare client; a browser User-Agent gets the feed. */
        const val USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126 Safari/537.36"
    }
}
