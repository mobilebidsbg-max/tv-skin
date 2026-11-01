package com.dzafirov.tvskin.ui

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * The big glass areas (the frost behind the hero, the darker band behind the rows) never move against the
 * wallpaper, so they are rendered once into a half-resolution image with the fade already in it. Each frame then
 * draws one image instead of re-blending an offscreen layer: on this TV's GPU that saves about 6 ms per frame.
 */
object GlassBaker {
    private val cache = HashMap<String, Bitmap>()

    /** The whole screen of blurred wallpaper, faded in from [topPx] over [featherPx], darkening towards the bottom. */
    @Synchronized
    fun band(context: Context, wallpaper: Wallpaper, screenW: Int, screenH: Int, topPx: Int, featherPx: Int): Bitmap =
        cache.getOrPut("band:$wallpaper:$screenW:$screenH:$topPx:$featherPx") {
            val w = screenW / 2
            val h = screenH / 2
            val top = topPx / 2f
            val feather = featherPx / 2f
            val out = blurredCanvas(context, wallpaper, w, h) { canvas, paint ->
                paint.shader = LinearGradient(
                    0f, top, 0f, h.toFloat(),
                    intArrayOf(0x000E0A06, 0x4D0E0A06, 0x8C0E0A06.toInt()), floatArrayOf(0f, 0.17f, 1f), Shader.TileMode.CLAMP,
                )
                canvas.drawRect(0f, top, w.toFloat(), h.toFloat(), paint)
            }
            mask(out) { canvas, paint ->
                paint.shader = LinearGradient(0f, top, 0f, top + feather, 0x00000000, -0x1000000, Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
            }
        }

    /** A patch of blurred, darkened wallpaper at [region] (screen px) whose edges fade out over [featherPx]. */
    @Synchronized
    fun patch(context: Context, wallpaper: Wallpaper, screenW: Int, screenH: Int, region: Rect, featherPx: Int, darken: Float): Bitmap =
        cache.getOrPut("patch:$wallpaper:$screenW:$screenH:$region:$featherPx:$darken") {
            val full = blurredCanvas(context, wallpaper, screenW / 2, screenH / 2) { canvas, paint ->
                paint.color = ((darken * 255).toInt() shl 24)
                canvas.drawRect(0f, 0f, screenW / 2f, screenH / 2f, paint)
            }
            val w = (region.width() / 2).coerceAtLeast(1)
            val h = (region.height() / 2).coerceAtLeast(1)
            val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            Canvas(out).drawBitmap(full, Rect(region.left / 2, region.top / 2, region.right / 2, region.bottom / 2), Rect(0, 0, w, h), Paint(Paint.FILTER_BITMAP_FLAG))
            full.recycle()
            val f = featherPx / 2f
            mask(out) { canvas, paint ->
                paint.shader = LinearGradient(0f, 0f, w.toFloat(), 0f, intArrayOf(0, -0x1000000, -0x1000000, 0), floatArrayOf(0f, f / w, 1 - f / w, 1f), Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
                paint.shader = LinearGradient(0f, 0f, 0f, h.toFloat(), intArrayOf(0, -0x1000000, -0x1000000, 0), floatArrayOf(0f, f / h, 1 - f / h, 1f), Shader.TileMode.CLAMP)
                canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), paint)
            }
        }

    private fun blurredCanvas(context: Context, wallpaper: Wallpaper, w: Int, h: Int, extra: (Canvas, Paint) -> Unit): Bitmap {
        val source = BitmapFactory.decodeResource(context.resources, wallpaper.blurred, BitmapFactory.Options().apply { inSampleSize = 2 })
        val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        canvas.drawBitmap(source, null, RectF(0f, 0f, w.toFloat(), h.toFloat()), Paint(Paint.FILTER_BITMAP_FLAG))
        source.recycle()
        extra(canvas, Paint(Paint.ANTI_ALIAS_FLAG))
        return out
    }

    /** Multiplies [bitmap]'s alpha by whatever [draw] paints (DST_IN). */
    private fun mask(bitmap: Bitmap, draw: (Canvas, Paint) -> Unit): Bitmap {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN) }
        draw(Canvas(bitmap), paint)
        return bitmap
    }
}

/** The band behind the rows, starting at [top] (from the top of the screen), as one pre-rendered image. */
@Composable
fun BakedBand(wallpaper: Wallpaper, top: Dp, modifier: Modifier = Modifier, feather: Dp = 65.dp, alpha: Float = 1f) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val screenW = with(density) { 960.dp.roundToPx() }
    val screenH = with(density) { 540.dp.roundToPx() }
    val topPx = with(density) { top.roundToPx() }
    val featherPx = with(density) { feather.roundToPx() }
    val image by produceState<ImageBitmap?>(null, wallpaper, topPx) {
        value = withContext(Dispatchers.Default) { GlassBaker.band(context, wallpaper, screenW, screenH, topPx, featherPx).asImageBitmap() }
    }
    if (alpha > 0f) image?.let { Image(it, null, modifier.fillMaxSize(), contentScale = ContentScale.FillBounds, alpha = alpha) }
}

/** A feathered frost patch at [x], [y] with [width] x [height] (screen dp), as one pre-rendered image. */
@Composable
fun BakedFrost(wallpaper: Wallpaper, x: Dp, y: Dp, width: Dp, height: Dp, feather: Dp, darken: Float, modifier: Modifier = Modifier, alpha: Float = 1f) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val region = with(density) { Rect(x.roundToPx(), y.roundToPx(), (x + width).roundToPx(), (y + height).roundToPx()) }
    val screenW = with(density) { 960.dp.roundToPx() }
    val screenH = with(density) { 540.dp.roundToPx() }
    val featherPx = with(density) { feather.roundToPx() }
    val image by produceState<ImageBitmap?>(null, wallpaper, region) {
        value = withContext(Dispatchers.Default) { GlassBaker.patch(context, wallpaper, screenW, screenH, region, featherPx, darken).asImageBitmap() }
    }
    if (alpha > 0f) image?.let { Image(it, null, modifier.offset(x, y).size(width, height), contentScale = ContentScale.FillBounds, alpha = alpha) }
}
