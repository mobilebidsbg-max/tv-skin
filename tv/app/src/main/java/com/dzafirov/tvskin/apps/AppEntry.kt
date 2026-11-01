package com.dzafirov.tvskin.apps

/**
 * One tile in the apps row. [id] is the package for [Kind.APP], `tv-input:<inputId>` for [Kind.INPUT],
 * and [LIVE_TV_ID] / [SETTINGS_ID] for the other TV items.
 */
data class AppEntry(val id: String, val label: String, val kind: Kind) {
    enum class Kind { APP, LIVE_TV, INPUT, SETTINGS }

    /** The package to open, or null for items that aren't an app. */
    val packageName: String? get() = if (kind == Kind.APP) id else null

    /** The TV input id for [Kind.INPUT]. */
    val inputId: String? get() = if (kind == Kind.INPUT) id.removePrefix(INPUT_PREFIX) else null

    companion object {
        const val LIVE_TV_ID = "live-tv"
        const val SETTINGS_ID = "settings"
        const val INPUT_PREFIX = "tv-input:"
    }
}
