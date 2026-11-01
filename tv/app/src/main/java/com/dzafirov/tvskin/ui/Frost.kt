package com.dzafirov.tvskin.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import kotlin.math.roundToInt

/**
 * Glass without live blur: draws the pre-blurred wallpaper exactly where the sharp one sits on screen, clipped to
 * this box, darkened by [darken], with edges that fade out over [feather] so there is no hard border.
 * [content] is drawn on top, unaffected by the fade.
 */
@Composable
fun Frost(
    wallpaper: Wallpaper,
    modifier: Modifier = Modifier,
    feather: Dp = 48.dp,
    darken: Float = 0.15f,
    featherSides: Boolean = true,
    content: @Composable BoxScope.() -> Unit = {},
) {
    val context = LocalContext.current
    val blurred: ImageBitmap = remember(wallpaper) { BlurCache.get(context, wallpaper) }
    var origin by remember { mutableStateOf(Offset.Zero) }
    var rootSize by remember { mutableStateOf(IntSize.Zero) }
    Box(
        modifier = modifier
            .onGloballyPositioned {
                origin = it.positionInRoot()
                rootSize = it.findRootCoordinates().size
            }
            // Only feathered glass needs its own offscreen layer (for the DstIn fade); plain glass is a clipped draw.
            .then(if (feather > 0.dp) Modifier.graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen) else Modifier)
            .drawWithContent {
                if (rootSize != IntSize.Zero) {
                    drawImage(
                        image = blurred,
                        srcOffset = IntOffset.Zero,
                        srcSize = IntSize(blurred.width, blurred.height),
                        dstOffset = IntOffset(-origin.x.roundToInt(), -origin.y.roundToInt()),
                        dstSize = rootSize,
                        filterQuality = FilterQuality.Medium,
                    )
                    drawRect(Color.Black.copy(alpha = darken))
                    if (feather <= 0.dp) {
                        drawContent()
                        return@drawWithContent
                    }
                    val fx = (feather.toPx() / size.width).coerceIn(0f, 0.5f)
                    val fy = (feather.toPx() / size.height).coerceIn(0f, 0.5f)
                    if (featherSides) {
                        drawRect(
                            Brush.horizontalGradient(0f to Color.Transparent, fx to Color.Black, 1f - fx to Color.Black, 1f to Color.Transparent),
                            blendMode = BlendMode.DstIn,
                        )
                    }
                    drawRect(
                        Brush.verticalGradient(0f to Color.Transparent, fy to Color.Black, 1f - fy to Color.Black, 1f to Color.Transparent),
                        blendMode = BlendMode.DstIn,
                    )
                }
                drawContent()
            },
        content = content,
    )
}

/**
 * The blurred wallpapers, decoded once each at quarter size (480x270): they are heavily blurred already, so drawing
 * them scaled up to the screen looks the same and costs 0.5 MB instead of 8 MB per glass element.
 */
object BlurCache {
    private val cache = HashMap<Wallpaper, ImageBitmap>()

    @Synchronized
    fun get(context: android.content.Context, wallpaper: Wallpaper): ImageBitmap = cache.getOrPut(wallpaper) {
        val options = android.graphics.BitmapFactory.Options().apply { inSampleSize = 4 }
        android.graphics.BitmapFactory.decodeResource(context.resources, wallpaper.blurred, options).asImageBitmap()
    }
}
