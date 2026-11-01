package com.dzafirov.tvskin.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.unit.dp
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.ui.Sizes

/** The Apps tab: every visible app, 6 per row, same tiles and hold-OK menu as the home row. */
@Composable
fun AppsPage(
    apps: List<AppEntry>,
    actions: HomeActions,
    focusFor: (String) -> FocusRequester,
    movingId: String?,
    onHold: (AppEntry) -> Unit,
    modifier: Modifier = Modifier,
) {
    LazyVerticalGrid(
        columns = GridCells.Fixed(COLUMNS),
        modifier = modifier,
        contentPadding = PaddingValues(start = Sizes.sideMargin, end = Sizes.sideMargin, top = 20.dp, bottom = 40.dp),
        horizontalArrangement = Arrangement.spacedBy(Sizes.rowGap),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        items(apps, key = { it.id }) { entry ->
            AppTile(entry, actions, moving = entry.id == movingId, onHold = onHold, modifier = Modifier.focusRequester(focusFor(entry.id)), tagPrefix = "grid")
        }
    }
}

private const val COLUMNS = 6
