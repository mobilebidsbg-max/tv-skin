package com.dzafirov.tvskin.home

import android.content.Context
import androidx.compose.runtime.mutableStateOf
import com.dzafirov.tvskin.apps.AppArranger
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppPrefs
import com.dzafirov.tvskin.apps.AppRepository
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/** Holds the home screen's state and refreshes it from the TV (apps) and the clock. */
class HomeModel(private val context: Context, private val prefs: AppPrefs, private val repo: AppRepository) {
    val state = mutableStateOf(
        HomeState(
            wallpaper = prefs.wallpaper, greeting = "", date = "", time = "", weather = null, hours = emptyList(),
            nowPlaying = null, lastApp = null, lastAppSubtitle = null, sleepLeftMinutes = null,
            apps = emptyList(), tvItems = emptyList(), promos = emptyList(),
        ),
    )

    /** Re-reads installed apps and the saved order / hidden set (call on resume: apps may have changed). */
    fun refreshApps() {
        val installed = repo.apps()
        val hidden = prefs.hiddenFor(installed.map { it.id })
        val promos = PROMO_PACKAGES.mapNotNull { pkg -> installed.firstOrNull { it.id == pkg } }
        state.value = state.value.copy(
            wallpaper = prefs.wallpaper,
            apps = AppArranger.arrange(installed, prefs.order, hidden),
            tvItems = repo.tvItems(),
            promos = promos,
        )
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
