package com.dzafirov.tvskin.ui

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Border
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.Glow
import androidx.tv.material3.Surface

/**
 * Every focusable thing on the home screen: it scales up and casts a soft shadow when focused; nothing else
 * on screen changes. Colours default to "dark glass, white when focused" (smart buttons, tabs, quick controls).
 */
@Composable
fun FocusSurface(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    onLongClick: (() -> Unit)? = null,
    radius: Dp = 14.dp,
    focusedScale: Float = 1.06f,
    container: Color = TvColors.DarkGlass,
    focusedContainer: Color = TvColors.FocusFill,
    content: Color = Color.White,
    focusedContent: Color = TvColors.Ink,
    edge: Color = Color.Transparent,
    focusedEdge: Color = Color.Transparent,
    interactionSource: MutableInteractionSource? = null,
    body: @Composable BoxScope.() -> Unit,
) {
    val shape = RoundedCornerShape(radius)
    Surface(
        onClick = onClick,
        onLongClick = onLongClick,
        modifier = modifier,
        shape = ClickableSurfaceDefaults.shape(shape),
        scale = ClickableSurfaceDefaults.scale(focusedScale = focusedScale),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = container,
            contentColor = content,
            focusedContainerColor = focusedContainer,
            focusedContentColor = focusedContent,
            pressedContainerColor = focusedContainer,
            pressedContentColor = focusedContent,
        ),
        border = ClickableSurfaceDefaults.border(
            border = Border(BorderStroke(0.75.dp, edge), shape = shape),
            focusedBorder = Border(BorderStroke(1.5.dp, focusedEdge), shape = shape),
        ),
        glow = ClickableSurfaceDefaults.glow(
            glow = Glow.None,
            // No shadow: on this TV's GPU a focused-tile shadow costs a whole frame; the lift is the scale.
            focusedGlow = Glow.None,
        ),
        interactionSource = interactionSource,
        content = body,
    )
}
