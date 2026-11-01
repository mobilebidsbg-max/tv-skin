package com.dzafirov.tvskin.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.drawable.Drawable
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.core.graphics.drawable.toBitmap
import com.dzafirov.tvskin.apps.AppEntry
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Draws an app's artwork into a tile. Production: the app's own TV banner. Tests: stand-ins. */
interface AppArt {
    @Composable
    fun Art(entry: AppEntry, modifier: Modifier)
}

val LocalAppArt = compositionLocalOf<AppArt> { PackageAppArt }

/** The original logos: each app's TV banner, or its icon on dark glass when it has no banner. */
object PackageAppArt : AppArt {
    private sealed interface Loaded {
        data class Banner(val bitmap: Bitmap) : Loaded
        data class Icon(val bitmap: Bitmap) : Loaded
        data object None : Loaded
    }

    private val cache = HashMap<String, Loaded>()

    @Composable
    override fun Art(entry: AppEntry, modifier: Modifier) {
        val context = LocalContext.current
        val loaded by produceState(cache[entry.id], entry.id) {
            if (value == null) value = withContext(Dispatchers.IO) { load(context, entry).also { cache[entry.id] = it } }
        }
        when (val art = loaded) {
            is Loaded.Banner -> Image(art.bitmap.asImageBitmap(), null, modifier.fillMaxSize(), contentScale = ContentScale.Crop)
            is Loaded.Icon -> Box(modifier.fillMaxSize().background(TvColors.DarkGlass)) {
                Image(art.bitmap.asImageBitmap(), null, Modifier.size(36.dp).align(Alignment.Center))
            }
            else -> Box(modifier.fillMaxSize().background(TvColors.DarkGlass))
        }
    }

    private fun load(context: Context, entry: AppEntry): Loaded {
        val pkg = entry.packageName ?: return Loaded.None
        val pm = context.packageManager
        val banner: Drawable? = pm.getLeanbackLaunchIntentForPackage(pkg)?.component
            ?.let { runCatching { pm.getActivityBanner(it) }.getOrNull() }
            ?: runCatching { pm.getApplicationBanner(pkg) }.getOrNull()
        if (banner != null) return Loaded.Banner(banner.toSizedBitmap(640, 360))
        val icon = runCatching { pm.getApplicationIcon(pkg) }.getOrNull() ?: return Loaded.None
        return Loaded.Icon(icon.toSizedBitmap(144, 144))
    }

    private fun Drawable.toSizedBitmap(fallbackW: Int, fallbackH: Int): Bitmap =
        toBitmap(
            width = intrinsicWidth.takeIf { it > 0 } ?: fallbackW,
            height = intrinsicHeight.takeIf { it > 0 } ?: fallbackH,
        )
}
