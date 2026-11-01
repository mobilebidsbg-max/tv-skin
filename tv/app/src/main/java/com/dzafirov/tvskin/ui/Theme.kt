package com.dzafirov.tvskin.ui

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Typography
import androidx.tv.material3.darkColorScheme
import com.dzafirov.tvskin.R

/** Inter (OFL), the closest free face to SF; Apple's fonts can't ship on Android. */
val Inter = FontFamily(
    Font(R.font.inter_light, FontWeight.Light),
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
    Font(R.font.inter_bold, FontWeight.Bold),
)

/** Colours from the v5 mockup. */
object TvColors {
    val Ink = Color(0xFF1B130C)          // text on a focused (white) surface
    val FocusFill = Color(0xEFFFFFFF)    // focused button / tile background
    val GlassFill = Color(0x17FFEEE0)    // rgba(255,238,224,.09)
    val GlassEdge = Color(0x1FFFFFFF)
    val DarkGlass = Color(0x3818100A)    // rgba(24,16,10,.22)
    val Dim = Color(0xB3FFFFFF)          // secondary text, 70%
}

/** Text styles from the v5 mockup: mockup px / 2 = sp. */
object TvType {
    val greeting = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 31.sp, letterSpacing = (-0.8).sp, color = Color.White)
    val button = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
    val buttonSub = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 9.sp)
    val tab = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 13.sp)
    val status = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 15.sp)
    val label = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 11.sp)
    val tileName = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Medium, fontSize = 10.sp)
    val body = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Normal, fontSize = 12.sp)
}

/** Sizes from the v5 mockup in dp (mockup px / 2). The screen is 960x540 dp. */
object Sizes {
    val screenWidth = 960.dp
    val screenHeight = 540.dp
    val sideMargin = 60.dp
    val topBarTop = 22.dp
    val topBarHeight = 38.dp
    val heroTop = 194.dp
    val smartHeight = 48.dp
    val smartRadius = 14.dp
    val rowGap = 15.dp
    val appsTop = 324.dp
    val tileWidth = 115.dp
    val tileHeight = 65.dp
    val tileRadius = 14.dp
    val sysTileWidth = 65.dp
    val widgetsLabelTop = 425.dp
    val widgetsTop = 446.dp
    val widgetWidth = 210.dp
    val widgetHeight = 118.dp
    val widgetRadius = 15.dp
    val stripLabelTop = 590.dp
    val stripTop = 610.dp
    val promoWidth = 210.dp
    val promoHeight = 78.dp
    val promoRadius = 13.dp
    val scrollOffset = 170.dp
    val focusScale = 1.1f
}

@Composable
fun TvSkinTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(),
        typography = Typography(bodyMedium = TvType.body),
        content = content,
    )
}
