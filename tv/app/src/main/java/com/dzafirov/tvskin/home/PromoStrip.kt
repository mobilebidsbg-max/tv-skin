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
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.Sizes

/** Netflix and HBO Max, last row. Plan 1 shows their own banners; plan 3 brings real titles. */
@Composable
fun PromoStrip(promos: List<AppEntry>, actions: HomeActions, modifier: Modifier = Modifier) {
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
