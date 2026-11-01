package com.dzafirov.tvskin.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Icon
import androidx.tv.material3.LocalContentColor
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.ui.FocusSurface
import com.dzafirov.tvskin.ui.LocalAppArt
import com.dzafirov.tvskin.ui.Sizes
import com.dzafirov.tvskin.ui.TvColors
import com.dzafirov.tvskin.ui.TvType

/** Greeting and the three smart buttons: Back to… · Side by side · Sleep. */
@Composable
fun Hero(state: HomeState, actions: HomeActions, onSleep: () -> Unit, focusFor: (String) -> FocusRequester, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(state.greeting, style = TvType.greeting)
        Spacer(Modifier.height(15.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            state.lastApp?.let { app ->
                SmartButton(
                    title = stringResource(R.string.back_to, app.label),
                    subtitle = state.lastAppSubtitle,
                    onClick = { actions.open(app) },
                    tag = "smart:back",
                ) {
                    Box(Modifier.size(58.dp, 33.dp).clip(RoundedCornerShape(8.dp))) {
                        LocalAppArt.current.Art(app, Modifier)
                    }
                }
            }
            SmartButton(stringResource(R.string.side_by_side), stringResource(R.string.side_by_side_sub), actions::sideBySide, "smart:split") {
                SmartIcon(R.drawable.ic_split)
            }
            val sleepSub = state.sleepLeftMinutes?.let { stringResource(R.string.minutes_short, it) } ?: stringResource(R.string.off)
            SmartButton(stringResource(R.string.sleep), sleepSub, onSleep, "smart:sleep", Modifier.focusRequester(focusFor("smart:sleep"))) {
                SmartIcon(R.drawable.ic_moon)
            }
        }
    }
}

@Composable
private fun SmartButton(title: String, subtitle: String?, onClick: () -> Unit, tag: String, modifier: Modifier = Modifier, leading: @Composable () -> Unit) {
    FocusSurface(
        onClick = onClick,
        modifier = modifier.height(Sizes.smartHeight).testTag(tag),
        radius = Sizes.smartRadius,
        edge = Color.White.copy(alpha = 0.1f),
    ) {
        Row(
            Modifier.padding(start = 7.dp, end = 15.dp).align(Alignment.CenterStart),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            leading()
            Column {
                Text(title, style = TvType.button, maxLines = 1, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis, modifier = Modifier.widthIn(max = 170.dp))
                subtitle?.let { Text(it, style = TvType.buttonSub, maxLines = 1, color = LocalContentColor.current.copy(alpha = 0.7f)) }
            }
        }
    }
}

@Composable
private fun SmartIcon(icon: Int) {
    val onWhite = LocalContentColor.current != Color.White
    Box(
        Modifier.size(34.dp).clip(RoundedCornerShape(10.dp))
            .background(if (onWhite) TvColors.Ink.copy(alpha = 0.08f) else Color.White.copy(alpha = 0.12f)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(painterResource(icon), null, Modifier.size(16.dp))
    }
}
