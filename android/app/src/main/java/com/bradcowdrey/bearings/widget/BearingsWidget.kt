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
import com.bradcowdrey.bearings.MainActivity
import com.bradcowdrey.bearings.ui.Palette
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * The Home Screen widget, one that resizes: small (the place, the elevation, the coordinates), medium
 * (plus sunrise, sunset, the moon and a small rose with the sun's direction) and large (all of that as a
 * grid, with the marked spot). Tapping it opens Bearings.
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

@Composable
fun WidgetContent(entry: WidgetEntry) {
    val size = LocalSize.current
    Box(
        GlanceModifier.fillMaxSize().cornerRadius(22.dp).background(Palette.bg)
            .clickable(actionStartActivity<MainActivity>()),
    ) {
        Box(GlanceModifier.fillMaxSize().padding(14.dp)) {
            when {
                entry.snapshot == null -> Empty()
                size.height >= BearingsWidget.LARGE.height -> Large(entry)
                size.width >= BearingsWidget.MEDIUM.width -> Medium(entry)
                else -> Small(entry)
            }
        }
    }
}

@Composable
private fun Empty() {
    Column(GlanceModifier.fillMaxSize()) {
        Text("Bearings", style = style(15.sp, FontWeight.Medium), maxLines = 1)
        Spacer(GlanceModifier.defaultWeight())
        Text("Open Bearings to find where you are.", style = style(13.sp, color = Palette.textMuted), maxLines = 3)
    }
}

@Composable
private fun Small(entry: WidgetEntry) {
    Column(GlanceModifier.fillMaxSize()) {
        Text(entry.place, style = style(13.sp, FontWeight.Medium), maxLines = 2)
        Spacer(GlanceModifier.height(2.dp))
        Text(entry.elevationMain ?: "—", style = style(24.sp, FontWeight.Medium), maxLines = 1)
        Text(listOfNotNull(entry.elevationOther, entry.asOf).joinToString(" · "), style = style(11.sp, color = Palette.textMuted), maxLines = 1)
        Spacer(GlanceModifier.defaultWeight())
        entry.coordinates.forEach { Text(it, style = style(10.sp, color = Palette.textSecondary), maxLines = 1) }
    }
}

@Composable
private fun Medium(entry: WidgetEntry) {
    Row(GlanceModifier.fillMaxSize()) {
        Box(GlanceModifier.width(124.dp).fillMaxHeight()) { Small(entry) }
        Spacer(GlanceModifier.width(10.dp))
        Column(GlanceModifier.defaultWeight().fillMaxHeight()) {
            Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(GlanceModifier.defaultWeight()) { SunLines(entry) }
                Rose(entry, 44)
            }
            Spacer(GlanceModifier.defaultWeight())
            MoonRow(entry)
        }
    }
}

@Composable
private fun SunLines(entry: WidgetEntry) {
    val allDay = entry.sunAllDay
    if (allDay != null) {
        Text(allDay, style = style(13.sp, FontWeight.Medium), maxLines = 2)
    } else {
        Text("Sunrise ${entry.sunrise ?: "—"}", style = style(13.sp, FontWeight.Medium), maxLines = 1)
        Text("Sunset ${entry.sunset ?: "—"}", style = style(13.sp, FontWeight.Medium), maxLines = 1)
    }
}

@Composable
private fun MoonRow(entry: WidgetEntry) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Image(ImageProvider(moonBitmap(entry.moonPhase, 48)), null, GlanceModifier.size(16.dp))
        Spacer(GlanceModifier.width(6.dp))
        Text(entry.moonLine, style = style(12.sp, color = Palette.textSecondary), maxLines = 1)
    }
}

@Composable
private fun Rose(entry: WidgetEntry, sizeDp: Int) {
    val description = entry.sunAzimuth?.let { "Sun ${Math.round(it) % 360} degrees" }
    Image(ImageProvider(roseBitmap(entry.sunAzimuth, entry.sunUp, sizeDp * 3)), description, GlanceModifier.size(sizeDp.dp))
}

@Composable
private fun Large(entry: WidgetEntry) {
    Column(GlanceModifier.fillMaxSize()) {
        Row(GlanceModifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(GlanceModifier.defaultWeight()) {
                Text(entry.place, style = style(15.sp, FontWeight.Medium), maxLines = 2)
                Text(entry.elevationMain ?: "—", style = style(28.sp, FontWeight.Medium), maxLines = 1)
                Text(listOfNotNull(entry.elevationOther, entry.asOf).joinToString(" · "), style = style(12.sp, color = Palette.textMuted), maxLines = 1)
            }
            Rose(entry, 64)
        }
        Spacer(GlanceModifier.height(10.dp))
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
        Spacer(GlanceModifier.defaultWeight())
        entry.markLine?.let { Text(it, style = style(13.sp, FontWeight.Medium, Palette.accent), maxLines = 1) }
    }
}

/** Two labelled values side by side (or one across), as in the app's tiles. */
@Composable
private fun GridRow(title1: String, value1: String, title2: String?, value2: String?) {
    Row(GlanceModifier.fillMaxWidth().padding(bottom = 8.dp)) {
        Column(GlanceModifier.defaultWeight()) {
            Text(title1, style = style(11.sp, FontWeight.Medium, Palette.textMuted), maxLines = 1)
            Text(value1, style = style(13.sp, FontWeight.Medium), maxLines = 1)
        }
        if (title2 != null && value2 != null) {
            Spacer(GlanceModifier.width(8.dp))
            Column(GlanceModifier.defaultWeight()) {
                Text(title2, style = style(11.sp, FontWeight.Medium, Palette.textMuted), maxLines = 1)
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
        paint.color = (if (i == 0) Palette.accent else Palette.textMuted).toArgb()
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
