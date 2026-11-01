package com.dzafirov.tvskin.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.ui.RemoteImage
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.widgets.Brand
import com.dzafirov.tvskin.widgets.Promo
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.Sizes

/**
 * Netflix and HBO Max, last row: popular series in Bulgaria with their artwork (TMDB); OK opens the app.
 * Without titles (no key, no network) it shows the two apps' own banners.
 */
@Composable
fun PromoStrip(promos: List<AppEntry>, titles: List<Promo>, actions: HomeActions, modifier: Modifier = Modifier) {
    if (titles.isNotEmpty()) {
        Row(modifier.padding(start = Sizes.sideMargin), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
            titles.take(4).forEachIndexed { i, t -> TitleCard(i, t, actions) }
        }
        return
    }
    Row(modifier.padding(start = Sizes.sideMargin), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
        promos.forEach { entry ->
            FocusSurface(
                onClick = { actions.open(entry) },
                modifier = Modifier.size(Sizes.promoWidth, Sizes.promoHeight).testTag("promo:${entry.id}"),
                radius = Sizes.promoRadius,
                container = Color.Black,
                focusedContainer = Color.Black,
                focusedContent = Color.White,
                focusedEdge = Color.White.copy(alpha = 0.85f),
            ) {
                LocalAppArt.current.Art(entry, Modifier)
            }
        }
    }
}

@Composable
private fun TitleCard(index: Int, t: Promo, actions: HomeActions) {
    FocusSurface(
        onClick = { actions.open(AppEntry(t.brand.packageName, t.brand.label, AppEntry.Kind.APP)) },
        modifier = Modifier.size(Sizes.promoWidth, Sizes.promoHeight).testTag("title:$index"),
        radius = Sizes.promoRadius,
        container = Color(0xFF111111),
        focusedContainer = Color(0xFF111111),
        focusedContent = Color.White,
        focusedEdge = Color.White.copy(alpha = 0.85f),
    ) {
        RemoteImage(t.imageUrl, Modifier.matchParentSize())
        Box(Modifier.matchParentSize().background(Brush.horizontalGradient(listOf(Color(0x9E000000), Color(0x2E000000), Color.Transparent))))
        Text(
            t.brand.label,
            style = if (t.brand == Brand.NETFLIX) TvType.label.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = 1.sp, fontSize = 8.5.sp)
            else TvType.label.copy(fontWeight = FontWeight.Bold, fontSize = 11.sp, letterSpacing = (-0.3).sp),
            color = if (t.brand == Brand.NETFLIX) Color(0xFFE50914) else Color.White,
            modifier = Modifier.align(Alignment.TopStart).padding(start = 11.dp, top = 9.dp),
        )
        Column(Modifier.align(Alignment.BottomStart).padding(start = 11.dp, bottom = 8.dp, end = 11.dp)) {
            Text(t.title, style = TvType.body.copy(fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(t.meta, style = TvType.body.copy(fontSize = 8.5.sp), color = Color.White.copy(alpha = 0.78f), maxLines = 1)
        }
    }
}
