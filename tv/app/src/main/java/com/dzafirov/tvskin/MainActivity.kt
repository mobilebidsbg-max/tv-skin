package com.dzafirov.tvskin

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import com.dzafirov.tvskin.sleep.AdminSwitch
import com.dzafirov.tvskin.sleep.SleepScheduler
import com.dzafirov.tvskin.sleep.SleepTimer
import com.dzafirov.tvskin.weather.WeatherRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.Dispatchers
import android.content.pm.LauncherApps
import android.os.UserHandle
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
        if (AdminSwitch.handle(this, intent)) soon("Sleep timer can no longer turn the TV off")
        prefs = AppPrefs(this)
        repo = AppRepository(this)
        model = HomeModel(this, prefs, repo)
        getSystemService(LauncherApps::class.java)?.registerCallback(packageChanges)
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

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (AdminSwitch.handle(this, intent)) {
            soon("Sleep timer can no longer turn the TV off")
            return
        }
        // Home pressed (or the launcher opened) while it is already showing: reset to the home row.
        model.update { it.copy(resetToken = it.resetToken + 1) }
    }

    override fun onResume() {
        super.onResume()
        model.tick()
        refreshSleep()
        refreshWeather()
        // Reading packages, inputs and usage events is slow on the TV: off the main thread.
        lifecycleScope.launch(Dispatchers.Default) {
            model.refreshApps()
            refreshLastApp()
        }
    }

    /** Apps installed, removed or updated while the launcher runs: re-read them in the background. */
    private val packageChanges = object : LauncherApps.Callback() {
        private fun changed() { lifecycleScope.launch(Dispatchers.Default) { model.refreshApps() } }
        override fun onPackageRemoved(packageName: String, user: UserHandle) = changed()
        override fun onPackageAdded(packageName: String, user: UserHandle) = changed()
        override fun onPackageChanged(packageName: String, user: UserHandle) = changed()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = changed()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = changed()
    }

    override fun onDestroy() {
        getSystemService(LauncherApps::class.java)?.unregisterCallback(packageChanges)
        super.onDestroy()
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
        val installed = model.installed
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
    override fun hide(e: AppEntry) = model.hide(e)
    override fun move(e: AppEntry, delta: Int) = model.move(e, delta)
    override fun unhide(e: AppEntry) = model.unhide(e)
    override fun setWallpaper(w: Wallpaper) = model.setWallpaper(w)
    override fun setSleepDefault(minutes: Int) = model.setSleepDefault(minutes)
    override fun tab(tab: Tab) = when (tab) {
        Tab.HOME -> Unit
        Tab.ASK -> soon("Ask comes later")
        Tab.MUSIC -> soon("Music comes next")
        Tab.PHOTOS -> soon("Photos come next")
        Tab.APPS -> soon("Apps come next")
        Tab.SETTINGS -> Unit
    }
}
