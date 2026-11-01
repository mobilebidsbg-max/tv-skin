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

    /** At most ~12 MB of artwork; thread-safe (loads run on IO threads). */
    private val cache = object : android.util.LruCache<String, Loaded>(12 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Loaded): Int = when (value) {
            is Loaded.Banner -> value.bitmap.allocationByteCount
            is Loaded.Icon -> value.bitmap.allocationByteCount
            Loaded.None -> 1
        }
    }

    @Composable
    override fun Art(entry: AppEntry, modifier: Modifier) {
        val context = LocalContext.current
        val loaded by produceState(cache.get(entry.id), entry.id) {
            if (value == null) value = withContext(Dispatchers.IO) { load(context, entry).also { cache.put(entry.id, it) } }
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
        if (banner != null) return Loaded.Banner(banner.toSizedBitmap(640, 360, maxW = 256, maxH = 144))
        val icon = runCatching { pm.getApplicationIcon(pkg) }.getOrNull() ?: return Loaded.None
        return Loaded.Icon(icon.toSizedBitmap(144, 144, maxW = 144, maxH = 144))
    }

    /** The drawable as a bitmap no bigger than [maxW] x [maxH] (the tile at 2x), keeping its shape. */
    private fun Drawable.toSizedBitmap(fallbackW: Int, fallbackH: Int, maxW: Int, maxH: Int): Bitmap {
        val (w, h) = fitWithin(intrinsicWidth.takeIf { it > 0 } ?: fallbackW, intrinsicHeight.takeIf { it > 0 } ?: fallbackH, maxW, maxH)
        return toBitmap(width = w, height = h)
    }
}

/** [w] x [h] scaled down (never up) to fit inside [maxW] x [maxH], keeping the aspect ratio. */
fun fitWithin(w: Int, h: Int, maxW: Int, maxH: Int): Pair<Int, Int> {
    val scale = minOf(1f, maxW.toFloat() / w, maxH.toFloat() / h)
    return maxOf(1, Math.round(w * scale)) to maxOf(1, Math.round(h * scale))
}
