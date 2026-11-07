package com.bradcowdrey.bearings.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocationOff
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.bradcowdrey.bearings.DialBody
import com.bradcowdrey.bearings.Geo
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin

/** What's on the dial besides the card itself, all as directions on the card. */
class DialMarks(
    val lock: Double? = null,
    val sun: DialBody? = null,
    val moon: DialBody? = null,
    /** 0 new, 0.5 full (see MoonPhase). */
    val moonPhase: Double = 0.5,
    /** The marked spot's direction. */
    val mark: Double? = null,
)

/**
 * The compass card: ticks every 2°, numbers every 30°, the points, and on it the sun, the moon, the
 * marked spot's pin and the locked bearing. It turns opposite to the phone under a fixed lubber line at
 * the top; a bubble level sits in the middle. Drawn on a 400-unit square, like the web and Apple versions.
 * With [noCompass] (docs/REFINE.md §4.2) the rose drops to 40%, the lubber line goes, and a "no compass"
 * glyph sits in the middle with "N ↑ fixed" at the top of the ring, so the sun and moon read from north.
 */
@Composable
fun Dial(rotation: Double, heading: Double?, marks: DialMarks, tilt: Pair<Float, Float>?, modifier: Modifier = Modifier, noCompass: Boolean = false) {
    val measurer = rememberTextMeasurer()
    val labels = remember { mutableMapOf<String, androidx.compose.ui.text.TextLayoutResult>() }
    Box(modifier) {
        Canvas(Modifier.fillMaxSize().graphicsLayer { alpha = if (noCompass) 0.4f else 1f }) {
            val k = size.minDimension / 400f
            val c = Offset(size.width / 2, size.height / 2)
            fun label(t: String, deg: Float, radius: Float, sizePt: Float, weight: FontWeight, color: Color) {
                val key = "$t/$sizePt/$k"
                val layout = labels.getOrPut(key) {
                    measurer.measure(t, androidx.compose.ui.text.TextStyle(fontFamily = Inter, fontSize = (sizePt * k).toSp(), fontWeight = weight))
                }
                rotate(deg, pivot = c) {
                    drawText(layout, color = color, topLeft = Offset(c.x - layout.size.width / 2f, c.y - radius * k - layout.size.height / 2f))
                }
            }
            // Where a direction on the card is on the screen, at a radius in card units.
            fun at(deg: Double, radius: Float): Offset {
                val a = Math.toRadians(deg + rotation)
                return Offset(c.x + (sin(a) * radius * k).toFloat(), c.y - (cos(a) * radius * k).toFloat())
            }
            // A faint white disc with a 1 dp edge, as Two Degrees' tiles (docs/LOOK.md).
            drawCircle(Palette.tileFill, radius = 196 * k, center = c)
            drawCircle(Palette.tileStroke, radius = 196 * k, center = c, style = Stroke(Look.stroke.toPx()))
            rotate(rotation.toFloat(), pivot = c) {
                for (d in 0 until 360 step 2) {
                    val major = d % 30 == 0; val mid = d % 10 == 0
                    val len = if (major) 18f else if (mid) 12f else 6f
                    val w = if (major) 2.4f else if (mid) 1.4f else 1f
                    val col = if (d == 0) Palette.north else if (major) Color.White else if (mid) white(Op.CAPTION) else white(Op.MINOR)
                    rotate(d.toFloat(), pivot = c) {
                        drawLine(col, Offset(c.x, c.y - 188 * k), Offset(c.x, c.y - (188 - len) * k), strokeWidth = w * k, cap = StrokeCap.Round)
                    }
                }
                for (d in 30 until 360 step 30) if (d % 90 != 0) label("$d", d.toFloat(), 149f, 15f, FontWeight.Medium, white(Op.CAPTION))
                for ((l, d) in listOf("NE" to 45f, "SE" to 135f, "SW" to 225f, "NW" to 315f)) label(l, d, 147f, 13f, FontWeight.SemiBold, white(Op.POINTS))
                label("N", 0f, 147f, 30f, FontWeight.SemiBold, Palette.north)
                for ((l, d) in listOf("E" to 90f, "S" to 180f, "W" to 270f)) label(l, d, 147f, 26f, FontWeight.SemiBold, Color.White)
                val mark = marks.mark
                if (mark != null) rotate(mark.toFloat(), pivot = c) { pin(c, k) }
                val lock = marks.lock
                if (lock != null) {
                    rotate(lock.toFloat(), pivot = c) {
                        val p = Path().apply {
                            moveTo(c.x, c.y - 190 * k); lineTo(c.x + 7 * k, c.y - 200 * k); lineTo(c.x - 7 * k, c.y - 200 * k); close()
                        }
                        drawPath(p, Color.White)
                    }
                    if (heading != null) {
                        val sweep = Geo.delta(lock, heading)
                        if (abs(sweep) >= 0.5) {
                            val r = 190 * k
                            drawArc(white(Op.BODY), startAngle = (lock - 90).toFloat(), sweepAngle = sweep.toFloat(), useCenter = false,
                                topLeft = Offset(c.x - r, c.y - r), size = Size(2 * r, 2 * r), style = Stroke(6 * k, cap = StrokeCap.Round))
                        }
                    }
                }
            }
            // The sun and moon stay upright as the card turns, so they're placed rather than rotated.
            val moon = marks.moon
            if (moon != null) moonGlyph(at(moon.azimuth, 118f), 9 * k, marks.moonPhase, if (moon.up) 1f else 0.35f)
            val sun = marks.sun
            if (sun != null) sunGlyph(at(sun.azimuth, 118f), k, if (sun.up) 1f else 0.35f)
            // Fixed: the lubber line (where the phone points), cross hairs and the level's rings.
            if (!noCompass) {
                val lubber = Path().apply { moveTo(c.x, c.y - 200 * k); lineTo(c.x + 9 * k, c.y - 184 * k); lineTo(c.x - 9 * k, c.y - 184 * k); close() }
                drawPath(lubber, Color.White)
            }
            val hair = Color.White.copy(alpha = 0.07f)
            drawLine(hair, Offset(c.x, c.y - 100 * k), Offset(c.x, c.y + 100 * k), 1f)
            drawLine(hair, Offset(c.x - 100 * k, c.y), Offset(c.x + 100 * k, c.y), 1f)
            drawCircle(white(Op.TRACK), radius = 40 * k, center = c, style = Stroke(1.5f))
            drawCircle(white(Op.TRACK), radius = 13 * k, center = c, style = Stroke(1.5f))
            if (tilt != null) {
                // The bubble rises to the high side: opposite to gravity, 30° of tilt to the ring's edge.
                val degX = Math.toDegrees(asin(tilt.first.toDouble().coerceIn(-1.0, 1.0)))
                val degY = Math.toDegrees(asin(tilt.second.toDouble().coerceIn(-1.0, 1.0)))
                val x = (-degX / 30).coerceIn(-1.0, 1.0); val y = (-degY / 30).coerceIn(-1.0, 1.0)
                val len = hypot(x, y); val s = if (len > 1) 1 / len else 1.0
                val level = hypot(degX, degY) < 2
                drawCircle(if (level) Palette.level else Color.White, radius = 11 * k,
                    center = Offset(c.x + (x * s * 40 * k).toFloat(), c.y + (y * s * 40 * k).toFloat()))
            }
        }
        if (noCompass) {
            Icon(Icons.Filled.LocationOff, null, tint = Color.White, modifier = Modifier.align(Alignment.Center).size(28.dp))
            Text("N ↑ fixed", style = text(11f, FontWeight.SemiBold, white(Op.SUB)), textAlign = TextAlign.Center,
                // Inside the ring, under the N (a quarter of the way down).
                modifier = Modifier.align(BiasAlignment(0f, -0.5f)).fillMaxWidth())
        }
    }
}

/** The marked spot: a white teardrop on the outer ring, its point toward the middle (drawn at the top), with a black hole and edge. */
private fun DrawScope.pin(c: Offset, k: Float) {
    val head = Offset(c.x, c.y - 194 * k)
    val r = 6.5f * k
    val drop = Path().apply {
        moveTo(c.x, c.y - 178 * k)
        lineTo(c.x - r * 0.92f, head.y + r * 0.4f)
        lineTo(c.x + r * 0.92f, head.y + r * 0.4f)
        close()
    }
    val edge = Stroke(1.2f * k)
    drawPath(drop, Color.Black, style = edge)
    drawCircle(Color.Black, r, head, style = edge)
    drawPath(drop, Color.White)
    drawCircle(Color.White, r, head)
    drawCircle(Color.Black, r * 0.38f, head)
}

/** An amber disc with eight short rays. */
private fun DrawScope.sunGlyph(center: Offset, k: Float, alpha: Float) {
    val amber = Palette.sun.copy(alpha = alpha)
    drawCircle(amber, 7.5f * k, center)
    for (i in 0 until 8) {
        val a = i * PI / 4
        val dx = sin(a).toFloat(); val dy = -cos(a).toFloat()
        drawLine(amber, center + Offset(dx * 11 * k, dy * 11 * k), center + Offset(dx * 15.5f * k, dy * 15.5f * k), strokeWidth = 2.2f * k, cap = StrokeCap.Round)
    }
}

/** The moon for its phase: the dark part faintly, the lit part in cream. */
fun DrawScope.moonGlyph(center: Offset, r: Float, phase: Double, alpha: Float) {
    drawCircle(Palette.tickMinor.copy(alpha = 0.7f * alpha), r, center)
    drawPath(moonPath(phase, r, center), Palette.cream.copy(alpha = alpha))
}

/**
 * The lit part of the moon (lit on the right while waxing, as seen from the north): along the lit half's
 * edge, then back along the terminator, an ellipse whose width follows the phase.
 */
fun moonPath(phase: Double, r: Float, c: Offset): Path {
    val waxing = phase < 0.5
    val w = cos(2 * PI * phase).toFloat()
    val rx = maxOf(abs(w) * r, 0.01f)
    val bulgeRight = if (waxing) w > 0 else w < 0
    return Path().apply {
        moveTo(c.x, c.y - r)
        arcTo(Rect(c.x - r, c.y - r, c.x + r, c.y + r), -90f, if (waxing) 180f else -180f, false)
        arcTo(Rect(c.x - rx, c.y - r, c.x + rx, c.y + r), 90f, if (bulgeRight) -180f else 180f, false)
        close()
    }
}
