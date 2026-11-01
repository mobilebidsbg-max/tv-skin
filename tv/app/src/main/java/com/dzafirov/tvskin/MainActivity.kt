package com.dzafirov.tvskin

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import com.dzafirov.tvskin.apps.AppArranger
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppLauncher
import com.dzafirov.tvskin.apps.AppPrefs
import com.dzafirov.tvskin.apps.AppRepository
import com.dzafirov.tvskin.home.HomeActions
import com.dzafirov.tvskin.home.HomeModel
import com.dzafirov.tvskin.home.HomeScreen
import com.dzafirov.tvskin.home.Tab
import com.dzafirov.tvskin.lastapp.IGNORED_PACKAGES
import com.dzafirov.tvskin.lastapp.LastAppStore
import com.dzafirov.tvskin.lastapp.openedAgo
import com.dzafirov.tvskin.lastapp.pickLastApp
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.ui.Wallpaper
import androidx.lifecycle.lifecycleScope
import com.dzafirov.tvskin.sleep.SleepScheduler
import com.dzafirov.tvskin.sleep.SleepTimer
import com.dzafirov.tvskin.weather.WeatherRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.time.LocalDateTime

class MainActivity : ComponentActivity(), HomeActions {
    private lateinit var model: HomeModel
    private lateinit var launcher: AppLauncher
    private lateinit var prefs: AppPrefs
    private lateinit var repo: AppRepository
    private lateinit var lastApps: LastAppStore
    private val weather = WeatherRepository()
    private lateinit var sleep: SleepScheduler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = AppPrefs(this)
        repo = AppRepository(this)
        model = HomeModel(this, prefs, repo)
        lastApps = LastAppStore(this)
        sleep = SleepScheduler(this)
        launcher = AppLauncher(this, onLaunched = { lastApps.record(it) })
        model.tick()
        // This is the home screen: Back has nowhere to go.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) { override fun handleOnBackPressed() = Unit })
        setContent {
            TvSkinTheme {
                val state by model.state
                HomeScreen(state, this)
                LaunchedEffect(Unit) {
                    while (true) {
                        model.tick()
                        refreshSleep()
                        if (LocalDateTime.now().minute % 30 == 0) refreshWeather()
                        delay(60_000L - (LocalDateTime.now().second * 1000L))
                    }
                }
            }
        }
    }

    override fun onResume() {
        super.onResume()
        model.refreshApps()
        model.tick()
        refreshLastApp()
        refreshWeather()
        refreshSleep()
    }

    /** Weather in the top bar and the Today card; on failure the old values (or none) stay. */
    private fun refreshWeather() {
        lifecycleScope.launch {
            val forecast = weather.forecast() ?: return@launch
            model.update { it.copy(weather = forecast.now, hours = forecast.hours) }
        }
    }

    /** "Back to <app>": the newest app opened from here or (with usage access) anywhere. */
    private fun refreshLastApp() {
        val installed = repo.apps()
        val recent = lastApps.recent()
        val pkg = pickLastApp(recent.map { it.first }, packageName, IGNORED_PACKAGES, installed.map { it.id }.toSet())
        val entry = installed.firstOrNull { it.id == pkg }
        val time = recent.firstOrNull { it.first == pkg }?.second
        model.update { it.copy(lastApp = entry, lastAppSubtitle = time?.let { t -> openedAgo(System.currentTimeMillis(), t) }) }
    }

    private fun soon(text: String) = Toast.makeText(this, text, Toast.LENGTH_SHORT).show()

    override fun open(e: AppEntry) {
        if (!launcher.open(e)) soon("Couldn't open ${e.label}")
    }

    override fun sideBySide() = soon("Two windows come next")
    override fun setSleep(minutes: Int?) {
        val now = System.currentTimeMillis()
        sleep.set(if (minutes == null) SleepTimer(null) else SleepTimer(null).start(now, minutes))
        refreshSleep()
    }

    private fun refreshSleep() {
        val left = sleep.current().minutesLeft(System.currentTimeMillis())
        model.update { it.copy(sleepLeftMinutes = left) }
    }
    override fun hide(e: AppEntry) {
        prefs.hidden = prefs.hiddenFor(repo.apps().map { it.id }) + e.id
        model.refreshApps()
    }

    override fun move(e: AppEntry, delta: Int) {
        prefs.order = AppArranger.move(model.state.value.apps.map { it.id }, e.id, delta)
        model.refreshApps()
    }
    override fun unhide(e: AppEntry) {
        prefs.hidden = prefs.hiddenFor(repo.apps().map { it.id }) - e.id
        model.refreshApps()
    }

    override fun setWallpaper(w: Wallpaper) {
        prefs.wallpaper = w
        model.refreshApps()
    }

    override fun setSleepDefault(minutes: Int) {
        prefs.sleepDefaultMinutes = minutes
        model.refreshApps()
    }
    override fun tab(tab: Tab) = when (tab) {
        Tab.HOME -> Unit
        Tab.ASK -> soon("Ask comes later")
        Tab.MUSIC -> soon("Music comes next")
        Tab.PHOTOS -> soon("Photos come next")
        Tab.APPS -> soon("Apps come next")
        Tab.SETTINGS -> Unit
    }
}
