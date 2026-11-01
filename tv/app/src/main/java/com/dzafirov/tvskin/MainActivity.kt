package com.dzafirov.tvskin

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
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
import androidx.lifecycle.repeatOnLifecycle
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
    private val air = com.dzafirov.tvskin.widgets.AirRepository()
    private val news = com.dzafirov.tvskin.widgets.HeadlinesRepository()
    private val titles = com.dzafirov.tvskin.widgets.PromosRepository(BuildConfig.TMDB_API_KEY)
    private val nowPlaying by lazy {
        com.dzafirov.tvskin.media.NowPlayingWatcher(this) { np ->
            model.update { it.copy(nowPlaying = np) }
            // Remember YouTube Music's last song for the always-on pill (shown paused when nothing plays).
            if (np != null && np.packageName == com.dzafirov.tvskin.home.YT_MUSIC) {
                getSharedPreferences("music", MODE_PRIVATE).edit().putString("title", np.title).putString("artist", np.artist).apply()
                model.update { it.copy(lastMusic = np.copy(playing = false)) }
            }
        }
    }
    private lateinit var sleep: SleepScheduler

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (AdminSwitch.handle(this, intent)) soon("Sleep timer can no longer turn the TV off")
        prefs = AppPrefs(this)
        repo = AppRepository(this)
        model = HomeModel(this, prefs, repo)
        getSystemService(LauncherApps::class.java)?.registerCallback(packageChanges)
        // Turning the TV off with the remote cancels a running sleep timer.
        registerReceiver(screenOff, android.content.IntentFilter(android.content.Intent.ACTION_SCREEN_OFF))
        lastApps = LastAppStore(this)
        sleep = SleepScheduler(this)
        launcher = AppLauncher(this, onLaunched = { lastApps.record(it) })
        model.tick()
        getSharedPreferences("music", MODE_PRIVATE).getString("title", null)?.let { title ->
            val artist = getSharedPreferences("music", MODE_PRIVATE).getString("artist", "").orEmpty()
            model.update { it.copy(lastMusic = com.dzafirov.tvskin.home.NowPlaying(title, artist, com.dzafirov.tvskin.home.YT_MUSIC, playing = false)) }
        }
        // This is the home screen: Back has nowhere to go.
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) { override fun handleOnBackPressed() = Unit })
        setContent {
            TvSkinTheme {
                val state by model.state
                androidx.compose.runtime.CompositionLocalProvider(com.dzafirov.tvskin.ui.LocalUhdWallpaper provides true) {
                    val split by com.dzafirov.tvskin.split.SplitHub.get(this@MainActivity).state.collectAsState()
                    val current = split
                    if (current != null) {
                        com.dzafirov.tvskin.split.SplitStage(current, state.wallpaper, state.time)
                    } else {
                        HomeScreen(state, this@MainActivity)
                    }
                }
                LaunchedEffect(Unit) {
                    // Tick only while the home screen is on screen (another app in front: no clock, no fetches).
                    lifecycle.repeatOnLifecycle(androidx.lifecycle.Lifecycle.State.STARTED) { while (true) {
                        model.tick()
                        refreshSleep()
                        if (LocalDateTime.now().minute % 30 == 0) refreshWeather()
                        delay(60_000L - (LocalDateTime.now().second * 1000L))
                    } }
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
        // Home while side by side is on and the key service is off: leave it (both apps stay, full size).
        val split = com.dzafirov.tvskin.split.SplitHub.peek()
        if (split?.state?.value != null) {
            com.dzafirov.tvskin.split.SplitHub.scope.launch { runCatching { split.leave() } }
            return
        }
        // Home pressed (or the launcher opened) while it is already showing: reset to the home row.
        model.update { it.copy(resetToken = it.resetToken + 1) }
    }

    override fun onStart() {
        super.onStart()
        nowPlaying.start()
    }

    override fun onStop() {
        nowPlaying.stop()
        super.onStop()
    }

    override fun onResume() {
        super.onResume()
        model.tick()
        refreshSleep()
        refreshWeather()
        // Reading packages, inputs and usage events is slow on the TV: off the main thread.
        lifecycleScope.launch(Dispatchers.Default) {
            model.loadApps()
            refreshLastApp()
        }
    }

    /** Apps installed, removed or updated while the launcher runs: re-read them in the background. */
    private val packageChanges = object : LauncherApps.Callback() {
        private fun changed() { lifecycleScope.launch(Dispatchers.Default) { model.loadApps() } }
        override fun onPackageRemoved(packageName: String, user: UserHandle) = changed()
        override fun onPackageAdded(packageName: String, user: UserHandle) = changed()
        override fun onPackageChanged(packageName: String, user: UserHandle) = changed()
        override fun onPackagesAvailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = changed()
        override fun onPackagesUnavailable(packageNames: Array<out String>, user: UserHandle, replacing: Boolean) = changed()
    }

    private val screenOff = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: android.content.Context, intent: android.content.Intent) {
            sleep.set(SleepTimer(null))
            refreshSleep()
        }
    }

    override fun onDestroy() {
        unregisterReceiver(screenOff)
        getSystemService(LauncherApps::class.java)?.unregisterCallback(packageChanges)
        super.onDestroy()
    }

    /** Weather in the top bar and the Today card; on failure the old values (or none) stay. */
    private fun refreshWeather() {
        lifecycleScope.launch {
            weather.forecast()?.let { f -> model.update { it.copy(weather = f.now, hours = f.hours) } }
            air.now()?.let { a -> model.update { it.copy(air = a) } }
            news.latest().takeIf { it.isNotEmpty() }?.let { h -> model.update { it.copy(headlines = h) } }
            titles.latest().takeIf { it.isNotEmpty() }?.let { t -> model.update { it.copy(titles = t) } }
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

    override fun startSplit(left: AppEntry, right: AppEntry) {
        val split = com.dzafirov.tvskin.split.SplitHub.get(this)
        soon("Opening ${left.label} and ${right.label}…")
        lifecycleScope.launch {
            val ok = runCatching { split.start(left, right) }.getOrElse { e ->
                android.util.Log.w("Split", "start failed", e)
                false
            }
            if (ok) com.dzafirov.tvskin.split.SplitHub.watch(split)
            else soon("Allow TV Skin on the TV (\"Always allow\"), then try again")
        }
    }
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

    override fun openUrl(url: String) {
        val view = android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url)).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(view) }.onFailure { soon("No browser for this link") }
    }

    override fun openDisplaySound() {
        val intent = android.content.Intent().setClassName("com.android.tv.settings", "com.android.tv.settings.device.displaysound.DisplaySoundActivity").addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        runCatching { startActivity(intent) }.onFailure { runCatching { startActivity(android.content.Intent(android.provider.Settings.ACTION_SETTINGS).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)) } }
    }
}
