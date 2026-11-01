package com.dzafirov.tvskin.home

import android.content.Context
import androidx.compose.runtime.mutableStateOf
import com.dzafirov.tvskin.apps.AppArranger
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppPrefs
import com.dzafirov.tvskin.apps.InstalledApps
import com.dzafirov.tvskin.ui.Wallpaper
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Holds the home screen's state and refreshes it from the TV (apps) and the clock. */
class HomeModel(private val context: Context, private val prefs: AppPrefs, private val repo: InstalledApps) {
    val state = mutableStateOf(
        HomeState(
            wallpaper = prefs.wallpaper, greeting = "", date = "", time = "", weather = null, hours = emptyList(),
            nowPlaying = null, lastApp = null, lastAppSubtitle = null, sleepLeftMinutes = null,
            apps = emptyList(), tvItems = emptyList(), promos = emptyList(),
        ),
    )

    /** Every installed app (hidden ones too), as last read from the TV. */
    @Volatile
    var installed: List<AppEntry> = emptyList()
        private set

    /** Re-reads installed apps and TV items from the TV (slow: call off the main thread, on resume or when apps change). */
    fun refreshApps() {
        installed = repo.apps()
        val tvItems = repo.tvItems()
        val version = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull().orEmpty()
        state.value = state.value.copy(tvItems = tvItems, version = version)
        rearrange()
    }

    /** Applies the saved order, hidden set, wallpaper and sleep default to the apps already read. Fast. */
    private fun rearrange() {
        val hidden = prefs.hiddenFor(installed.map { it.id })
        state.value = state.value.copy(
            wallpaper = prefs.wallpaper,
            hiddenApps = installed.filter { it.id in hidden }.sortedBy { it.label.lowercase() },
            sleepDefaultMinutes = prefs.sleepDefaultMinutes,
            apps = AppArranger.arrange(installed, prefs.order, hidden),
            promos = PROMO_PACKAGES.mapNotNull { pkg -> installed.firstOrNull { it.id == pkg } },
        )
    }

    fun move(e: AppEntry, delta: Int) {
        prefs.order = AppArranger.move(state.value.apps.map { it.id }, e.id, delta)
        rearrange()
    }

    fun hide(e: AppEntry) {
        prefs.hidden = prefs.hiddenFor(installed.map { it.id }) + e.id
        rearrange()
    }

    fun unhide(e: AppEntry) {
        prefs.hidden = prefs.hiddenFor(installed.map { it.id }) - e.id
        rearrange()
    }

    fun setWallpaper(w: Wallpaper) {
        prefs.wallpaper = w
        rearrange()
    }

    fun setSleepDefault(minutes: Int) {
        prefs.sleepDefaultMinutes = minutes
        rearrange()
    }

    fun tick(now: LocalDateTime = LocalDateTime.now()) {
        state.value = state.value.copy(
            greeting = context.getString(greetingFor(now.hour)),
            date = now.format(DATE),
            time = now.format(TIME),
        )
    }

    fun update(transform: (HomeState) -> HomeState) {
        state.value = transform(state.value)
    }

    fun find(id: String): AppEntry? = state.value.apps.firstOrNull { it.id == id }

    companion object {
        val PROMO_PACKAGES = listOf("com.netflix.ninja", "com.wbd.stream")
        private val DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("EEE d MMM", Locale.UK)
        private val TIME: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.UK)
    }
}
