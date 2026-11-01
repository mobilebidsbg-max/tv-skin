package com.dzafirov.tvskin.lastapp

/** Never offered as "Back to…": settings, the stock launcher, system UI, the remote service and Live TV. */
val IGNORED_PACKAGES: Set<String> = setOf(
    "com.android.tv.settings",
    "com.google.android.apps.tv.launcherx",
    "com.android.systemui",
    "com.google.android.tv.remote.service",
    "com.tcl.tv",
)

/** The newest package in [recent] (newest first) that is launchable, not this launcher and not [ignored]. */
fun pickLastApp(recent: List<String>, own: String, ignored: Set<String>, launchable: Set<String>): String? =
    recent.firstOrNull { it != own && it !in ignored && it in launchable }

/** "Opened just now", "Opened 20 min ago", "Opened 2 h ago", "Opened yesterday". */
fun openedAgo(nowMillis: Long, thenMillis: Long): String {
    val minutes = ((nowMillis - thenMillis) / 60_000).coerceAtLeast(0)
    return when {
        minutes < 1 -> "Opened just now"
        minutes < 60 -> "Opened $minutes min ago"
        minutes < 24 * 60 -> "Opened ${minutes / 60} h ago"
        else -> "Opened yesterday"
    }
}

/** Both lists as (package, time); keeps each package's newest time and sorts newest first. */
fun mergeRecent(a: List<Pair<String, Long>>, b: List<Pair<String, Long>>): List<Pair<String, Long>> =
    (a + b).groupBy({ it.first }, { it.second })
        .map { (pkg, times) -> pkg to times.max() }
        .sortedByDescending { it.second }
