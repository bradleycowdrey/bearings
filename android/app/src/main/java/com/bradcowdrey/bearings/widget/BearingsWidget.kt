package com.bradcowdrey.bearings.widget

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.Image
import androidx.glance.ImageProvider
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
import com.bradcowdrey.bearings.Sky
import com.bradcowdrey.bearings.ui.Op
import com.bradcowdrey.bearings.ui.Palette
import com.bradcowdrey.bearings.ui.white
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * The Home Screen widget, one that resizes, in Two Degrees' layout: small (the place, the elevation, the
 * coordinates), medium (plus the sun's direction on a small rose, sunrise and sunset in three columns, and
 * the moon) and large (a captioned grid, with the marked spot). Tapping it opens Bearings.
 */
class BearingsWidget : GlanceAppWidget() {
    companion object {
        val SMALL = DpSize(110.dp, 110.dp)
        val MEDIUM = DpSize(250.dp, 110.dp)
        val LARGE = DpSize(250.dp, 250.dp)
    }

    override val sizeMode = SizeMode.Responsive(setOf(SMALL, MEDIUM, LARGE))

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

/**
 * Two Degrees' widget look, on Bearings' warm near-black with its 3 dp crimson rule across the top
 * (docs/LOOK.md): white type with the warm greys, 1 dp dividers, captions in capitals.
 */
@Composable
fun WidgetContent(entry: WidgetEntry) {
    val size = LocalSize.current
    Column(
        GlanceModifier.fillMaxSize().cornerRadius(22.dp).background(Palette.bg)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        Box(GlanceModifier.fillMaxWidth().height(3.dp).background(Palette.crimson)) {}
        Box(GlanceModifier.fillMaxWidth().defaultWeight().padding(14.dp)) {
            when {
                entry.snapshot == null -> Empty()
                size.height >= BearingsWidget.LARGE.height -> Large(entry)
                size.width >= BearingsWidget.MEDIUM.width -> Medium(entry)
                else -> Small(entry)
            }
        }
    }
}

/** A 1 dp line across (Glance has no half-dp line). */
@Composable
private fun Rule() {
    Box(GlanceModifier.fillMaxWidth().height(1.dp).background(Palette.widgetRule)) {}
}

/** A 1 dp line down. */
@Composable
private fun RuleDown() {
    Box(GlanceModifier.width(1.dp).fillMaxHeight().background(Palette.widgetRule)) {}
}

@Composable
private fun Empty() {
    Column(GlanceModifier.fillMaxSize()) {
        Text("Bearings", style = style(15.sp, FontWeight.Medium), maxLines = 1)
        Spacer(GlanceModifier.defaultWeight())
        Text("Open Bearings to find where you are.", style = style(13.sp, color = Palette.textSecondary), maxLines = 3)
    }
}

/** Two Degrees' reading block: the place, the elevation large, the other unit and the time, and the coordinates at the foot. */
@Composable
private fun Small(entry: WidgetEntry) {
    Column(GlanceModifier.fillMaxSize()) {
        Text(entry.place, style = style(13.sp, FontWeight.Medium), maxLines = 2)
        Text(entry.elevationMain ?: "—", style = style(30.sp, FontWeight.Medium), maxLines = 1)
        Text(listOfNotNull(entry.elevationOther, entry.asOf).joinToString(" · "), style = style(12.sp, color = Palette.textMuted), maxLines = 1)
        Spacer(GlanceModifier.defaultWeight())
        entry.coordinates.forEach { Text(it, style = style(11.sp, FontWeight.Medium, Palette.textSecondary), maxLines = 1) }
    }
}

/** The reading block | the sun's direction, sunrise and sunset in three columns, with the moon under them. */
@Composable
private fun Medium(entry: WidgetEntry) {
    Row(GlanceModifier.fillMaxSize()) {
        Box(GlanceModifier.width(124.dp).fillMaxHeight()) { Small(entry) }
        Spacer(GlanceModifier.width(8.dp))
        RuleDown()
        Spacer(GlanceModifier.width(8.dp))
        Column(GlanceModifier.defaultWeight().fillMaxHeight()) {
            SunColumns(entry)
            Spacer(GlanceModifier.defaultWeight())
            MoonRow(entry)
        }
    }
}

/** Sun (the rose, its direction, up or below), Sunrise and Sunset, as Two Degrees' hours; one wide column in polar day or night. */
@Composable
private fun SunColumns(entry: WidgetEntry) {
    Row(GlanceModifier.fillMaxWidth()) {
        val az = entry.sunAzimuth
        val altitude = entry.snapshot?.let { Sky.sunPosition(System.currentTimeMillis().toDouble(), it.latitude, it.longitude).altitude }
        SunColumn("Sun", Palette.cream, az?.let { "${Geo.jsRound(it) % 360}° ${Geo.point(it)}" } ?: "—",
            if (altitude == null || altitude <= 0) "Below" else "${Geo.jsRound(altitude)}° up") { Rose(entry, 34) }
        val allDay = entry.sunAllDay
        if (allDay != null) {
            Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
                Spacer(GlanceModifier.height(14.dp))
                Box(GlanceModifier.height(34.dp), contentAlignment = Alignment.Center) {
                    Image(ImageProvider(horizonBitmap(allDay.contains("up"), 54)), null, GlanceModifier.size(18.dp))
                }
                Text(allDay, style = style(13.sp, FontWeight.Medium, align = TextAlign.Center), maxLines = 2)
            }
        } else {
            val (riseTime, riseSub) = splitClock(entry.sunrise)
            val (setTime, setSub) = splitClock(entry.sunset)
            SunColumn("Sunrise", Palette.textMuted, riseTime, riseSub) {
                Image(ImageProvider(horizonBitmap(true, 54)), null, GlanceModifier.size(18.dp))
            }
            SunColumn("Sunset", Palette.textMuted, setTime, setSub) {
                Image(ImageProvider(horizonBitmap(false, 54)), null, GlanceModifier.size(18.dp))
            }
        }
    }
}

/** "6:42 AM" → "6:42" and "AM"; "06:42" → "06:42" and nothing. */
private fun splitClock(clock: String?): Pair<String, String> {
    val c = clock?.replace('\u202F', ' ')?.replace('\u00A0', ' ')?.trim() ?: return "—" to ""
    val i = c.lastIndexOf(' ')
    return if (i > 0) c.substring(0, i) to c.substring(i + 1) else c to ""
}

/** One column: a label, a picture in a 34 dp band, the value and a line under it. */
@Composable
private fun RowScope.SunColumn(label: String, labelColor: Color, value: String, sub: String, picture: @Composable () -> Unit) {
    Column(GlanceModifier.defaultWeight(), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = style(10.sp, FontWeight.Medium, labelColor, TextAlign.Center), maxLines = 1)
        Box(GlanceModifier.height(34.dp), contentAlignment = Alignment.Center) { picture() }
        Text(value, style = style(13.sp, FontWeight.Medium, align = TextAlign.Center), maxLines = 1)
        Text(sub, style = style(10.sp, color = Palette.textMuted, align = TextAlign.Center), maxLines = 1)
    }
}

@Composable
private fun MoonRow(entry: WidgetEntry) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Image(ImageProvider(moonBitmap(entry.moonPhase, 42)), null, GlanceModifier.size(14.dp))
        Spacer(GlanceModifier.width(6.dp))
        Text(entry.moonLine, style = style(11.sp, color = Palette.textMuted), maxLines = 1)
    }
}

@Composable
private fun Rose(entry: WidgetEntry, sizeDp: Int) {
    val description = entry.sunAzimuth?.let { "Sun ${Math.round(it) % 360} degrees" }
    Image(ImageProvider(roseBitmap(entry.sunAzimuth, entry.sunUp, sizeDp * 3)), description, GlanceModifier.size(sizeDp.dp))
}

/** The top row as the large Apple widget, then the info grid with captions, then the marked spot and the time. */
@Composable
private fun Large(entry: WidgetEntry) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(GlanceModifier.defaultWeight()) {
                Text(entry.place, style = style(13.sp, FontWeight.Medium), maxLines = 2)
                Row(verticalAlignment = Alignment.Bottom) {
                    Text(entry.elevationMain ?: "—", style = style(34.sp, FontWeight.Medium), maxLines = 1)
                    entry.elevationOther?.let {
                        Text("  $it", style = style(14.sp, FontWeight.Medium, Palette.textMuted), maxLines = 1,
                            modifier = GlanceModifier.padding(bottom = 6.dp))
                    }
                }
            }
            Rose(entry, 56)
        }
        Spacer(GlanceModifier.height(8.dp))
        Rule()
        Spacer(GlanceModifier.height(8.dp))
        // The grid in a column of its own: Glance keeps at most 10 children in a Column and drops the rest.
        Column(GlanceModifier.fillMaxWidth()) {
            val coords = entry.coordinates
            if (coords.size == 2) {
                GridRow("Latitude", coords[0], "Longitude", coords[1])
            } else {
                GridRow("Coordinates", coords.firstOrNull() ?: "—", null, null)
            }
            val allDay = entry.sunAllDay
            if (allDay != null) GridRow("Sun", allDay, "Moon", entry.moonLine)
            else GridRow("Sunrise", entry.sunrise ?: "—", "Sunset", entry.sunset ?: "—")
            if (allDay == null) GridRow("Moon", entry.moonLine, null, null)
        }
        Spacer(GlanceModifier.defaultWeight())
        Rule()
        Spacer(GlanceModifier.height(8.dp))
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(entry.markLine ?: "", style = style(12.sp, FontWeight.Medium), maxLines = 1, modifier = GlanceModifier.defaultWeight())
            Text(entry.asOf, style = style(11.sp, color = Palette.textMuted, align = TextAlign.End), maxLines = 1)
        }
    }
}

/** Two captioned values side by side (or one across), as in the app's tiles: the caption in capitals, white at 60%. */
@Composable
private fun GridRow(title1: String, value1: String, title2: String?, value2: String?) {
    Row(GlanceModifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Column(GlanceModifier.defaultWeight()) {
            Text(title1.uppercase(), style = style(10.sp, FontWeight.Medium, white(Op.CAPTION)), maxLines = 1)
            Text(value1, style = style(13.sp, FontWeight.Medium), maxLines = 1)
        }
        if (title2 != null && value2 != null) {
            Spacer(GlanceModifier.width(8.dp))
            Column(GlanceModifier.defaultWeight()) {
                Text(title2.uppercase(), style = style(10.sp, FontWeight.Medium, white(Op.CAPTION)), maxLines = 1)
                Text(value2, style = style(13.sp, FontWeight.Medium), maxLines = 1)
            }
        }
    }
}

// ---------- Small pictures (Glance draws bitmaps, not canvases) ----------

/** The moon drawn for its phase (lit side on the right while waxing), as on the dial. */
internal fun moonBitmap(phase: Double, px: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val r = px / 2f - 1f; val cx = px / 2f; val cy = px / 2f
    canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Palette.tickMinor.toArgb() })
    val waxing = phase < 0.5
    val k = cos(2 * PI * phase).toFloat()
    val rx = maxOf(abs(k) * r, 0.01f)
    val bulgeRight = if (waxing) k > 0 else k < 0
    val lit = Path().apply {
        moveTo(cx, cy - r)
        arcTo(RectF(cx - r, cy - r, cx + r, cy + r), -90f, if (waxing) 180f else -180f, false)
        arcTo(RectF(cx - rx, cy - r, cx + rx, cy + r), 90f, if (bulgeRight) -180f else 180f, false)
        close()
    }
    canvas.drawPath(lit, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Palette.cream.toArgb() })
    return bitmap
}

/** A small compass rose, north up, with the sun's direction (faint when it's below the horizon). */
private fun roseBitmap(sunAzimuth: Double?, sunUp: Boolean, px: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val c = px / 2f; val r = px / 2f - px * 0.04f
    val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    paint.color = Palette.dial.toArgb(); canvas.drawCircle(c, c, r, paint)
    paint.style = Paint.Style.STROKE; paint.strokeWidth = px * 0.02f; paint.color = Palette.border.toArgb()
    canvas.drawCircle(c, c, r, paint)
    paint.strokeCap = Paint.Cap.ROUND
    for (i in 0 until 8) {
        val a = i * PI / 4
        val len = if (i % 2 == 0) 0.16f else 0.08f
        paint.color = (if (i == 0) Palette.north else Palette.textMuted).toArgb()
        paint.strokeWidth = px * (if (i % 2 == 0) 0.035f else 0.02f)
        canvas.drawLine(c + (sin(a) * r * 0.94f).toFloat(), c - (cos(a) * r * 0.94f).toFloat(),
            c + (sin(a) * r * (0.94f - len)).toFloat(), c - (cos(a) * r * (0.94f - len)).toFloat(), paint)
    }
    if (sunAzimuth != null) {
        val a = Math.toRadians(sunAzimuth)
        val sun = Palette.sun.copy(alpha = if (sunUp) 1f else 0.35f).toArgb()
        paint.color = sun; paint.strokeWidth = px * 0.03f
        canvas.drawLine(c, c, c + (sin(a) * r * 0.5f).toFloat(), c - (cos(a) * r * 0.5f).toFloat(), paint)
        paint.style = Paint.Style.FILL
        canvas.drawCircle(c + (sin(a) * r * 0.6f).toFloat(), c - (cos(a) * r * 0.6f).toFloat(), px * 0.08f, paint)
    }
    return bitmap
}

/** The sun half over the horizon with a small arrow, up for sunrise and down for sunset (and for polar day and night). */
private fun horizonBitmap(rising: Boolean, px: Int): Bitmap {
    val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bitmap)
    val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Palette.sun.toArgb() }
    val horizon = px * 0.72f
    val c = px / 2f; val r = px * 0.22f
    canvas.drawArc(RectF(c - r, horizon - r, c + r, horizon + r), 180f, 180f, true, paint)
    paint.style = Paint.Style.STROKE; paint.strokeWidth = px * 0.07f; paint.strokeCap = Paint.Cap.ROUND
    canvas.drawLine(px * 0.08f, horizon, px * 0.92f, horizon, paint)
    // The arrow above the sun.
    val tip = if (rising) px * 0.06f else px * 0.30f
    val base = if (rising) px * 0.30f else px * 0.06f
    canvas.drawLine(c, base, c, tip, paint)
    val wing = px * 0.10f
    val back = if (rising) tip + wing else tip - wing
    canvas.drawLine(c, tip, c - wing, back, paint)
    canvas.drawLine(c, tip, c + wing, back, paint)
    return bitmap
}
