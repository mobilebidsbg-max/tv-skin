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
