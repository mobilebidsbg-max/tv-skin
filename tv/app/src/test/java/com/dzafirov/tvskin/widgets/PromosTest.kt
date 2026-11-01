package com.dzafirov.tvskin.widgets

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PromosTest {
    private val fixture = javaClass.classLoader!!.getResource("tmdb-discover-tv.json")!!.readText()

    @Test
    fun `parse titles with artwork`() {
        val promos = parseTmdb(fixture, Brand.NETFLIX)
        assertEquals(listOf("Wednesday", "Stranger Things"), promos.map { it.title })
        assertEquals("https://image.tmdb.org/t/p/w780/iHSwvRVsRyxpX7FE7GbviaDvgGZ.jpg", promos[0].imageUrl)
        assertEquals("Series · 2022", promos[0].meta)
        assertEquals(Brand.NETFLIX, promos[0].brand)
    }

    @Test
    fun `titles without artwork are skipped, bad json gives nothing`() {
        assertTrue(parseTmdb(fixture, Brand.HBO).none { it.title == "No Picture" })
        assertTrue(parseTmdb("{", Brand.HBO).isEmpty())
    }

    @Test
    fun `the strip alternates Netflix and HBO Max`() {
        val n = listOf(Promo("N1", "u", "m", Brand.NETFLIX), Promo("N2", "u", "m", Brand.NETFLIX), Promo("N3", "u", "m", Brand.NETFLIX))
        val h = listOf(Promo("H1", "u", "m", Brand.HBO))
        assertEquals(listOf("N1", "H1", "N2", "N3"), interleave(n, h, count = 4).map { it.title })
    }
}
