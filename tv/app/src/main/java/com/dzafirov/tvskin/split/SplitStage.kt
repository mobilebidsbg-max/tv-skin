package com.dzafirov.tvskin.split

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.BlurCache
import com.dzafirov.tvskin.ui.GlassPanel
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.ui.Wallpaper

private fun px(v: Int): Dp = (v / 2f).dp

/**
 * What the launcher shows behind the two app windows (mockup v3, made quieter): the wallpaper blurred and dark,
 * each app's name and sound state above its window, a thin white frame around the one in control, the time, and
 * at the bottom the control bar (opened with Home) or a small hint.
 */
@Composable
fun SplitStage(s: SplitState, wallpaper: Wallpaper, time: String) {
    val context = LocalContext.current
    val blurred = remember(wallpaper) { BlurCache.get(context, wallpaper) }
    Box(Modifier.fillMaxSize().background(Color(0xFF0B0907))) {
        Image(blurred, null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.55f)))
        Text(time, style = TvType.status, color = Color.White.copy(alpha = 0.9f), modifier = Modifier.align(Alignment.TopEnd).padding(top = 24.dp, end = 36.dp))

        listOf(s.left, s.right).forEach { app ->
            val r = s.boundsOf(app)
            val inControl = app == s.controlled
            // Shown behind the window (visible while the app starts) and a frame around it when it has control.
            Box(
                Modifier.offset(px(r.left) - 3.dp, px(r.top) - 3.dp).size(px(r.width) + 6.dp, px(r.height) + 6.dp)
                    .border(if (inControl) 2.dp else 1.dp, Color.White.copy(alpha = if (inControl) 0.95f else 0.18f), RoundedCornerShape(6.dp))
                    .padding(3.dp).background(Color.White.copy(alpha = 0.05f)),
            )
            PaneLabel(app, inControl, Modifier.offset(px(r.left), px(r.top) - 24.dp))
        }

        if (s.barOpen) ControlBar(s, wallpaper, Modifier.align(Alignment.BottomCenter).padding(bottom = 34.dp))
        else Hint(Modifier.align(Alignment.BottomCenter).padding(bottom = 40.dp))
    }
}

@Composable
private fun PaneLabel(app: AppEntry, inControl: Boolean, modifier: Modifier) {
    Row(modifier.alpha(if (inControl) 1f else 0.6f), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp)) {
        Box(Modifier.size(28.dp, 16.dp).clip(RoundedCornerShape(4.dp))) { LocalAppArt.current.Art(app, Modifier) }
        Text(app.label, style = TvType.button.copy(fontSize = 12.sp), color = Color.White)
        Icon(painterResource(if (inControl) R.drawable.ic_speaker else R.drawable.ic_mute), null, Modifier.size(13.dp), tint = Color.White)
    }
}

@Composable
private fun Hint(modifier: Modifier) {
    Row(
        modifier.testTag("split:hint").clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = 0.10f)).padding(horizontal = 12.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Text("⌂", style = TvType.button.copy(fontSize = 12.sp), color = Color.White.copy(alpha = 0.8f))
        Text(stringResource(R.string.split_hint), style = TvType.buttonSub.copy(fontSize = 10.sp), color = Color.White.copy(alpha = 0.8f))
    }
}

/** The glass bar: the two apps (control and sound), then Swap, 50/50, 70/30, Full screen and End. */
@Composable
private fun ControlBar(s: SplitState, wallpaper: Wallpaper, modifier: Modifier) {
    GlassPanel(wallpaper, modifier.height(44.dp), radius = 22.dp) {
        Row(Modifier.padding(5.dp), horizontalArrangement = Arrangement.spacedBy(2.dp), verticalAlignment = Alignment.CenterVertically) {
            BAR_ITEMS.forEachIndexed { i, item ->
                val on = i == s.barIndex
                val selected = when (item) {
                    BarItem.LEFT -> s.active == Side.LEFT
                    BarItem.RIGHT -> s.active == Side.RIGHT
                    BarItem.HALF -> s.ratio == Ratio.HALF && !s.full
                    BarItem.WIDE -> s.ratio == Ratio.WIDE && !s.full
                    BarItem.FULL -> s.full
                    else -> false
                }
                if (item == BarItem.SWAP) Box(Modifier.width(1.dp).height(20.dp).background(Color.White.copy(alpha = 0.18f)))
                BarButton(item, s, on, selected)
            }
        }
    }
}

@Composable
private fun BarButton(item: BarItem, s: SplitState, on: Boolean, selected: Boolean) {
    val bg = when {
        on -> TvColors.FocusFill
        selected -> Color.White.copy(alpha = 0.16f)
        else -> Color.Transparent
    }
    val fg = if (on) TvColors.Ink else Color.White
    Row(
        Modifier.testTag("split:bar:${item.name}").height(34.dp).clip(RoundedCornerShape(17.dp)).background(bg).padding(horizontal = 13.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        when (item) {
            BarItem.LEFT, BarItem.RIGHT -> {
                val app = if (item == BarItem.LEFT) s.left else s.right
                Box(Modifier.size(24.dp, 14.dp).clip(RoundedCornerShape(3.dp))) { LocalAppArt.current.Art(app, Modifier) }
                Text(app.label, style = TvType.button.copy(fontSize = 12.sp, fontWeight = FontWeight.SemiBold), color = fg, maxLines = 1)
                if (selected) Icon(painterResource(R.drawable.ic_speaker), null, Modifier.size(12.dp), tint = fg)
            }
            BarItem.SWAP -> Label(R.drawable.ic_swap, stringResource(R.string.split_swap), fg)
            BarItem.HALF -> Label(R.drawable.ic_ratio_half, "50 / 50", fg)
            BarItem.WIDE -> Label(R.drawable.ic_ratio_wide, "70 / 30", fg)
            BarItem.FULL -> Label(R.drawable.ic_expand, stringResource(R.string.split_full), fg)
            BarItem.END -> Label(R.drawable.ic_close, stringResource(R.string.split_end), fg)
        }
    }
}

@Composable
private fun Label(icon: Int, text: String, color: Color) {
    Icon(painterResource(icon), null, Modifier.size(14.dp), tint = color)
    Text(text, style = TvType.button.copy(fontSize = 12.sp), color = color, maxLines = 1)
}
