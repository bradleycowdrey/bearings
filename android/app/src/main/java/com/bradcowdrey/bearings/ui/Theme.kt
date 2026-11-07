package com.bradcowdrey.bearings.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.bradcowdrey.bearings.R

/** The Mac and iPhone apps' colours (Palette.swift): warm near-black, cream, crimson. */
object Palette {
    val bg = Color(0xFF1A1816)
    val tile = Color(0xFF23201D)
    val dial = Color(0xFF201D1A)
    val border = Color(0xFF3A3530)
    val cream = Color(0xFFFFF1E5)
    val textSecondary = Color(0xFFE0D8D0)
    val textMuted = Color(0xFFB0A898)
    val textFaint = Color(0xFF9A9286)
    val tickMinor = Color(0xFF5A534B)
    val crimson = Color(0xFF990F3D)
    val accent = Color(0xFFE04A7A)
    val level = Color(0xFF8FC89A)
    val warn = Color(0xFFF2A65A)
    /** The sun on the dial and the widget's rose. */
    val sun = Color(0xFFF5B841)
    /** Night mode multiplies everything by this, so only red is left (and night vision is kept). */
    val nightRed = Color(0xFFFF2E1F)

    // ---- The Two Degrees look (docs/LOOK.md); the same tokens as Palette.swift ----

    /** The main screen's background: pure black. */
    val screen = Color.Black
    /** A frosted tile on black: white at 8%. */
    val tileFill = Color(0x14FFFFFF)
    /** The tile's 1 dp edge: white at 12%. */
    val tileStroke = Color(0x1FFFFFFF)
    /** A choice that is off, or a quiet round button (the ⋯ menu): white at 12%. */
    val chipOff = Color(0x1FFFFFFF)
    /** North on the dial and the widget's rose, as on the icon: the one place pink stays inside the app. */
    val north = accent
    /** Warnings and the Sample badge (Two Degrees' notice amber, the same as warn). */
    val notice = warn
    /** Switches, as in Two Degrees and Meridian. */
    val switchOn = Color(0xFF30D158)
    /** A sky card before there is a location. */
    val skyUnknown = Color(0xFF262626)
    /** Menus and dialogs (Two Degrees' search field and sheet grey). */
    val menu = Color(0xFF1E1E22)
    /** Behind the map's round buttons and speed chip (Android has no blur): black at 60%. */
    val mapControl = Color(0x99000000)
    /** The lock row (C3.4 #7): maroon, with a 1 dp edge; red through night mode's multiply. */
    val lockFill = Color(0xFF3D2128)
    val lockStroke = Color(0xFF5A2C38)
    /** The dividers inside a widget (the same as border). */
    val widgetRule = border
}

/** White on black, in steps (as Palette.Op on Apple): `white(Op.CAPTION)`. */
object Op {
    const val STRONG = 0.9f
    const val BODY = 0.85f
    const val LABEL = 0.8f
    const val SUB = 0.7f
    const val CAPTION = 0.6f
    const val POINTS = 0.45f
    const val FAINT = 0.35f
    const val MINOR = 0.3f
    const val TRACK = 0.15f
    const val STROKE = 0.12f
    const val FILL = 0.12f
    const val TILE = 0.08f
    const val ROW_FILL = 0.07f
    /** Secondary text in night mode: white at 90% through the red multiply is #E6291C, about 4.7:1 on black (§4.3). */
    const val NIGHT_SECONDARY = 0.9f
    /** The readout's "—°" before there is a heading. */
    const val NO_HEADING = 0.4f
}

/** True while night mode's red multiply is on, for colours that must stay legible through it. */
val LocalNight = compositionLocalOf { false }

/** Secondary text: white at 60% by day, at 90% at night (so it stays 4.5:1 or better through the red multiply). */
@Composable
fun secondary(): Color = white(if (LocalNight.current) Op.NIGHT_SECONDARY else Op.CAPTION)

/** Header line 2: white at 75% by day, at 90% at night. */
@Composable
fun headerSecondary(): Color = white(if (LocalNight.current) Op.NIGHT_SECONDARY else 0.75f)

/** WCAG contrast of night mode's secondary text on black, for the self-test (§4.7): white at [alpha] × the night red. */
object NightContrast {
    private fun linear(c: Float): Double { val v = c.toDouble(); return if (v <= 0.03928) v / 12.92 else Math.pow((v + 0.055) / 1.055, 2.4) }
    fun luminance(c: Color) = 0.2126 * linear(c.red) + 0.7152 * linear(c.green) + 0.0722 * linear(c.blue)
    /** The colour white at [alpha] on black becomes through the multiply. */
    fun nightColor(alpha: Float) = Color(alpha * Palette.nightRed.red, alpha * Palette.nightRed.green, alpha * Palette.nightRed.blue)
    fun ratioOnBlack(c: Color) = (luminance(c) + 0.05) / 0.05
    val secondary: Double get() = ratioOnBlack(nightColor(Op.NIGHT_SECONDARY))
}

/** White at a step of the ladder. */
fun white(alpha: Float): Color = Color.White.copy(alpha = alpha)

/** Sizes shared by every screen, as Look on Apple. */
object Look {
    val radius = 16.dp
    val padding = 14.dp
    val paddingV = 12.dp
    val skyPadding = 14.dp
    val margin = 16.dp
    val gap = 12.dp
    val tileGap = 8.dp
    val titleRow = 48.dp
    val stroke = 1.dp
    val compactHeight = 700.dp
    const val TITLE_SIZE = 34f
    const val CAPTION_SIZE = 12f
    const val VALUE_SIZE = 20f
    val shape = RoundedCornerShape(16.dp)

    // The tile component (docs/REFINE.md §3.2), shared with the widgets (which keep 10 sp captions for their size).
    const val TILE_CAPTION = 11f
    const val TILE_CAPTION_LINE = 13f
    const val TILE_CAPTION_TRACKING = 0.6f
    const val TILE_VALUE = 17f
    const val TILE_VALUE_LINE = 19f
    /** A one-line Position (MGRS, Plus Code, UTM): 20 (C3.4 #12). */
    const val TILE_VALUE_SINGLE = 20f
    const val TILE_SECONDARY = 13f
    const val TILE_SECONDARY_LINE = 16f
    const val WIDGET_CAPTION = 10f
    val tilePaddingH = 12.dp
    val tilePaddingV = 10.dp
    /** The header bar's corners. */
    val headerShape = RoundedCornerShape(14.dp)
    /** Values may shrink this far before they wrap; they never ellipsize. */
    const val MIN_TEXT_SCALE = 0.85f
}

/**
 * The sky behind the place card, following the sun's altitude in degrees (as SkyTone on Apple): night
 * #141E3C → #0A0E1C at -12° and below, twilight #4F78A3 → #24384F from -2° to 8°, day #3D74B0 → #1C3A5E
 * at 15° and above, interpolated between; a flat #262626 with no location.
 */
object SkyTone {
    enum class Phase { DAY, TWILIGHT_MORNING, TWILIGHT_EVENING, NIGHT, UNKNOWN }

    private class Stop(val altitude: Double, val top: Color, val bottom: Color)

    private val stops = listOf(
        Stop(-12.0, Color(0xFF141E3C), Color(0xFF0A0E1C)),
        Stop(-2.0, Color(0xFF4F78A3), Color(0xFF24384F)),
        Stop(8.0, Color(0xFF4F78A3), Color(0xFF24384F)),
        Stop(15.0, Color(0xFF3D74B0), Color(0xFF1C3A5E)),
    )

    /** Top and bottom of the sky for the sun's altitude (null: no location yet). */
    fun colors(altitude: Double?): Pair<Color, Color> {
        if (altitude == null) return Palette.skyUnknown to Palette.skyUnknown
        val first = stops.first()
        val last = stops.last()
        if (altitude <= first.altitude) return first.top to first.bottom
        if (altitude >= last.altitude) return last.top to last.bottom
        for (i in 1 until stops.size) {
            val b = stops[i]
            if (altitude <= b.altitude) {
                val a = stops[i - 1]
                val t = ((altitude - a.altitude) / (b.altitude - a.altitude)).toFloat()
                return lerp(a.top, b.top, t) to lerp(a.bottom, b.bottom, t)
            }
        }
        return last.top to last.bottom
    }

    fun brush(altitude: Double?): Brush = colors(altitude).let { Brush.verticalGradient(listOf(it.first, it.second)) }

    /**
     * Which symbol the card shows in its corner: the sun from 8° up, sunrise or sunset in twilight (morning
     * while the sun is in the east), the moon below -6°. Icons: WbSunny, WbTwilight, NightsStay, LocationOn.
     */
    fun phase(altitude: Double?, azimuth: Double?): Phase = when {
        altitude == null -> Phase.UNKNOWN
        altitude >= 8 -> Phase.DAY
        altitude >= -6 -> if ((azimuth ?: 0.0) < 180) Phase.TWILIGHT_MORNING else Phase.TWILIGHT_EVENING
        else -> Phase.NIGHT
    }
}

/** A frosted tile: white at 8% with a 1 dp edge at 12%, rounded 16. Put it before click modifiers so ripples stay rounded. */
fun Modifier.frostedTile(shape: Shape = Look.shape): Modifier =
    this.clip(shape).background(Palette.tileFill).border(Look.stroke, Palette.tileStroke, shape)

/** A sky card: the sky for the sun's altitude, rounded 16. White type on it. */
fun Modifier.skyCard(altitude: Double?, shape: Shape = Look.shape): Modifier =
    this.clip(shape).background(SkyTone.brush(altitude))

/** A tile's caption, as in Two Degrees: a small icon and the title in capitals, white at 60%. Hidden from TalkBack (the tile speaks for itself). */
@Composable
fun CardCaption(title: String, icon: ImageVector?, size: Float = Look.CAPTION_SIZE, modifier: Modifier = Modifier) {
    Row(modifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        if (icon != null) Icon(icon, contentDescription = null, tint = white(Op.CAPTION), modifier = Modifier.size((size + 2f).dp))
        Text(title.uppercase(), style = text(size, FontWeight.SemiBold, white(Op.CAPTION)).copy(letterSpacing = 0.3.sp), maxLines = 1)
    }
}

/** For what night mode's multiply can't reach (menus and dialogs, in windows of their own): the same tint, by hand. */
fun Color.night(on: Boolean): Color =
    if (!on) this else Color(red * Palette.nightRed.red, green * Palette.nightRed.green, blue * Palette.nightRed.blue, alpha)

val Inter = FontFamily(
    Font(R.font.inter_regular, FontWeight.Normal),
    Font(R.font.inter_medium, FontWeight.Medium),
    Font(R.font.inter_semibold, FontWeight.SemiBold),
)

fun text(size: Float, weight: FontWeight = FontWeight.Normal, color: Color = Color.White) =
    TextStyle(fontFamily = Inter, fontSize = size.sp, fontWeight = weight, color = color, letterSpacing = (-0.01 * size).sp)
