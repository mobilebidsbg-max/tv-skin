package com.dzafirov.tvskin.home

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.ui.Band
import com.dzafirov.tvskin.ui.Frost
import com.dzafirov.tvskin.ui.Sizes
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.ui.WallpaperImage

/** Which part of the screen has focus: the upper part (top bar, hero, apps) or the lower rows. */
private enum class Section { UPPER, LOWER }

/**
 * The v5 home screen. The wallpaper never changes. Focus on the widgets or the Netflix/HBO strip scrolls the rows
 * up by [Sizes.scrollOffset] and hides the hero; focus back on the apps brings them down again.
 */
@Composable
fun HomeScreen(state: HomeState, actions: HomeActions) {
    var section by remember { mutableStateOf(Section.UPPER) }
    val scroll by animateDpAsState(if (section == Section.LOWER) -Sizes.scrollOffset else 0.dp, tween(600), label = "scroll")
    val heroAlpha by animateFloatAsState(if (section == Section.LOWER) 0f else 1f, tween(450), label = "hero")
    val firstApp = remember { FocusRequester() }
    fun Modifier.section(s: Section) = onFocusChanged { if (it.hasFocus) section = s }

    Box(Modifier.fillMaxSize()) {
        WallpaperImage(state.wallpaper)
        Box(Modifier.fillMaxWidth().height(76.dp).background(Brush.verticalGradient(listOf(Color(0x47000000), Color.Transparent))))

        Box(Modifier.fillMaxSize().offset { IntOffset(0, scroll.roundToPx()) }) {
            Box(Modifier.graphicsLayer { alpha = heroAlpha }) {
                Frost(state.wallpaper, Modifier.offset((-30).dp, 145.dp).unbounded().size(700.dp, 190.dp), feather = 90.dp, darken = 0.15f)
            }
            Band(state.wallpaper, Modifier.offset((-48).dp, 300.dp).unbounded().size(1056.dp, 500.dp))

            Hero(state, actions, Modifier.offset(Sizes.sideMargin, Sizes.heroTop).graphicsLayer { alpha = heroAlpha }.section(Section.UPPER))
            AppRow(state.apps, state.tvItems, actions, firstApp, Modifier.offset(y = Sizes.appsTop).section(Section.UPPER))

            Text(stringResource(R.string.today), style = TvType.label, color = Color.White.copy(alpha = 0.75f), modifier = Modifier.offset(62.dp, Sizes.widgetsLabelTop))
            WidgetsRow(state, actions, Modifier.offset(y = Sizes.widgetsTop).section(Section.LOWER))

            if (state.promos.isNotEmpty()) {
                Text(stringResource(R.string.promo_label), style = TvType.label, color = Color.White.copy(alpha = 0.75f), modifier = Modifier.offset(62.dp, Sizes.stripLabelTop))
                PromoStrip(state.promos, actions, Modifier.offset(y = Sizes.stripTop).section(Section.LOWER))
            }
        }

        TopBar(state, actions, Modifier.padding(horizontal = 48.dp).offset(y = Sizes.topBarTop).section(Section.UPPER))
    }

    // Start on the first app once the row has been laid out (requesting earlier finds no node).
    LaunchedEffect(state.apps.isNotEmpty() || state.tvItems.isNotEmpty()) {
        withFrameNanos { }
        runCatching { firstApp.requestFocus() }
    }
}

/** Lets a backdrop layer be wider or taller than the screen, so its feathered edges fall off-screen. */
private fun Modifier.unbounded() = wrapContentSize(Alignment.TopStart, unbounded = true)
