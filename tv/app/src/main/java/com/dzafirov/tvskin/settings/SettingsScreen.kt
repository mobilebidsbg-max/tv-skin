package com.dzafirov.tvskin.settings

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.home.HomeActions
import com.dzafirov.tvskin.home.HomeState
import com.dzafirov.tvskin.sleep.SleepTimer
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.GlassPanel
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.ui.Wallpaper

/** Settings: wallpaper, hidden apps, sleep timer default, about. A frosted panel on the right half. */
@Composable
fun SettingsPanel(state: HomeState, actions: HomeActions, modifier: Modifier = Modifier) {
    val first = remember { FocusRequester() }
    val rows = remember { mutableMapOf<String, FocusRequester>() }
    fun rowFocus(id: String) = rows.getOrPut(id) { FocusRequester() }
    var pendingRow by remember { mutableStateOf<String?>(null) }
    GlassPanel(state.wallpaper, modifier, radius = 20.dp) {
        Column(Modifier.padding(20.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(stringResource(R.string.settings), style = TvType.greeting.copy(fontSize = 20.sp))

            Section(R.string.settings_wallpaper)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Wallpaper.entries.forEachIndexed { i, w ->
                    val selected = w == state.wallpaper
                    FocusSurface(
                        onClick = { actions.setWallpaper(w) },
                        modifier = Modifier.size(80.dp, 45.dp).testTag("settings:wallpaper:${w.name}")
                            .then(if (i == 0) Modifier.focusRequester(first) else Modifier),
                        radius = 9.dp,
                        focusedScale = 1.08f,
                        container = Color.Black,
                        focusedContainer = Color.Black,
                        edge = if (selected) Color.White else Color.Transparent,
                        focusedEdge = Color.White,
                    ) {
                        Image(painterResource(w.thumb), null, Modifier.fillMaxWidth().height(45.dp), contentScale = ContentScale.Crop)
                    }
                }
            }

            Section(R.string.settings_hidden)
            if (state.hiddenApps.isEmpty()) {
                Text(stringResource(R.string.settings_none_hidden), style = TvType.body, color = TvColors.Dim)
            }
            state.hiddenApps.forEach { entry ->
                FocusSurface(
                    onClick = {
                        val i = state.hiddenApps.indexOf(entry)
                        pendingRow = (state.hiddenApps.getOrNull(i + 1) ?: state.hiddenApps.getOrNull(i - 1))?.id ?: FIRST
                        actions.unhide(entry)
                    },
                    modifier = Modifier.fillMaxWidth().height(30.dp).testTag("settings:hidden:${entry.id}").focusRequester(rowFocus(entry.id)),
                    radius = 10.dp,
                    focusedScale = 1.02f,
                    container = Color.White.copy(alpha = 0.06f),
                ) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 11.dp).align(Alignment.CenterStart), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(entry.label, style = TvType.button)
                        Text(stringResource(R.string.settings_show), style = TvType.buttonSub.copy(fontSize = 11.sp))
                    }
                }
            }

            Section(R.string.settings_sleep_default)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SleepTimer.CHOICES.forEach { minutes ->
                    val selected = minutes == state.sleepDefaultMinutes
                    FocusSurface(
                        onClick = { actions.setSleepDefault(minutes) },
                        modifier = Modifier.height(28.dp).testTag("settings:sleep:$minutes"),
                        radius = 14.dp,
                        container = if (selected) TvColors.FocusFill else Color.White.copy(alpha = 0.1f),
                        content = if (selected) TvColors.Ink else Color.White,
                    ) {
                        Text(stringResource(R.string.minutes_short, minutes), style = TvType.button, modifier = Modifier.padding(horizontal = 14.dp).align(Alignment.Center))
                    }
                }
            }

            Section(R.string.settings_about)
            Text("TV Skin ${state.version}", style = TvType.body, color = Color.White)
            Text(stringResource(R.string.settings_changes), style = TvType.body, color = TvColors.Dim)
        }
    }
    LaunchedEffect(Unit) {
        withFrameNanos { }
        runCatching { first.requestFocus() }
    }
    LaunchedEffect(pendingRow, state.hiddenApps) {
        val id = pendingRow ?: return@LaunchedEffect
        withFrameNanos { }
        runCatching { if (id == FIRST) first.requestFocus() else rowFocus(id).requestFocus() }
        pendingRow = null
    }
}

private const val FIRST = "first"


@Composable
private fun Section(title: Int) {
    Text(stringResource(title), style = TvType.label, color = TvColors.Dim, modifier = Modifier.padding(top = 10.dp, bottom = 2.dp))
}
