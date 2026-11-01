package com.dzafirov.tvskin.apps

/** Pure rules for which apps show in the row and in what order. */
object AppArranger {
    /** Dimitar's apps first, as installed on the TV on 2026-11-01. */
    val DEFAULT_ORDER: List<String> = listOf(
        "com.google.android.youtube.tv",
        "com.netflix.ninja",
        "com.wbd.stream",
        "com.amazon.amazonvideo.livingroom",
        "com.disney.disneyplus",
        "com.apple.atve.androidtv.appletv",
        "com.google.android.youtube.tvmusic",
        "com.internet.tvbrowser",
        "com.android.vending",
    )

    /** Hidden until Dimitar unhides them: TCL extras (except Live TV) and preinstalled apps he doesn't use. */
    val DEFAULT_HIDDEN: Set<String> = setOf(
        "com.iqiyi.i18n.tv",
        "xploretv.android.tv",
        "com.google.android.play.games",
        "com.android.tv.settings", // the TV's Settings is a TV item at the end of the row instead
    )

    private const val TCL_PREFIX = "com.tcl."
    const val LIVE_TV_PACKAGE = "com.tcl.tv"

    fun isHiddenByDefault(id: String): Boolean =
        id in DEFAULT_HIDDEN || (id.startsWith(TCL_PREFIX) && id != LIVE_TV_PACKAGE)

    /**
     * The visible apps: those in [order] first (in that order), then the rest by label, ignoring case.
     * Ids in [order] that aren't installed are skipped; anything in [hidden] is left out.
     */
    fun arrange(installed: List<AppEntry>, order: List<String>, hidden: Set<String>): List<AppEntry> {
        val visible = installed.filter { it.id !in hidden }
        val byId = visible.associateBy { it.id }
        val ordered = order.distinct().mapNotNull { byId[it] }
        val orderedIds = ordered.map { it.id }.toSet()
        val rest = visible.filter { it.id !in orderedIds }.sortedBy { it.label.lowercase() }
        return ordered + rest
    }

    /** Moves [id] by [delta] places, clamped to the ends. An id missing from [order] is appended first. */
    fun move(order: List<String>, id: String, delta: Int): List<String> {
        val list = order.toMutableList()
        if (id !in list) list += id
        val from = list.indexOf(id)
        val to = (from + delta).coerceIn(0, list.lastIndex)
        list.removeAt(from)
        list.add(to, id)
        return list
    }
}
