package com.dzafirov.tvskin.dream

import android.service.dreams.DreamService
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.ComposeView
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.LifecycleRegistry
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.lifecycle.setViewTreeLifecycleOwner
import androidx.lifecycle.setViewTreeViewModelStoreOwner
import androidx.savedstate.SavedStateRegistry
import androidx.savedstate.SavedStateRegistryController
import androidx.savedstate.SavedStateRegistryOwner
import androidx.savedstate.setViewTreeSavedStateRegistryOwner
import com.dzafirov.tvskin.apps.AppPrefs
import com.dzafirov.tvskin.ui.TvSkinTheme
import com.dzafirov.tvskin.weather.WeatherNow
import com.dzafirov.tvskin.weather.WeatherRepository
import com.dzafirov.tvskin.weather.isNight
import kotlinx.coroutines.delay
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * The screensaver. Compose needs a lifecycle, saved-state and view-model owner on the window, which a
 * DreamService doesn't provide, so this service is all three.
 */
class ClockDream : DreamService(), LifecycleOwner, SavedStateRegistryOwner, ViewModelStoreOwner {
    private val lifecycleRegistry = LifecycleRegistry(this)
    private val savedState = SavedStateRegistryController.create(this)
    private val store = ViewModelStore()
    private val weatherRepo = WeatherRepository()

    override val lifecycle: Lifecycle get() = lifecycleRegistry
    override val savedStateRegistry: SavedStateRegistry get() = savedState.savedStateRegistry
    override val viewModelStore: ViewModelStore get() = store

    override fun onCreate() {
        super.onCreate()
        savedState.performRestore(null)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        isInteractive = false
        isFullscreen = true
        isScreenBright = true
        val wallpaper = AppPrefs(this).wallpaper
        val view = ComposeView(this).apply {
            setContent {
                TvSkinTheme {
                    var now by remember { mutableStateOf(LocalDateTime.now()) }
                    var weather by remember { mutableStateOf<WeatherNow?>(null) }
                    LaunchedEffect(Unit) {
                        while (true) {
                            now = LocalDateTime.now()
                            if (weather == null || now.minute % 30 == 0) weather = weatherRepo.forecast()?.now ?: weather
                            delay(60_000L - now.second * 1000L)
                        }
                    }
                    androidx.compose.runtime.CompositionLocalProvider(com.dzafirov.tvskin.ui.LocalUhdWallpaper provides true) { SaverFace(
                        wallpaper = wallpaper,
                        time = now.format(TIME),
                        dateLine = now.format(DATE),
                        weather = weather,
                        night = isNight(now.hour),
                        offset = driftOffset(now.hour * 60 + now.minute),
                    ) }
                }
            }
        }
        window.decorView.setViewTreeLifecycleOwner(this)
        window.decorView.setViewTreeSavedStateRegistryOwner(this)
        window.decorView.setViewTreeViewModelStoreOwner(this)
        setContentView(view)
    }

    override fun onDreamingStarted() {
        super.onDreamingStarted()
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_START)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_RESUME)
    }

    override fun onDreamingStopped() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_PAUSE)
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_STOP)
        super.onDreamingStopped()
    }

    override fun onDetachedFromWindow() {
        lifecycleRegistry.handleLifecycleEvent(Lifecycle.Event.ON_DESTROY)
        store.clear()
        super.onDetachedFromWindow()
    }

    private companion object {
        val TIME: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.UK)
        val DATE: DateTimeFormatter = DateTimeFormatter.ofPattern("EEEE d MMMM", Locale.UK)
    }
}
