package com.dzafirov.tvskin.lastapp

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Process

/**
 * Remembers the apps opened from this launcher (newest 10), and, when usage access is granted over adb,
 * also apps opened another way (the remote's app buttons, the phone).
 */
class LastAppStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("lastapp", Context.MODE_PRIVATE)

    fun record(pkg: String, now: Long = System.currentTimeMillis()) {
        val list = mergeRecent(saved(), listOf(pkg to now)).take(KEEP)
        prefs.edit().putString(KEY, list.joinToString(";") { "${it.first}|${it.second}" }).apply()
    }

    /** (package, time) newest first: our own records merged with the last 24 h of usage events. */
    fun recent(now: Long = System.currentTimeMillis()): List<Pair<String, Long>> = mergeRecent(saved(), usage(now))

    private fun saved(): List<Pair<String, Long>> =
        prefs.getString(KEY, null).orEmpty().split(';').mapNotNull { item ->
            val parts = item.split('|')
            val time = parts.getOrNull(1)?.toLongOrNull() ?: return@mapNotNull null
            parts[0] to time
        }

    private fun usage(now: Long): List<Pair<String, Long>> {
        if (!hasUsageAccess()) return emptyList()
        val manager = context.getSystemService(UsageStatsManager::class.java) ?: return emptyList()
        val events = runCatching { manager.queryEvents(now - DAY, now) }.getOrNull() ?: return emptyList()
        val found = mutableListOf<Pair<String, Long>>()
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) found += event.packageName to event.timeStamp
        }
        return found
    }

    private fun hasUsageAccess(): Boolean {
        val ops = context.getSystemService(AppOpsManager::class.java) ?: return false
        return ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
    }

    private companion object {
        const val KEY = "recent"
        const val KEEP = 10
        const val DAY = 24 * 60 * 60 * 1000L
    }
}
