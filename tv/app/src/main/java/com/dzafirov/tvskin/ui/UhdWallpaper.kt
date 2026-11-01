package com.dzafirov.tvskin.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PixelFormat
import android.graphics.Rect
import android.graphics.Shader
import android.view.SurfaceHolder
import android.view.SurfaceView
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** True in the app on the TV: the wallpaper goes into a 4K surface. Tests and previews keep the 1080p image. */
val LocalUhdWallpaper = staticCompositionLocalOf { false }

/**
 * The home screen's still background at the panel's real resolution: the 4K wallpaper with the top scrim, the
 * band behind the rows and the frost behind the hero merged in. It is drawn once into a 3840x2160 SurfaceView,
 * which the TV's display hardware composes by itself: real 4K pixels, and no per-frame cost for the app's GPU
 * (the app's own UI is 1920x1080 and scaled up by the TV).
 */
object UhdPlate {
    const val W = 3840
    const val H = 2160
    private var cached: Pair<Wallpaper, Bitmap>? = null

    @Synchronized
    fun get(context: Context, wallpaper: Wallpaper): Bitmap {
        cached?.let { (w, bmp) -> if (w == wallpaper) return bmp else bmp.recycle() }
        val plate = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(plate)
        val paint = Paint(Paint.FILTER_BITMAP_FLAG)
        BitmapFactory.decodeResource(context.resources, wallpaper.uhd, BitmapFactory.Options().apply { inScaled = false }).also {
            canvas.drawBitmap(it, null, Rect(0, 0, W, H), paint)
            it.recycle()
        }
        // Top scrim (v5): black .28 fading out over the top 14%.
        canvas.drawRect(0f, 0f, W.toFloat(), H * 0.14f, Paint().apply {
            shader = LinearGradient(0f, 0f, 0f, H * 0.14f, 0x47000000, 0x00000000, Shader.TileMode.CLAMP)
        })
        // Band (top at 300 dp) and hero frost, from the same pre-rendered pieces the 1080p path uses, scaled x2.
        val band = GlassBaker.band(context, wallpaper, 1920, 1080, topPx = 600, featherPx = 130)
        canvas.drawBitmap(band, null, Rect(0, 0, W, H), paint)
        val frostRegion = Rect(0, 290, 1340, 670)
        val frost = GlassBaker.patch(context, wallpaper, 1920, 1080, frostRegion, featherPx = 180, darken = 0.15f)
        canvas.drawBitmap(frost, null, Rect(0, 290 * 2, 1340 * 2, 670 * 2), paint)
        cached = wallpaper to plate
        return plate
    }
}

@Composable
fun UhdWallpaperSurface(wallpaper: Wallpaper, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val holderRef = remember { arrayOfNulls<SurfaceHolder>(1) }
    val plateRef = remember { arrayOfNulls<Bitmap>(1) }
    fun draw() {
        val holder = holderRef[0] ?: return
        val plate = plateRef[0] ?: return
        val canvas = runCatching { holder.lockHardwareCanvas() }.getOrNull() ?: return
        try {
            canvas.drawBitmap(plate, 0f, 0f, null)
        } finally {
            holder.unlockCanvasAndPost(canvas)
        }
    }
    LaunchedEffect(wallpaper) {
        plateRef[0] = withContext(Dispatchers.Default) { UhdPlate.get(context, wallpaper) }
        draw()
    }
    AndroidView(
        modifier = modifier.fillMaxSize(),
        factory = { ctx ->
            SurfaceView(ctx).apply {
                holder.setFormat(PixelFormat.OPAQUE)
                holder.setFixedSize(UhdPlate.W, UhdPlate.H)
                holder.addCallback(object : SurfaceHolder.Callback {
                    override fun surfaceCreated(h: SurfaceHolder) { holderRef[0] = h; draw() }
                    override fun surfaceChanged(h: SurfaceHolder, format: Int, width: Int, height: Int) { holderRef[0] = h; draw() }
                    override fun surfaceDestroyed(h: SurfaceHolder) { holderRef[0] = null }
                })
            }
        },
    )
    DisposableEffect(Unit) { onDispose { holderRef[0] = null } }
}
