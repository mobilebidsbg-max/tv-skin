package com.dzafirov.tvskin.apps

import android.content.Context
import com.dzafirov.tvskin.ui.Wallpaper

/** Dimitar's choices, kept on the TV. */
class AppPrefs(context: Context) {
    private val prefs = context.getSharedPreferences("tvskin", Context.MODE_PRIVATE)

    init {
        // Versions before 2026-11-01 hid A1 Xplore by default; Dimitar wants it shown. Unhide it once.
        if (!prefs.getBoolean(KEY_A1_SHOWN, false)) {
            hidden?.let { if (AppArranger.XPLORE_PACKAGE in it) hidden = it - AppArranger.XPLORE_PACKAGE }
            prefs.edit().putBoolean(KEY_A1_SHOWN, true).apply()
        }
    }

    /** App order; [AppArranger.DEFAULT_ORDER] until he moves something. */
    var order: List<String>
        get() = prefs.getString(KEY_ORDER, null)?.split(SEP)?.filter { it.isNotEmpty() } ?: AppArranger.DEFAULT_ORDER
        set(value) = prefs.edit().putString(KEY_ORDER, value.joinToString(SEP)).apply()

    /** Explicitly hidden apps, or null until he hides or unhides something (then the default rule applies). */
    var hidden: Set<String>?
        get() = prefs.getStringSet(KEY_HIDDEN, null)?.toSet()
        set(value) = prefs.edit().apply { if (value == null) remove(KEY_HIDDEN) else putStringSet(KEY_HIDDEN, value) }.apply()

    /** The hidden set to use for [installedIds]: his own choice, or the default rule on a fresh install. */
    fun hiddenFor(installedIds: Collection<String>): Set<String> =
        hidden ?: installedIds.filter(AppArranger::isHiddenByDefault).toSet()

    var wallpaper: Wallpaper
        get() = prefs.getString(KEY_WALLPAPER, null)?.let { name -> Wallpaper.entries.firstOrNull { it.name == name } } ?: Wallpaper.DEFAULT
        set(value) = prefs.edit().putString(KEY_WALLPAPER, value.name).apply()

    var sleepDefaultMinutes: Int
        get() = prefs.getInt(KEY_SLEEP_DEFAULT, 60)
        set(value) = prefs.edit().putInt(KEY_SLEEP_DEFAULT, value).apply()

    private companion object {
        const val SEP = ","
        const val KEY_ORDER = "order"
        const val KEY_HIDDEN = "hidden"
        const val KEY_WALLPAPER = "wallpaper"
        const val KEY_SLEEP_DEFAULT = "sleep_default_minutes"
        const val KEY_A1_SHOWN = "a1_shown"
    }
}
