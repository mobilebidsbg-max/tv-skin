package com.dzafirov.tvskin.home

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.Icon
import androidx.tv.material3.LocalContentColor
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.Frost
import com.dzafirov.tvskin.ui.GlassPanel
import com.dzafirov.tvskin.ui.Sizes
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType
import com.dzafirov.tvskin.weather.isNight
import com.dzafirov.tvskin.weather.weatherIcon

/** v5 "Today" row. Calendar and Memories wait for their data source; Picture and Sound for the TCL check. */
@Composable
fun WidgetsRow(state: HomeState, onSleep: () -> Unit, onInputs: () -> Unit, modifier: Modifier = Modifier) {
    Row(modifier.padding(start = Sizes.sideMargin), horizontalArrangement = Arrangement.spacedBy(Sizes.rowGap)) {
        WeatherCard(state)
        QuickControls(state, onSleep, onInputs)
    }
}

@Composable
private fun WeatherCard(state: HomeState) {
    val w = state.weather
    FocusSurface(
        onClick = {},
        modifier = Modifier.size(Sizes.widgetWidth, Sizes.widgetHeight).testTag("widget:weather"),
        radius = Sizes.widgetRadius,
        container = Color.Transparent,
        focusedContainer = Color.White.copy(alpha = 0.06f),
        focusedContent = Color.White,
        edge = TvColors.GlassEdge,
        focusedEdge = Color.White.copy(alpha = 0.35f),
    ) {
        Frost(state.wallpaper, Modifier.matchParentSize(), feather = 0.dp, darken = 0.05f)
        Box(Modifier.matchParentSize().background(TvColors.GlassFill))
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(w?.let { "${it.tempC}°" } ?: "–", style = TvType.body.copy(fontSize = 39.sp, fontWeight = FontWeight.Light, letterSpacing = (-1.5).sp))
                Column(Modifier.padding(start = 10.dp).weight(1f)) {
                    Text(stringResource(R.string.weather_city), style = TvType.body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold))
                    Text(w?.text?.replaceFirstChar { it.uppercase() } ?: "", style = TvType.body.copy(fontSize = 10.5.sp), color = Color.White.copy(alpha = 0.82f))
                }
                val hour = state.time.substringBefore(':').toIntOrNull() ?: 12
                if (w != null) Image(painterResource(weatherIcon(w.code, isNight(hour))), null, Modifier.size(28.dp))
            }
            Spacer(Modifier.height(10.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                state.hours.take(5).forEachIndexed { i, h ->
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(if (i == 0) stringResource(R.string.weather_now) else "%02d".format(h.hour), style = TvType.body.copy(fontSize = 9.sp), color = Color.White.copy(alpha = 0.72f))
                        Image(painterResource(weatherIcon(h.code, isNight(h.hour))), null, Modifier.size(13.dp).padding(vertical = 1.dp))
                        Text("${h.tempC}°", style = TvType.body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold))
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickControls(state: HomeState, onSleep: () -> Unit, onInputs: () -> Unit) {
    GlassPanel(state.wallpaper, Modifier.size(Sizes.widgetWidth, Sizes.widgetHeight), radius = Sizes.widgetRadius) {
        Column(Modifier.padding(9.dp), verticalArrangement = Arrangement.spacedBy(7.dp)) {
            val sleepValue = state.sleepLeftMinutes?.let { stringResource(R.string.minutes_short, it) } ?: stringResource(R.string.off)
            QuickTile(R.drawable.ic_moon, stringResource(R.string.sleep_timer), sleepValue, onSleep, "widget:sleep", Modifier.weight(1f))
            QuickTile(R.drawable.ic_input, stringResource(R.string.input), stringResource(R.string.choose), onInputs, "widget:input", Modifier.weight(1f))
        }
    }
}

@Composable
private fun QuickTile(icon: Int, label: String, value: String, onClick: () -> Unit, tag: String, modifier: Modifier) {
    FocusSurface(
        onClick = onClick,
        modifier = modifier.fillMaxWidth().testTag(tag),
        radius = 11.dp,
        container = Color.White.copy(alpha = 0.13f),
    ) {
        Row(Modifier.padding(horizontal = 7.dp).align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically) {
            val onWhite = LocalContentColor.current != Color.White
            Box(
                Modifier.size(20.dp).clip(CircleShape).background(if (onWhite) TvColors.Ink.copy(alpha = 0.1f) else Color.White.copy(alpha = 0.2f)),
                contentAlignment = Alignment.Center,
            ) { Icon(painterResource(icon), null, Modifier.size(12.dp)) }
            Column(Modifier.padding(start = 6.dp)) {
                Text(label, style = TvType.body.copy(fontSize = 8.5.sp), color = LocalContentColor.current.copy(alpha = 0.72f))
                Text(value, style = TvType.body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold))
            }
        }
    }
}
