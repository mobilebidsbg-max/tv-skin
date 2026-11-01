package com.dzafirov.tvskin.home

import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import com.dzafirov.tvskin.ui.okPress
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.apps.AppEntry.Kind
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.Sizes
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType

/** One row: his apps (original banners), then Live TV / HDMI / Settings as glass tiles. */
@Composable
fun AppRow(
    apps: List<AppEntry>,
    tvItems: List<AppEntry>,
    actions: HomeActions,
    focusFor: (String) -> FocusRequester,
    movingId: String?,
    onHold: (AppEntry) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyRow(
        modifier = modifier.height(Sizes.tileHeight + 30.dp),
        contentPadding = PaddingValues(horizontal = Sizes.sideMargin),
        horizontalArrangement = Arrangement.spacedBy(Sizes.rowGap),
    ) {
        itemsIndexed(apps, key = { _, e -> e.id }) { _, entry ->
            AppTile(entry, actions, moving = entry.id == movingId, onHold = onHold, modifier = Modifier.focusRequester(focusFor(entry.id)))
        }
        itemsIndexed(tvItems, key = { _, e -> e.id }) { i, entry ->
            Row {
                if (i == 0) Spacer(Modifier.width(11.dp))
                SysTile(entry, actions, Modifier.focusRequester(focusFor(entry.id)))
            }
        }
    }
}

@Composable
fun AppTile(entry: AppEntry, actions: HomeActions, moving: Boolean, onHold: (AppEntry) -> Unit, modifier: Modifier, tagPrefix: String = "app") {
    val interaction = remember { MutableInteractionSource() }
    val focused by interaction.collectIsFocusedAsState()
    Column(Modifier.width(Sizes.tileWidth), horizontalAlignment = Alignment.CenterHorizontally) {
        FocusSurface(
            onClick = { actions.open(entry) },
            onLongClick = { onHold(entry) },
            modifier = modifier.size(Sizes.tileWidth, Sizes.tileHeight).testTag("$tagPrefix:${entry.id}")
                .okPress(onClick = { actions.open(entry) }, onHold = { onHold(entry) }),
            radius = Sizes.tileRadius,
            focusedScale = Sizes.focusScale,
            container = Color.Black,
            focusedContainer = Color.Black,
            focusedContent = Color.White,
            edge = if (moving) Color.White else Color.Transparent,
            focusedEdge = if (moving) Color.White else Color.Transparent,
            interactionSource = interaction,
        ) {
            LocalAppArt.current.Art(entry, Modifier)
        }
        TileName(entry.label, focused)
    }
}

@Composable
private fun SysTile(entry: AppEntry, actions: HomeActions, modifier: Modifier) {
    val icon = when (entry.kind) {
        Kind.LIVE_TV -> R.drawable.ic_tv
        Kind.INPUT -> R.drawable.ic_input
        else -> R.drawable.ic_gear
    }
    FocusSurface(
        onClick = { actions.open(entry) },
        modifier = modifier.size(Sizes.sysTileWidth, Sizes.tileHeight).testTag("tv:${entry.id}"),
        radius = Sizes.tileRadius,
        focusedScale = Sizes.focusScale,
        container = Color.White.copy(alpha = 0.12f),
        edge = Color.White.copy(alpha = 0.12f),
    ) {
        Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(painterResource(icon), null, Modifier.size(20.dp))
            Text(entry.label, style = TvType.tileName, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 4.dp, start = 4.dp, end = 4.dp))
        }
    }
}

/** The name under a tile, shown only while it is focused (v5). */
@Composable
private fun TileName(label: String, focused: Boolean) {
    Box(Modifier.width(Sizes.tileWidth).padding(top = 9.dp), contentAlignment = Alignment.TopCenter) {
        Text(
            label,
            style = TvType.tileName,
            color = Color.White,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            modifier = Modifier.requiredWidth(Sizes.tileWidth + 30.dp).alpha(if (focused) 1f else 0f),
        )
    }
}

/** A tile-sized dark glass placeholder colour, used by tests and fallbacks. */
val TileFallback = TvColors.DarkGlass
