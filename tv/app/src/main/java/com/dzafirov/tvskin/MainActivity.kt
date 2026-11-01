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
import kotlinx.coroutines.delay
import java.time.LocalDateTime

class MainActivity : ComponentActivity(), HomeActions {
    private lateinit var model: HomeModel
    private lateinit var launcher: AppLauncher
    private lateinit var prefs: AppPrefs
    private lateinit var repo: AppRepository
    private lateinit var lastApps: LastAppStore

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prefs = AppPrefs(this)
        repo = AppRepository(this)
        model = HomeModel(this, prefs, repo)
        lastApps = LastAppStore(this)
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
    override fun sleep() = soon("Sleep timer comes next")
    override fun hide(e: AppEntry) {
        prefs.hidden = prefs.hiddenFor(repo.apps().map { it.id }) + e.id
        model.refreshApps()
    }

    override fun move(e: AppEntry, delta: Int) {
        prefs.order = AppArranger.move(model.state.value.apps.map { it.id }, e.id, delta)
        model.refreshApps()
    }
    override fun settings() = soon("Settings come next")
    override fun tab(tab: Tab) = when (tab) {
        Tab.HOME -> Unit
        Tab.ASK -> soon("Ask comes later")
        Tab.MUSIC -> soon("Music comes next")
        Tab.PHOTOS -> soon("Photos come next")
        Tab.APPS -> soon("Apps come next")
        Tab.SETTINGS -> settings()
    }
}
