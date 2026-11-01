package com.dzafirov.tvskin.home

import androidx.activity.compose.BackHandler
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
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Text
import com.dzafirov.tvskin.R
import com.dzafirov.tvskin.apps.AppEntry
import com.dzafirov.tvskin.settings.SettingsPanel
import com.dzafirov.tvskin.sleep.SleepTimer
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
    val requesters = remember { mutableMapOf<String, FocusRequester>() }
    fun focusFor(id: String) = requesters.getOrPut(id) { FocusRequester() }
    fun Modifier.section(s: Section) = onFocusChanged { if (it.hasFocus) section = s }

    var page by remember { mutableStateOf(Tab.HOME) }
    var menuFor by remember { mutableStateOf<AppEntry?>(null) }
    var inputsOpen by remember { mutableStateOf(false) }
    var sleepOpen by remember { mutableStateOf(false) }
    // The control that opened the sleep or input sheet; focus returns there when the sheet closes.
    var sheetOpener by remember { mutableStateOf<String?>(null) }
    var movingId by remember { mutableStateOf<String?>(null) }
    // The tile to focus once the next layout is done (after a menu closes, a move, or a hide).
    var pendingFocus by remember { mutableStateOf(state.apps.firstOrNull()?.id ?: state.tvItems.firstOrNull()?.id) }

    fun onTab(tab: Tab) {
        when (tab) {
            Tab.HOME, Tab.APPS, Tab.SETTINGS -> if (page != tab) {
                page = tab
                pendingFocus = if (tab == Tab.SETTINGS) null else state.apps.firstOrNull()?.id
            }
            else -> actions.tab(tab)
        }
    }
    BackHandler(enabled = page != Tab.HOME && menuFor == null && movingId == null) { onTab(Tab.HOME) }

    BackHandler(enabled = menuFor != null || inputsOpen || sleepOpen) {
        pendingFocus = menuFor?.id ?: sheetOpener
        menuFor = null
        inputsOpen = false
        sleepOpen = false
    }

    Box(
        Modifier.fillMaxSize().onPreviewKeyEvent { e ->
            // Move mode: left/right move the app, OK or Back finish; nothing else moves focus meanwhile.
            val moving = movingId ?: return@onPreviewKeyEvent false
            val entry = state.apps.firstOrNull { it.id == moving } ?: return@onPreviewKeyEvent false
            if (e.type == KeyEventType.KeyDown) {
                when (e.key) {
                    Key.DirectionLeft -> actions.move(entry, -1)
                    Key.DirectionRight -> actions.move(entry, +1)
                    Key.DirectionCenter, Key.Enter, Key.NumPadEnter, Key.Back -> { movingId = null; pendingFocus = moving }
                    else -> Unit
                }
            }
            true
        },
    ) {
        WallpaperImage(state.wallpaper)
        Box(Modifier.fillMaxWidth().height(76.dp).background(Brush.verticalGradient(listOf(Color(0x47000000), Color.Transparent))))

        if (page == Tab.SETTINGS) {
            SettingsPanel(state, actions, Modifier.align(Alignment.TopEnd).padding(top = 70.dp, end = Sizes.sideMargin, bottom = 30.dp).size(420.dp, 440.dp))
        } else if (page == Tab.APPS) {
            Band(state.wallpaper, Modifier.offset((-48).dp, 40.dp).unbounded().size(1056.dp, 560.dp))
            AppsPage(
                state.apps, actions, ::focusFor, movingId,
                onHold = { menuFor = it },
                modifier = Modifier.fillMaxSize().padding(top = 70.dp),
            )
        } else Box(Modifier.fillMaxSize().offset { IntOffset(0, scroll.roundToPx()) }) {
            Box(Modifier.graphicsLayer { alpha = heroAlpha }) {
                Frost(state.wallpaper, Modifier.offset((-30).dp, 145.dp).unbounded().size(700.dp, 190.dp), feather = 90.dp, darken = 0.15f)
            }
            Band(state.wallpaper, Modifier.offset((-48).dp, 300.dp).unbounded().size(1056.dp, 500.dp))

            Hero(state, actions, onSleep = { sleepOpen = true; sheetOpener = "smart:sleep" }, focusFor = ::focusFor, modifier = Modifier.offset(Sizes.sideMargin, Sizes.heroTop).graphicsLayer { alpha = heroAlpha }.section(Section.UPPER))
            if (movingId != null) {
                Text(stringResource(R.string.menu_move_hint), style = TvType.label, color = Color.White, modifier = Modifier.offset(62.dp, Sizes.appsTop - 18.dp))
            }
            AppRow(
                state.apps, state.tvItems, actions, ::focusFor, movingId,
                onHold = { menuFor = it },
                modifier = Modifier.offset(y = Sizes.appsTop).section(Section.UPPER),
            )

            Text(stringResource(R.string.today), style = TvType.label, color = Color.White.copy(alpha = 0.75f), modifier = Modifier.offset(62.dp, Sizes.widgetsLabelTop))
            WidgetsRow(
                state,
                onSleep = { sleepOpen = true; sheetOpener = "widget:sleep" },
                onInputs = { inputsOpen = true; sheetOpener = "widget:input" },
                focusFor = ::focusFor,
                modifier = Modifier.offset(y = Sizes.widgetsTop).section(Section.LOWER))

            if (state.promos.isNotEmpty()) {
                Text(stringResource(R.string.promo_label), style = TvType.label, color = Color.White.copy(alpha = 0.75f), modifier = Modifier.offset(62.dp, Sizes.stripLabelTop))
                PromoStrip(state.promos, actions, Modifier.offset(y = Sizes.stripTop).section(Section.LOWER))
            }
        }

        TopBar(state, page, ::onTab, Modifier.padding(horizontal = 48.dp).offset(y = Sizes.topBarTop).section(Section.UPPER))

        if (menuFor != null || inputsOpen || sleepOpen) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.25f)))
        }
        menuFor?.let { entry ->
            MenuSheet(
                title = entry.label,
                items = appMenuItems(entry, state, actions,
                    close = { focusId -> menuFor = null; pendingFocus = focusId },
                    startMove = { movingId = entry.id; menuFor = null; pendingFocus = entry.id },
                ),
                wallpaper = state.wallpaper,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = Sizes.sideMargin),
            )
        }
        if (sleepOpen) {
            MenuSheet(
                title = stringResource(R.string.sleep_timer),
                items = listOf<Int?>(null).plus(SleepTimer.CHOICES).map { minutes ->
                    MenuItem(
                        "menu:sleep:${minutes ?: "off"}",
                        minutes?.let { stringResource(R.string.minutes_short, it) } ?: stringResource(R.string.off),
                        R.drawable.ic_moon,
                    ) {
                        sleepOpen = false
                        pendingFocus = sheetOpener
                        actions.setSleep(minutes)
                    }
                },
                wallpaper = state.wallpaper,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = Sizes.sideMargin),
            )
        }
        if (inputsOpen) {
            MenuSheet(
                title = stringResource(R.string.inputs_title),
                items = state.tvItems.filter { it.kind != AppEntry.Kind.SETTINGS }.map { item ->
                    MenuItem("menu:tv:${item.id}", item.label, if (item.kind == AppEntry.Kind.LIVE_TV) R.drawable.ic_tv else R.drawable.ic_input) {
                        inputsOpen = false
                        pendingFocus = sheetOpener
                        actions.open(item)
                    }
                },
                wallpaper = state.wallpaper,
                modifier = Modifier.align(Alignment.CenterEnd).padding(end = Sizes.sideMargin),
            )
        }
    }

    // Home pressed again while this screen is open: back to the home row with everything closed.
    LaunchedEffect(state.resetToken) {
        if (state.resetToken == 0) return@LaunchedEffect
        page = Tab.HOME
        menuFor = null
        inputsOpen = false
        sleepOpen = false
        movingId = null
        section = Section.UPPER
        pendingFocus = state.apps.firstOrNull()?.id ?: state.tvItems.firstOrNull()?.id
    }

    // Focus a tile once the row has been laid out (requesting earlier finds no node). Starts on the first app.
    LaunchedEffect(pendingFocus, state.apps, state.tvItems) {
        val id = pendingFocus ?: return@LaunchedEffect
        withFrameNanos { }
        if (runCatching { focusFor(id).requestFocus() }.isSuccess) pendingFocus = null
    }
}

/** Hold OK on an app: Open · Side by side · Move · Hide. */
@Composable
private fun appMenuItems(
    entry: AppEntry,
    state: HomeState,
    actions: HomeActions,
    close: (focusId: String?) -> Unit,
    startMove: () -> Unit,
): List<MenuItem> {
    val apps = state.apps
    val index = apps.indexOfFirst { it.id == entry.id }
    val neighbour = apps.getOrNull(index + 1) ?: apps.getOrNull(index - 1) ?: state.tvItems.firstOrNull()
    return listOf(
        MenuItem("menu:open", stringResource(R.string.menu_open), R.drawable.ic_open) { close(entry.id); actions.open(entry) },
        MenuItem("menu:split", stringResource(R.string.side_by_side), R.drawable.ic_split) { close(entry.id); actions.sideBySide() },
        MenuItem("menu:move", stringResource(R.string.menu_move), R.drawable.ic_move) { startMove() },
        MenuItem("menu:hide", stringResource(R.string.menu_hide), R.drawable.ic_hide) { close(neighbour?.id); actions.hide(entry) },
    )
}

/** Lets a backdrop layer be wider or taller than the screen, so its feathered edges fall off-screen. */
private fun Modifier.unbounded() = wrapContentSize(Alignment.TopStart, unbounded = true)
