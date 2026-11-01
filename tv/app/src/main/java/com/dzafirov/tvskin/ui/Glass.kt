package com.dzafirov.tvskin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** A rounded glass panel (v5 `.glass`): blurred wallpaper, a warm tint and a thin light edge. */
@Composable
fun GlassPanel(
    wallpaper: Wallpaper,
    modifier: Modifier = Modifier,
    radius: Dp = 15.dp,
    content: @Composable BoxScope.() -> Unit,
) {
    val shape = RoundedCornerShape(radius)
    Box(modifier.clip(shape)) {
        Frost(wallpaper, Modifier.matchParentSize(), feather = 0.dp, darken = 0.05f)
        Box(Modifier.matchParentSize().background(TvColors.GlassFill).border(0.75.dp, TvColors.GlassEdge, shape))
        content()
    }
}
