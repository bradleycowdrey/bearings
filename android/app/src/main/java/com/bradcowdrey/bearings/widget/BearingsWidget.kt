package com.bradcowdrey.bearings.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.LocalContext
import androidx.glance.LocalSize
import androidx.glance.action.actionStartActivity
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.ContentScale
import androidx.glance.layout.Row
import androidx.glance.layout.RowScope
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxHeight
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextAlign
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.bradcowdrey.bearings.Geo
import com.bradcowdrey.bearings.MainActivity
import com.bradcowdrey.bearings.ui.Op
import com.bradcowdrey.bearings.ui.Palette
import com.bradcowdrey.bearings.ui.SkyTone
import com.bradcowdrey.bearings.ui.white

/**
 * The Home Screen widget (docs/DESIGN.md, Widgets; mock W2), one that resizes through three layouts, each on black
 * with the app's slim sky header (the place and the time of the reading) and its frosted tiles with captions in
 * capitals, and each carrying a NORTH-UP compass in the app's dial style ([WidgetDial]) that shows only true
 * directions: the sun, the moon, the marked spot and the locked bearing. Never a live or "last" heading.
 *
 * - Small (under 250 dp wide, 2 × 2): the header, the dial's top half (W → N → E, up to 124 dp) with the spot's
 *   pin and distance pill, the sun and moon below the arc as edge marks; the elevation at 30 sp under it.
 * - Medium (250 dp wide and up, under 300 tall, 4 × 2): a full dial (up to 120 dp) in the left column with the sun,
 *   moon, spot (pin and dashed line) and lock notch, "9.2 mi · 46° NE" under it; the header over the right column,
 *   then ELEVATION and SUN (the moon's % in its caption, ↑ rise ↓ set).
 * - Large (250 × 300 dp and up): the header; the full-scale dial (up to 212 dp) with ELEVATION, SUN and MOON stacked
 *   beside it; POSITION and the Marked spot row (the lock and the spot's distance and bearing) full width below.
 *   Without a spot or lock that row and those marks drop out and the dial takes the room.
 *
 * Corners 24 dp outside, 16 inside. [SizeMode.Exact], so each layout sizes its dial to the widget it is in.
 * Tapping it opens Bearings.
 */
class BearingsWidget : GlanceAppWidget() {
    companion object {
        /** From this width, the full dial and tiles; from this height too, Large. */
        const val WIDE = 250f
        const val TALL = 300f
        const val OUTER = 24
        const val INNER = 16
    }

    override val sizeMode: SizeMode = SizeMode.Exact

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val entry = WidgetData.entry(context)
        provideContent { WidgetContent(entry) }
    }
}

class BearingsWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = BearingsWidget()
}

private fun style(size: TextUnit, weight: FontWeight = FontWeight.Normal, color: Color = Color.White, align: TextAlign = TextAlign.Start) =
    TextStyle(color = ColorProvider(color), fontSize = size, fontWeight = weight, textAlign = align)

/** Which layout a widget of this size shows (the self-test checks the breakpoints). */
enum class WidgetLayout { SMALL, MEDIUM, LARGE }

fun widgetLayout(widthDp: Float, heightDp: Float): WidgetLayout = when {
    widthDp >= BearingsWidget.WIDE && heightDp >= BearingsWidget.TALL -> WidgetLayout.LARGE
    widthDp >= BearingsWidget.WIDE -> WidgetLayout.MEDIUM
    else -> WidgetLayout.SMALL
}

/** The dial each layout draws at a widget size (dp): Small's half dial, Medium's and Large's full dial. 0 for none. */
fun widgetDialSize(layout: WidgetLayout, w: Float, h: Float, hasSpot: Boolean, hasRow: Boolean): Float = when (layout) {
    // 124 at most; the arc and its edge marks within the width; the arc between the header and the elevation (its
    // edge-mark room may run behind the number's sides).
    WidgetLayout.SMALL -> minOf(124f, w - 2 * WidgetDial.SIDE - 4f, 2f * (h - 106f)).let { if (it < 60f) 0f else it }
    WidgetLayout.MEDIUM -> minOf(mediumColumn(w, h), h - 16f - (if (hasSpot) 34f else 8f), 180f)
    // The row height under the header, less the rows below; the width less 128 for the tiles.
    WidgetLayout.LARGE -> minOf(w - 16f - 8f - 128f, h - 16f - 48f - 52f - (if (hasRow) 50f else 0f))
}

/** Medium's left column: 128 wide, more on a taller widget, never over 42% of the width. */
private fun mediumColumn(w: Float, h: Float) = minOf(maxOf(128f, h - 50f), w * 0.42f)

/** The marks on a widget's dial, from the entry (all true bearings). */
private fun marks(entry: WidgetEntry, spotLabel: Boolean, lock: Boolean) = WidgetDial.Marks(
    sun = entry.sunAzimuth, sunUp = entry.sunUp,
    moon = entry.moonAzimuth, moonUp = entry.moonUp, moonPhase = entry.moonPhase,
    spot = entry.markBearing, spotLabel = if (spotLabel) entry.markDistance else null,
    lock = if (lock) entry.lock else null,
)

/** What the dial says to TalkBack. */
private fun dialDescription(entry: WidgetEntry, lock: Boolean): String {
    val parts = mutableListOf("Compass, north up")
    entry.sunAzimuth?.let { parts += "sun ${Geo.jsRound(it) % 360}° ${Geo.point(it)}" }
    entry.moonAzimuth?.let { parts += "moon ${Geo.jsRound(it) % 360}° ${Geo.point(it)}" }
    if (entry.markPoint != null && entry.markDistance != null) parts += "marked spot ${entry.markPoint}, ${entry.markDistance}"
    if (lock) entry.lock?.let { parts += "locked ${Geo.jsRound(it) % 360}°" }
    return parts.joinToString(", ")
}

@Composable
fun WidgetContent(entry: WidgetEntry) {
    val size = LocalSize.current
    val w = size.width.value; val h = size.height.value
    // Bitmaps at no more than 2 px per dp: sharp enough at widget sizes, and a widget update carries every bitmap.
    val scale = minOf(LocalContext.current.resources.displayMetrics.density, 2f)
    Box(
        GlanceModifier.fillMaxSize().cornerRadius(BearingsWidget.OUTER.dp).background(Color.Black)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        if (entry.snapshot == null) Empty()
        else when (widgetLayout(w, h)) {
            WidgetLayout.SMALL -> Small(entry, w, h, scale)
            WidgetLayout.MEDIUM -> Medium(entry, w, h, scale)
            WidgetLayout.LARGE -> Large(entry, w, h, scale)
        }
    }
}

@Composable
private fun Empty() {
    Column(GlanceModifier.fillMaxSize().padding(8.dp)) {
        Header("Bearings", "No reading yet", null)
        Spacer(GlanceModifier.defaultWeight())
        Text("Open Bearings to find where you are.", style = style(13.sp, color = white(Op.CAPTION)), maxLines = 3,
            modifier = GlanceModifier.padding(horizontal = 4.dp, vertical = 4.dp))
    }
}

/**
 * The app's slim location bar: 40 dp, the sky for the sun's altitude (as the app's header), rounded 16; the place
 * at 15 sp and the time of the reading at 12 sp, white at 75%.
 */
@Composable
private fun Header(place: String, time: String, sunAltitude: Double?) {
    val (top, bottom) = SkyTone.colors(sunAltitude)
    Box(GlanceModifier.fillMaxWidth().height(40.dp).cornerRadius(BearingsWidget.INNER.dp)) {
        Image(ImageProvider(WidgetDial.sky(top.toArgb(), bottom.toArgb())), null, GlanceModifier.fillMaxSize(), contentScale = ContentScale.FillBounds)
        Column(GlanceModifier.fillMaxSize().padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(place, style = style(15.sp, FontWeight.Medium), maxLines = 1)
            Text(time, style = style(12.sp, color = white(0.75f)), maxLines = 1)
        }
    }
}

/** A caption in capitals, 11 sp, white at 60%. */
@Composable
private fun Caption(text: String) {
    Text(text.uppercase(), style = style(11.sp, FontWeight.Medium, white(Op.CAPTION)), maxLines = 1)
}

/** A frosted tile: white at 8%, rounded 16, the caption at the top and [content] at the foot. */
@Composable
private fun Tile(modifier: GlanceModifier, caption: @Composable () -> Unit, content: @Composable () -> Unit) {
    Column(modifier.fillMaxWidth().cornerRadius(BearingsWidget.INNER.dp).background(Palette.tileFill).padding(horizontal = 12.dp, vertical = 6.dp)) {
        caption()
        Spacer(GlanceModifier.defaultWeight())
        content()
    }
}

/** "9,587 ft" → "9,587" and "ft". */
private fun splitUnit(text: String?): Pair<String, String> {
    val t = text ?: return "—" to ""
    val i = t.lastIndexOf(' ')
    return if (i > 0) t.substring(0, i) to t.substring(i + 1) else t to ""
}

/** ↑ 6:36 AM, the arrow in the sun's amber. */
@Composable
private fun SunTime(up: Boolean, time: String?, size: TextUnit) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Text(if (up) "↑" else "↓", style = style(size, FontWeight.Medium, Palette.sun), maxLines = 1)
        Text(" ${time ?: "—"}", style = style(size, FontWeight.Medium), maxLines = 1)
    }
}

/** Small: the header, the half dial with the spot's pin and pill and the sun and moon as edge marks, the elevation under it. */
@Composable
private fun Small(entry: WidgetEntry, w: Float, h: Float, scale: Float) {
    val d = widgetDialSize(WidgetLayout.SMALL, w, h, entry.markBearing != null, false)
    Box(GlanceModifier.fillMaxSize().padding(8.dp)) { Header(entry.shortPlace, entry.asOf, entry.sunAltitude) }
    if (d > 0f) {
        val dial = WidgetDial.draw(d, half = true, marks = marks(entry, spotLabel = true, lock = false), scale = scale)
        Box(GlanceModifier.fillMaxSize().padding(top = 56.dp), contentAlignment = Alignment.TopCenter) {
            Image(ImageProvider(dial.bitmap), dialDescription(entry, lock = false), GlanceModifier.size(dial.widthDp.dp, dial.heightDp.dp))
        }
    }
    val (number, unit) = splitUnit(entry.elevationMain)
    Box(GlanceModifier.fillMaxSize().padding(bottom = 8.dp), contentAlignment = if (d > 0f) Alignment.BottomCenter else Alignment.Center) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(number, style = style(30.sp, FontWeight.Medium), maxLines = 1)
            if (unit.isNotEmpty()) Text(" $unit", style = style(15.sp, FontWeight.Medium, white(Op.SUB)), maxLines = 1,
                modifier = GlanceModifier.padding(bottom = 4.dp))
        }
    }
}

/** Medium: the full dial in the left column with the spot's readout under it; the header, ELEVATION and SUN on the right. */
@Composable
private fun Medium(entry: WidgetEntry, w: Float, h: Float, scale: Float) {
    val hasSpot = entry.markBearing != null && entry.markDistance != null
    val column = mediumColumn(w, h)
    val d = widgetDialSize(WidgetLayout.MEDIUM, w, h, hasSpot, false)
    val dial = WidgetDial.draw(d, half = false, marks = marks(entry, spotLabel = false, lock = true), scale = scale)
    Row(GlanceModifier.fillMaxSize().padding(8.dp)) {
        Column(GlanceModifier.width(column.dp).fillMaxHeight(), verticalAlignment = Alignment.CenterVertically,
            horizontalAlignment = Alignment.CenterHorizontally) {
            Image(ImageProvider(dial.bitmap), dialDescription(entry, lock = true), GlanceModifier.size(dial.widthDp.dp, dial.heightDp.dp))
            if (hasSpot) {
                Spacer(GlanceModifier.height(5.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(ImageProvider(WidgetDial.pinIcon(11f, scale)), null, GlanceModifier.size(11.dp))
                    Spacer(GlanceModifier.width(5.dp))
                    Text("${entry.markDistance} · ${entry.markPoint}", style = style(12.sp, FontWeight.Medium, white(Op.STRONG)), maxLines = 1)
                }
            }
        }
        Spacer(GlanceModifier.width(8.dp))
        Column(GlanceModifier.defaultWeight().fillMaxHeight()) {
            Header(entry.place, entry.asOfLong, entry.sunAltitude)
            Spacer(GlanceModifier.height(8.dp))
            Tile(GlanceModifier.defaultWeight(), { Caption("Elevation") }) {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(entry.elevationMain ?: "—", style = style(22.sp, FontWeight.Medium), maxLines = 1)
                    entry.elevationOther?.let {
                        Text("  $it", style = style(13.sp, color = white(Op.CAPTION)), maxLines = 1, modifier = GlanceModifier.padding(bottom = 2.dp))
                    }
                }
            }
            Spacer(GlanceModifier.height(8.dp))
            Tile(GlanceModifier.defaultWeight(), {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Caption("Sun · ")
                    Image(ImageProvider(WidgetDial.moonIcon(11f, scale, entry.moonPhase)), null, GlanceModifier.size(11.dp))
                    Caption(" ${entry.moonPercent}")
                }
            }) {
                val allDay = entry.sunAllDay
                if (allDay != null) Text(allDay, style = style(15.sp, FontWeight.Medium), maxLines = 1)
                else Row(verticalAlignment = Alignment.CenterVertically) {
                    SunTime(true, entry.sunrise, 15.sp)
                    Spacer(GlanceModifier.width(12.dp))
                    SunTime(false, entry.sunset, 15.sp)
                }
            }
        }
    }
}

/** Large: the header; the big dial with ELEVATION, SUN and MOON beside it; POSITION and the marked spot (and lock) below. */
@Composable
private fun Large(entry: WidgetEntry, w: Float, h: Float, scale: Float) {
    val hasSpot = entry.markBearing != null && entry.markDistance != null
    val lock = entry.lock
    val hasRow = hasSpot || lock != null
    val d = widgetDialSize(WidgetLayout.LARGE, w, h, hasSpot, hasRow)
    val dial = WidgetDial.draw(d, half = false, marks = marks(entry, spotLabel = true, lock = true), scale = scale)
    Column(GlanceModifier.fillMaxSize().padding(8.dp)) {
        Header(entry.place, entry.asOfLong, entry.sunAltitude)
        Spacer(GlanceModifier.height(8.dp))
        Row(GlanceModifier.fillMaxWidth().defaultWeight()) {
            Box(GlanceModifier.width(d.dp).fillMaxHeight(), contentAlignment = Alignment.Center) {
                Image(ImageProvider(dial.bitmap), dialDescription(entry, lock = true), GlanceModifier.size(dial.widthDp.dp, dial.heightDp.dp))
            }
            Spacer(GlanceModifier.width(8.dp))
            Column(GlanceModifier.defaultWeight().fillMaxHeight()) {
                // Tile contents go straight into the tile's column (RemoteViews limit how deep views nest).
                Tile(GlanceModifier.defaultWeight(), { Caption("Elevation") }) {
                    Text(entry.elevationMain ?: "—", style = style(20.sp, FontWeight.Medium), maxLines = 1)
                    entry.elevationOther?.let { Text(it, style = style(13.sp, color = white(Op.CAPTION)), maxLines = 1) }
                }
                Spacer(GlanceModifier.height(8.dp))
                val sunCaption = entry.sunAzimuth?.let { "Sun · ${Geo.jsRound(it) % 360}° ${Geo.point(it)}" } ?: "Sun"
                Tile(GlanceModifier.defaultWeight(), { Caption(sunCaption) }) {
                    val allDay = entry.sunAllDay
                    if (allDay != null) Text(allDay, style = style(15.sp, FontWeight.Medium), maxLines = 2)
                    else {
                        SunTime(true, entry.sunrise, 15.sp)
                        SunTime(false, entry.sunset, 15.sp)
                    }
                }
                Spacer(GlanceModifier.height(8.dp))
                Tile(GlanceModifier.defaultWeight(), { Caption("Moon") }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Image(ImageProvider(WidgetDial.moonIcon(15f, scale, entry.moonPhase)), null, GlanceModifier.size(15.dp))
                        Spacer(GlanceModifier.width(6.dp))
                        Text(entry.moonPercent, style = style(17.sp, FontWeight.Medium), maxLines = 1)
                    }
                    Text(entry.moonName, style = style(13.sp, color = white(Op.CAPTION)), maxLines = 1)
                }
            }
        }
        Spacer(GlanceModifier.height(8.dp))
        WideRow(44) {
            Caption("Position")
            Spacer(GlanceModifier.defaultWeight())
            Text(entry.coordinates.joinToString("  "), style = style(15.sp, FontWeight.Medium), maxLines = 1)
        }
        if (hasRow) {
            Spacer(GlanceModifier.height(8.dp))
            WideRow(42) {
                Image(ImageProvider(if (hasSpot) WidgetDial.pinIcon(14f, scale) else WidgetDial.lockIcon(14f, scale)), null, GlanceModifier.size(14.dp))
                Spacer(GlanceModifier.width(8.dp))
                Text(if (hasSpot) "Marked spot" else "Locked bearing", style = style(15.sp), maxLines = 1)
                Spacer(GlanceModifier.defaultWeight())
                val lockText = lock?.let { "${Geo.jsRound(it) % 360}°" }
                if (hasSpot) {
                    if (lockText != null) {
                        Image(ImageProvider(WidgetDial.lockIcon(14f, scale)), null, GlanceModifier.size(14.dp))
                        Spacer(GlanceModifier.width(4.dp))
                        Text(lockText, style = style(13.sp, color = white(Op.SUB)), maxLines = 1)
                        Spacer(GlanceModifier.width(8.dp))
                    }
                    Text("${entry.markDistance} · ${entry.markPoint}", style = style(15.sp, FontWeight.Bold), maxLines = 1)
                } else if (lockText != null) {
                    Text(lockText, style = style(15.sp, FontWeight.Bold), maxLines = 1)
                }
            }
        }
    }
}

/** A full-width frosted row, [height] dp, 12 in each side. */
@Composable
private fun WideRow(height: Int, content: @Composable RowScope.() -> Unit) {
    Row(GlanceModifier.fillMaxWidth().height(height.dp).cornerRadius(BearingsWidget.INNER.dp).background(Palette.tileFill).padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically) { content() }
}
