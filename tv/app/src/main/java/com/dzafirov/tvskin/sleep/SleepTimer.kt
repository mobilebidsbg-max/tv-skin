package com.dzafirov.tvskin.sleep

/** A sleep timer: off, or the moment the TV should go to standby. */
data class SleepTimer(val endsAtMillis: Long?) {
    /** Whole minutes left, rounded up; null when off or already past (a timer never fires late). */
    fun minutesLeft(nowMillis: Long): Int? {
        val end = endsAtMillis ?: return null
        val left = end - nowMillis
        if (left <= 0) return null
        return ((left + 59_999) / 60_000).toInt()
    }

    fun start(nowMillis: Long, minutes: Int) = SleepTimer(nowMillis + minutes * 60_000L)

    fun cancel() = SleepTimer(null)

    companion object {
        val CHOICES = listOf(30, 60, 90)
    }
}

/** How late an alarm may arrive and still turn the TV off; later than this, it is dropped. */
private const val LATE_MS = 60_000L

/** How early an alarm may arrive (inexact delivery) and still count. */
private const val EARLY_MS = 5_000L

/**
 * Whether the alarm that just fired should put the TV in standby: only when a timer is set and its end is now
 * (a few seconds early, or up to a minute late). A timer whose end passed long ago (the TV was off, the alarm was
 * held back) never turns the TV off later.
 */
fun shouldSleepNow(endsAtMillis: Long?, nowMillis: Long): Boolean {
    val end = endsAtMillis ?: return false
    return nowMillis >= end - EARLY_MS && nowMillis - end <= LATE_MS
}
