package com.bradcowdrey.bearings.widget

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import androidx.compose.ui.graphics.toArgb
import com.bradcowdrey.bearings.ui.Palette
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.sin

/**
 * The widget's compass (docs/DESIGN.md, Widgets; mock W2): the app's dial language (a dark disc, white ticks, the
 * pink N) fixed NORTH-UP, since a widget can't read the compass, carrying only bearings that are true wherever the
 * phone points: the sun (an amber rayed disc), the moon (a cream crescent for its phase), the marked spot (a pink
 * teardrop on the rim, a dashed line from you and its distance in a pill) and the locked bearing (a pink notch
 * outside the rim and a 14° arc on it).
 *
 * Tick density follows the drawn size, never the widget's: 180 dp and up 2° / 10° / 30° with the numbers every 30°;
 * 100 to 180 dp 10° / 30° with the letters N E S W; under 100 dp 10° / 30° and N alone.
 *
 * The half dial (Small) is the top half, W → N → E. A mark below it never moves onto the arc: it becomes a small
 * glyph just past the nearer end of the arc (E side for 90–180°, W side for 180–270°) with a chevron pointing its
 * true way. Glance can't draw vectors, so the dial is a bitmap, drawn in dp on a canvas scaled to [Dial.scale]
 * pixels per dp, on the widget's black (RGB 565: half the memory, and a widget update carries every bitmap).
 */
internal object WidgetDial {
    val PINK get() = Palette.accent.toArgb()
    val AMBER get() = Palette.sun.toArgb()
    val CREAM get() = Palette.cream.toArgb()
    val DISC = 0xFF151515.toInt()
    /** The moon's dark side, as on the app's dial. */
    val MOON_DARK get() = Palette.border.toArgb()
    /** Room either side of a half dial for the edge marks, and under it. */
    const val SIDE = 20f
    const val BELOW = 18f
    /** The longest side of a dial's bitmap, px (Large's 212 dp at 2 px per dp fits). */
    const val MAX_PX = 440f

    class Marks(
        val sun: Double? = null,
        val sunUp: Boolean = true,
        val moon: Double? = null,
        val moonUp: Boolean = true,
        /** 0 new, 0.5 full (MoonPhase.phase). */
        val moonPhase: Double = 0.5,
        val spot: Double? = null,
        /** "9.2 mi", in a pill by the spot's line; null for none. */
        val spotLabel: String? = null,
        /** The dashed line from you to the spot's pin. */
        val spotLine: Boolean = true,
        val lock: Double? = null,
    )

    /** A drawn dial: the bitmap and the size it is shown at, in dp. */
    class Dial(val bitmap: Bitmap, val widthDp: Float, val heightDp: Float)

    enum class Density { BIG, MID, SMALL }

    fun density(diameter: Float) = when {
        diameter >= 180f -> Density.BIG
        diameter >= 100f -> Density.MID
        else -> Density.SMALL
    }

    private fun white(a: Float) = android.graphics.Color.argb(Math.round(a * 255), 255, 255, 255)
    private fun withAlpha(color: Int, a: Float) = (color and 0x00FFFFFF) or (Math.round(a * 255) shl 24)
    private fun norm(d: Double): Double { val x = d % 360; return if (x < 0) x + 360 else x }
    private fun inHalf(d: Double) = norm(d).let { it <= 90 || it >= 270 }

    private val bold: Typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.BOLD)
    private val medium: Typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    private val regular: Typeface = Typeface.create(Typeface.SANS_SERIF, Typeface.NORMAL)

    /**
     * The dial [diameter] dp across, [half] for the top half only. A full dial's bitmap is [diameter] square; a half
     * dial's is [SIDE] wider each side and [BELOW] taller than its arc, for the edge marks.
     */
    fun draw(diameter: Float, half: Boolean, marks: Marks, scale: Float): Dial {
        val dens = density(diameter)
        val big = dens == Density.BIG; val mid = dens == Density.MID
        val m = if (marks.lock != null && !half) 5f else 2f
        val r = diameter / 2f - m
        val side = if (half) SIDE else 0f
        val cx = side + diameter / 2f
        val cy = if (half) r + m else diameter / 2f
        val wDp = diameter + 2 * side
        val hDp = if (half) cy + BELOW else diameter
        // At most MAX_PX on the long side (a big widget on a tablet would otherwise send megabytes in every update).
        val ps = minOf(scale, MAX_PX / max(wDp, hDp))
        val bitmap = Bitmap.createBitmap(max(1, Math.round(wDp * ps)), max(1, Math.round(hDp * ps)), Bitmap.Config.RGB_565)
        val canvas = Canvas(bitmap)
        canvas.drawColor(android.graphics.Color.BLACK)
        canvas.scale(ps, ps)
        val show = { d: Double -> !half || inHalf(d) }
        fun px(deg: Double, radius: Float) = cx + (sin(Math.toRadians(deg)) * radius).toFloat()
        fun py(deg: Double, radius: Float) = cy - (cos(Math.toRadians(deg)) * radius).toFloat()
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND }

        // The disc and its edge.
        fill.color = DISC
        stroke.color = white(0.16f); stroke.strokeWidth = 1f
        val oval = RectF(cx - r, cy - r, cx + r, cy + r)
        if (half) {
            val disc = Path().apply { moveTo(cx - r, cy); arcTo(oval, 180f, 180f, false); close() }
            canvas.drawPath(disc, fill); canvas.drawPath(disc, stroke)
        } else {
            canvas.drawCircle(cx, cy, r, fill); canvas.drawCircle(cx, cy, r, stroke)
        }

        // Ticks.
        val step = if (big) 2 else 10
        val lMaj = if (big) 11f else if (mid) 8f else 6f
        val lMid = if (big) 7f else if (mid) 4.5f else 3.5f
        val lMin = 3.5f
        val r0 = r - 2.5f
        var d = 0
        while (d < 360) {
            val deg = d.toDouble()
            if (show(deg)) {
                val major = d % 30 == 0; val ten = d % 10 == 0
                val len = if (major) lMaj else if (ten) lMid else lMin
                stroke.strokeWidth = if (major) (if (big) 2f else 1.6f) else if (ten) (if (big) 1.2f else 1f) else 0.8f
                stroke.color = when {
                    d == 0 -> PINK
                    major -> android.graphics.Color.WHITE
                    ten -> white(if (big) 0.6f else 0.55f)
                    else -> white(0.3f)
                }
                canvas.drawLine(px(deg, r0), py(deg, r0), px(deg, r0 - len), py(deg, r0 - len), stroke)
            }
            d += step
        }

        // Letters, and the numbers on the big dial.
        val fN = if (big) 18f else if (mid) 14f else 11f
        val fL = if (big) 15f else if (mid) 12f else 11f
        val rl = r0 - lMaj - 3f - fN * 0.5f
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textAlign = Paint.Align.CENTER }
        fun label(t: String, deg: Double, size: Float, face: Typeface, color: Int, radius: Float) {
            text.textSize = size; text.typeface = face; text.color = color
            val fm = text.fontMetrics
            canvas.drawText(t, px(deg, radius), py(deg, radius) - (fm.ascent + fm.descent) / 2f, text)
        }
        label("N", 0.0, fN, bold, PINK, rl)
        if (dens != Density.SMALL) {
            for ((l, deg) in listOf("E" to 90.0, "S" to 180.0, "W" to 270.0)) {
                if (show(deg)) label(l, deg, fL, medium, android.graphics.Color.WHITE, rl + (fN - fL) * 0.3f)
            }
        }
        if (big) {
            var n = 30
            while (n < 360) { if (n % 90 != 0 && show(n.toDouble())) label("$n", n.toDouble(), 11f, regular, white(0.6f), rl + 2f); n += 30 }
        }
        if (half) {
            stroke.color = white(0.22f); stroke.strokeWidth = 1f; stroke.strokeCap = Paint.Cap.BUTT
            canvas.drawLine(cx - r + 1f, cy, cx + r - 1f, cy, stroke)
            stroke.strokeCap = Paint.Cap.ROUND
        }
        // You, in the middle of the big dial: a faint cross and ring.
        if (!half && big) {
            stroke.color = white(0.07f); stroke.strokeWidth = 1f
            canvas.drawLine(cx, cy - 28f, cx, cy + 28f, stroke); canvas.drawLine(cx - 28f, cy, cx + 28f, cy, stroke)
            stroke.color = white(0.12f); canvas.drawCircle(cx, cy, 22f, stroke)
        }

        // The sun and the moon on the dial, or as edge marks off a half dial's arc.
        val ks = if (big) 5f else if (mid) 4f else 3f
        val km = if (big) 6.5f else if (mid) 5.2f else 4f
        val rm = if (big) r * 0.5f else if (mid) r * 0.4f else r * 0.44f
        val slots = intArrayOf(0, 0)
        fun edge(deg: Double, glyph: (Float, Float) -> Unit, color: Int) {
            val right = norm(deg) < 180
            val i = if (right) 1 else 0
            val ex = if (right) cx + r else cx - r
            val gx = ex + (if (right) 7f else -7f)
            val gy = cy + 2f - 18f * slots[i]
            slots[i]++
            glyph(gx, gy)
            val a = Math.toRadians(deg)
            val dx = sin(a).toFloat(); val dy = -cos(a).toFloat()
            val ax = gx + dx * 10f; val ay = gy + dy * 10f
            val qx = -dy; val qy = dx
            val chevron = Path().apply {
                moveTo(ax - dx * 4f + qx * 3.2f, ay - dy * 4f + qy * 3.2f); lineTo(ax, ay); lineTo(ax - dx * 4f - qx * 3.2f, ay - dy * 4f - qy * 3.2f)
            }
            stroke.color = color; stroke.strokeWidth = 1.6f; stroke.strokeJoin = Paint.Join.ROUND
            canvas.drawPath(chevron, stroke)
        }
        marks.sun?.let { az ->
            val alpha = if (marks.sunUp) 1f else 0.45f
            if (show(az)) sun(canvas, px(az, rm), py(az, rm), ks, withAlpha(AMBER, alpha))
            else if (half) edge(az, { x, y -> sun(canvas, x, y, 2.8f, withAlpha(AMBER, alpha)) }, withAlpha(AMBER, alpha))
        }
        marks.moon?.let { az ->
            if (show(az)) moon(canvas, px(az, rm), py(az, rm), km, marks.moonPhase)
            else if (half) edge(az, { x, y -> moon(canvas, x, y, 4.4f, marks.moonPhase) }, CREAM)
        }

        // The locked bearing: a short arc on the rim and a notch outside it (never on Small's half dial).
        marks.lock?.let { lock ->
            if (half) return@let
            stroke.color = PINK; stroke.strokeWidth = if (big) 3f else 2.4f
            canvas.drawArc(oval, (lock - 7 - 90).toFloat(), 14f, false, stroke)
            val n = if (big) 6f else 5f
            canvas.save(); canvas.rotate(lock.toFloat(), cx, cy)
            val notch = Path().apply { moveTo(cx, cy - r + n * 0.9f); lineTo(cx + n, cy - r - m + 0.5f); lineTo(cx - n, cy - r - m + 0.5f); close() }
            fill.color = PINK; canvas.drawPath(notch, fill)
            stroke.color = android.graphics.Color.BLACK; stroke.strokeWidth = 1f; canvas.drawPath(notch, stroke)
            canvas.restore()
        }

        // The marked spot: the dashed line from you, the teardrop on the rim, the distance in a pill.
        marks.spot?.let { b ->
            if (!show(b)) {
                if (half) {
                    edge(b, { x, y -> pin(canvas, x, y - 4f, 4f) }, PINK)
                    // The distance still reads, in the arc's middle under the N.
                    marks.spotLabel?.let { pillAt(canvas, it, cx, cy - minOf(r * 0.36f, rl - fN * 0.5f - 9f)) }
                }
                return@let
            }
            val hs = if (big) 7f else if (mid) 5.6f else 4.6f
            val rh = r0 - hs - 0.5f
            val tip = rh - hs * 2.1f
            if (marks.spotLine) {
                val dash = Paint(stroke).apply {
                    color = withAlpha(PINK, 0.75f); strokeWidth = if (big) 1.6f else 1.3f
                    pathEffect = if (big) DashPathEffect(floatArrayOf(3f, 3f), 0f) else DashPathEffect(floatArrayOf(2.5f, 2.5f), 0f)
                }
                val from = if (big) 6f else 4f
                canvas.drawLine(px(b, from), py(b, from), px(b, tip - 1f), py(b, tip - 1f), dash)
            }
            marks.spotLabel?.let { pill(canvas, it, b, cx, cy, if (half) r * 0.48f else rm * 1.02f, clockwise = !half, cyLimit = if (half) cy - 10f else null) }
            canvas.save(); canvas.rotate(b.toFloat(), cx, cy)
            pin(canvas, cx, cy - rh, hs, tipY = cy - tip)
            canvas.restore()
        }
        fill.color = android.graphics.Color.WHITE
        canvas.drawCircle(cx, cy, if (big) 3f else 2.4f, fill)
        return Dial(bitmap, wDp, hDp)
    }

    /** The sun: a disc of radius [k] with eight rays from 1.55 k to 2.2 k. */
    fun sun(canvas: Canvas, x: Float, y: Float, k: Float, color: Int) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawCircle(x, y, k, p)
        p.style = Paint.Style.STROKE; p.strokeCap = Paint.Cap.ROUND; p.strokeWidth = max(1f, k * 0.32f)
        for (i in 0 until 8) {
            val b = i * PI / 4
            val c = cos(b).toFloat(); val s = sin(b).toFloat()
            canvas.drawLine(x + c * k * 1.55f, y + s * k * 1.55f, x + c * k * 2.2f, y + s * k * 2.2f, p)
        }
    }

    /** The moon for its phase (lit side on the right while waxing), cream on its dark side. */
    fun moon(canvas: Canvas, cx: Float, cy: Float, r: Float, phase: Double, dark: Int = MOON_DARK) {
        canvas.drawCircle(cx, cy, r, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = dark })
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
        canvas.drawPath(lit, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CREAM })
    }

    /**
     * The spot's teardrop, upright: its head (radius [hs]) centred at ([x], [y]), its point at [tipY] (2.1 heads
     * below the head's centre by default), pink with a black edge and a white eye.
     */
    fun pin(canvas: Canvas, x: Float, y: Float, hs: Float, tipY: Float = y + hs * 2.1f) {
        val path = Path().apply {
            moveTo(x, tipY)
            cubicTo(x - hs * 0.5f, y + hs * 1.2f, x - hs, y + hs * 0.7f, x - hs, y)
            arcTo(RectF(x - hs, y - hs, x + hs, y + hs), 180f, 180f, false)
            cubicTo(x + hs, y + hs * 0.7f, x + hs * 0.5f, y + hs * 1.2f, x, tipY)
            close()
        }
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = PINK })
        canvas.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; color = android.graphics.Color.BLACK; strokeWidth = 1.2f; strokeJoin = Paint.Join.ROUND
        })
        canvas.drawCircle(x, y, hs * 0.38f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE })
    }

    /**
     * The distance pill (11 dp semibold, white on black 72% with a pink edge), beside the spot's line at [radius]:
     * on its clockwise side on a full dial, straight across from it on a half dial, kept clear of the line.
     */
    private fun pill(canvas: Canvas, label: String, bearing: Double, cx: Float, cy: Float, radius: Float, clockwise: Boolean, cyLimit: Float?) {
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; typeface = medium; color = android.graphics.Color.WHITE; textAlign = Paint.Align.CENTER }
        val tw = text.measureText(label) + 10f
        val a = Math.toRadians(bearing)
        val lx = cx + (sin(a) * radius).toFloat(); val ly = cy - (cos(a) * radius).toFloat()
        // Full dial: off the line's clockwise side (cos, sin). Half dial: straight across, away from the line's side
        // (clear of the N above). Far enough that the box clears the line.
        val sx = if (clockwise) cos(a).toFloat() else (if (sin(a) >= 0) -1f else 1f)
        val sy = if (clockwise) sin(a).toFloat() else 0f
        val reach = (tw / 2f) * abs(sx) + 8f * abs(sy) + 3f
        var x = lx + sx * reach; var y = ly + sy * reach
        if (cyLimit != null && y + 8f > cyLimit) y = cyLimit - 8f
        if (2 * cx > tw) x = x.coerceIn(tw / 2f, 2 * cx - tw / 2f)
        pillAt(canvas, label, x, y)
    }

    /** The distance pill centred at ([x], [y]). */
    private fun pillAt(canvas: Canvas, label: String, x: Float, y: Float) {
        val text = Paint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 11f; typeface = medium; color = android.graphics.Color.WHITE; textAlign = Paint.Align.CENTER }
        val tw = text.measureText(label) + 10f
        val box = RectF(x - tw / 2f, y - 8f, x + tw / 2f, y + 8f)
        canvas.drawRoundRect(box, 8f, 8f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.argb(184, 0, 0, 0) })
        canvas.drawRoundRect(box, 8f, 8f, Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE; strokeWidth = 1f; color = withAlpha(PINK, 0.55f)
        })
        val fm = text.fontMetrics
        canvas.drawText(label, x, y + 0.5f - (fm.ascent + fm.descent) / 2f, text)
    }

    // ---------- Small icons for the tiles (transparent, for the frosted tiles) ----------

    private fun icon(sizeDp: Float, scale: Float, draw: (Canvas) -> Unit): Bitmap {
        val px = max(1, Math.round(sizeDp * scale))
        val bitmap = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        canvas.scale(px / 14f, px / 14f)
        draw(canvas)
        return bitmap
    }

    /** The marked spot's teardrop, on a 14-unit square. */
    fun pinIcon(sizeDp: Float, scale: Float): Bitmap = icon(sizeDp, scale) { c ->
        val path = Path().apply {
            moveTo(7f, 13.6f)
            cubicTo(3.6f, 9.6f, 1.9f, 7.6f, 1.9f, 5.6f)
            arcTo(RectF(1.9f, 0.5f, 12.1f, 10.7f), 180f, 180f, false)
            cubicTo(12.1f, 7.6f, 10.4f, 9.6f, 7f, 13.6f)
            close()
        }
        c.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = PINK })
        c.drawCircle(7f, 5.6f, 1.9f, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = android.graphics.Color.WHITE })
    }

    /** The locked bearing's mark: a short pink arc over a notch. */
    fun lockIcon(sizeDp: Float, scale: Float): Bitmap = icon(sizeDp, scale) { c ->
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = PINK; style = Paint.Style.STROKE; strokeWidth = 2.4f; strokeCap = Paint.Cap.ROUND }
        c.drawArc(RectF(1f, 1.5f, 13f, 13.5f), -138f, 96f, false, p)
        c.drawPath(Path().apply { moveTo(7f, 11f); lineTo(11f, 4f); lineTo(3f, 4f); close() }, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = PINK })
    }

    /** The moon for its phase, on a 14-unit square. */
    fun moonIcon(sizeDp: Float, scale: Float, phase: Double): Bitmap = icon(sizeDp, scale) { c -> moon(c, 7f, 7f, 6f, phase) }

    /** The location header's sky, top to bottom (stretched to the header; the corners come from cornerRadius). */
    fun sky(top: Int, bottom: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(2, 48, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val p = Paint().apply { shader = android.graphics.LinearGradient(0f, 0f, 0f, 48f, top, bottom, android.graphics.Shader.TileMode.CLAMP) }
        canvas.drawRect(0f, 0f, 2f, 48f, p)
        return bitmap
    }
}
