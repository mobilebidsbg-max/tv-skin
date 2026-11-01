package com.dzafirov.tvskin.dream

/** Eight spots within ±12 dp; the clock and weather move to the next one every minute so nothing burns in. */
private val SPOTS = listOf(0 to 0, 8 to -4, 12 to 4, 4 to 10, -6 to 8, -12 to 0, -6 to -8, 4 to -12)

/** The dp offset for the corners at [minuteOfDay] (0-1439). */
fun driftOffset(minuteOfDay: Int): Pair<Int, Int> = SPOTS[Math.floorMod(minuteOfDay, SPOTS.size)]
