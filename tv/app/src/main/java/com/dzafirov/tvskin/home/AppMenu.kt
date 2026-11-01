package com.dzafirov.tvskin.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.GlassPanel
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.ui.Wallpaper

data class MenuItem(val tag: String, val label: String, val icon: Int?, val onClick: () -> Unit)

/**
 * A frosted sheet on the right (hold-OK menu, input chooser). Focus starts on the first item and can't leave
 * the sheet; Back closes it (handled by the caller).
 */
@Composable
fun MenuSheet(title: String, items: List<MenuItem>, wallpaper: Wallpaper, modifier: Modifier = Modifier) {
    val first = remember { FocusRequester() }
    val focusedIndex = remember { mutableIntStateOf(0) }
    GlassPanel(wallpaper, modifier.width(230.dp), radius = 18.dp) {
        Column(
            Modifier.padding(8.dp).onPreviewKeyEvent { e ->
                // Keep focus inside the sheet: sideways never leaves, up/down stop at the ends.
                if (e.type != KeyEventType.KeyDown) return@onPreviewKeyEvent false
                when (e.key) {
                    Key.DirectionLeft, Key.DirectionRight -> true
                    Key.DirectionUp -> focusedIndex.intValue == 0
                    Key.DirectionDown -> focusedIndex.intValue == items.lastIndex
                    else -> false
                }
            },
            verticalArrangement = Arrangement.spacedBy(3.dp),
        ) {
            Text(title, style = TvType.label.copy(fontSize = 12.sp), color = TvColors.Dim, modifier = Modifier.padding(start = 10.dp, top = 4.dp, bottom = 6.dp))
            items.forEachIndexed { i, item ->
                FocusSurface(
                    onClick = item.onClick,
                    modifier = Modifier.fillMaxWidth().height(33.dp).testTag(item.tag)
                        .then(if (i == 0) Modifier.focusRequester(first) else Modifier)
                        .onFocusChanged { if (it.isFocused) focusedIndex.intValue = i },
                    radius = 12.dp,
                    focusedScale = 1.02f,
                    container = Color.Transparent,
                ) {
                    Row(Modifier.padding(horizontal = 11.dp).align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically) {
                        item.icon?.let { Icon(painterResource(it), null, Modifier.size(14.dp)) }
                        Text(item.label, style = TvType.button.copy(fontSize = 12.5.sp), modifier = Modifier.padding(start = if (item.icon != null) 9.dp else 0.dp))
                    }
                }
            }
        }
    }
    LaunchedEffect(Unit) {
        withFrameNanos { }
        runCatching { first.requestFocus() }
    }
}
