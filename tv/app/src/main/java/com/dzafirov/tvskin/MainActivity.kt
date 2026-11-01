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
import com.dzafirov.tvskin.ui.TvSkinTheme
import kotlinx.coroutines.delay
import java.time.LocalDateTime

class MainActivity : ComponentActivity(), HomeActions {
    private lateinit var model: HomeModel
    private lateinit var launcher: AppLauncher

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val prefs = AppPrefs(this)
        model = HomeModel(this, prefs, AppRepository(this))
        launcher = AppLauncher(this)
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
    }

    private fun soon(text: String) = Toast.makeText(this, text, Toast.LENGTH_SHORT).show()

    override fun open(e: AppEntry) {
        if (!launcher.open(e)) soon("Couldn't open ${e.label}")
    }

    override fun sideBySide() = soon("Two windows come next")
    override fun sleep() = soon("Sleep timer comes next")
    override fun hold(e: AppEntry) = soon(e.label)
    override fun settings() = soon("Settings come next")
    override fun inputs() = soon("Inputs come next")
    override fun tab(tab: Tab) = when (tab) {
        Tab.HOME -> Unit
        Tab.ASK -> soon("Ask comes later")
        Tab.MUSIC -> soon("Music comes next")
        Tab.PHOTOS -> soon("Photos come next")
        Tab.APPS -> soon("Apps come next")
        Tab.SETTINGS -> settings()
    }
}
