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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.style.TextOverflow
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

/** "Today": weather, air in Sofia, headlines, quick controls (Dimitar chose these over calendar and photos). */
@Composable
fun WidgetsRow(state: HomeState, actions: HomeActions, onSleep: () -> Unit, onInputs: () -> Unit, focusFor: (String) -> FocusRequester, modifier: Modifier = Modifier) {
    Row(modifier.padding(start = Sizes.sideMargin), horizontalArrangement = Arrangement.spacedBy(Sizes.rowGap)) {
        WeatherCard(state)
        AirCard(state)
        HeadlinesCard(state, actions)
        QuickControls(state, actions, onSleep, onInputs, focusFor)
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

/** "Controls": four round buttons with a label and value underneath, like the other cards' layout. */
@Composable
private fun QuickControls(state: HomeState, actions: HomeActions, onSleep: () -> Unit, onInputs: () -> Unit, focusFor: (String) -> FocusRequester) {
    GlassPanel(state.wallpaper, Modifier.size(Sizes.widgetWidth, Sizes.widgetHeight), radius = Sizes.widgetRadius) {
        Column(Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Text(stringResource(R.string.controls_title), style = TvType.body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold), color = Color.White)
            Row(Modifier.fillMaxWidth().padding(top = 10.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                val sleepValue = state.sleepLeftMinutes?.let { stringResource(R.string.minutes_short, it) } ?: stringResource(R.string.off)
                RoundControl(R.drawable.ic_moon, stringResource(R.string.sleep), sleepValue, onSleep, "widget:sleep", Modifier.focusRequester(focusFor("widget:sleep")))
                RoundControl(R.drawable.ic_input, stringResource(R.string.input), stringResource(R.string.choose), onInputs, "widget:input", Modifier.focusRequester(focusFor("widget:input")))
                RoundControl(R.drawable.ic_sun, stringResource(R.string.picture), stringResource(R.string.adjust), actions::openDisplaySound, "widget:picture")
                RoundControl(R.drawable.ic_speaker, stringResource(R.string.sound), stringResource(R.string.adjust), actions::openDisplaySound, "widget:sound")
            }
        }
    }
}

@Composable
private fun RoundControl(icon: Int, label: String, value: String, onClick: () -> Unit, tag: String, modifier: Modifier = Modifier) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        FocusSurface(
            onClick = onClick,
            modifier = modifier.size(38.dp).testTag(tag),
            radius = 19.dp,
            focusedScale = 1.12f,
            container = Color.White.copy(alpha = 0.14f),
            edge = Color.White.copy(alpha = 0.12f),
        ) {
            Icon(painterResource(icon), null, Modifier.size(17.dp).align(Alignment.Center))
        }
        Text(label, style = TvType.body.copy(fontSize = 8.5.sp, fontWeight = FontWeight.SemiBold), color = Color.White, maxLines = 1, modifier = Modifier.padding(top = 5.dp))
        Text(value, style = TvType.body.copy(fontSize = 8.sp), color = Color.White.copy(alpha = 0.65f), maxLines = 1)
    }
}

@Composable
private fun AirCard(state: HomeState) {
    val air = state.air ?: return
    FocusSurface(
        onClick = {},
        modifier = Modifier.size(Sizes.widgetWidth, Sizes.widgetHeight).testTag("widget:air"),
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
            Text(stringResource(R.string.air_title), style = TvType.body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold))
            Row(Modifier.padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(11.dp).clip(CircleShape).background(Color(com.dzafirov.tvskin.widgets.airColor(air.aqi))))
                Text(com.dzafirov.tvskin.widgets.airVerdict(air.aqi), style = TvType.body.copy(fontSize = 24.sp, fontWeight = FontWeight.SemiBold, letterSpacing = (-0.5).sp), modifier = Modifier.padding(start = 8.dp))
            }
            Text(stringResource(R.string.air_detail, air.aqi, Math.round(air.pm25).toInt()), style = TvType.body.copy(fontSize = 10.sp), color = Color.White.copy(alpha = 0.72f), modifier = Modifier.padding(top = 4.dp))
            Text(com.dzafirov.tvskin.widgets.airTip(air.aqi), style = TvType.body.copy(fontSize = 10.5.sp, fontWeight = FontWeight.Medium), modifier = Modifier.padding(top = 6.dp))
        }
    }
}

@Composable
private fun HeadlinesCard(state: HomeState, actions: HomeActions) {
    if (state.headlines.isEmpty()) return
    GlassPanel(state.wallpaper, Modifier.size(Sizes.widgetWidth, Sizes.widgetHeight), radius = Sizes.widgetRadius) {
        Column(Modifier.padding(horizontal = 7.dp, vertical = 8.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(stringResource(R.string.headlines_title), style = TvType.body.copy(fontSize = 13.sp, fontWeight = FontWeight.SemiBold), color = Color.White, modifier = Modifier.padding(start = 7.dp, bottom = 3.dp))
            state.headlines.take(3).forEachIndexed { i, h ->
                FocusSurface(
                    onClick = { actions.openUrl(h.link) },
                    modifier = Modifier.fillMaxWidth().weight(1f).testTag("headline:$i"),
                    radius = 9.dp,
                    focusedScale = 1.03f,
                    container = Color.Transparent,
                ) {
                    Column(Modifier.padding(horizontal = 7.dp).align(Alignment.CenterStart)) {
                        Text(h.source, style = TvType.body.copy(fontSize = 7.5.sp, fontWeight = FontWeight.SemiBold), color = LocalContentColor.current.copy(alpha = 0.6f), maxLines = 1)
                        Text(h.title, style = TvType.body.copy(fontSize = 9.5.sp, fontWeight = FontWeight.Medium), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    }
                }
            }
        }
    }
}

