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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.findRootCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.res.imageResource
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
    content: @Composable BoxScope.() -> Unit = {},
) {
    val blurred: ImageBitmap = ImageBitmap.imageResource(wallpaper.blurred)
    var origin by remember { mutableStateOf(Offset.Zero) }
    var rootSize by remember { mutableStateOf(IntSize.Zero) }
    Box(
        modifier = modifier
            .onGloballyPositioned {
                origin = it.positionInRoot()
                rootSize = it.findRootCoordinates().size
            }
            .graphicsLayer(compositingStrategy = CompositingStrategy.Offscreen)
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
                    val fx = (feather.toPx() / size.width).coerceIn(0f, 0.5f)
                    val fy = (feather.toPx() / size.height).coerceIn(0f, 0.5f)
                    drawRect(
                        Brush.horizontalGradient(0f to Color.Transparent, fx to Color.Black, 1f - fx to Color.Black, 1f to Color.Transparent),
                        blendMode = BlendMode.DstIn,
                    )
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
