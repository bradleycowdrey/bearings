package com.bradcowdrey.bearings

import android.content.Context
import android.graphics.Paint
import android.graphics.Typeface
import androidx.core.content.res.ResourcesCompat
import com.bradcowdrey.bearings.ui.GridMode
import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.ui.MapDark
import com.bradcowdrey.bearings.ui.LayoutPlan
import com.bradcowdrey.bearings.ui.NightContrast
import com.bradcowdrey.bearings.ui.TextFit
import com.bradcowdrey.bearings.ui.TileKind
import com.bradcowdrey.bearings.widget.Snapshot
import com.bradcowdrey.bearings.widget.WidgetData
import kotlinx.coroutines.delay
import java.io.File
import kotlin.math.abs

/**
 * `--ez selftest true` in the emulator (CI): the core formats, sun, moon and distances, a real location
 * fix (CI places the emulator at Maroon Bells, Colorado), the live ground elevation and place name for it,
 * the compass state, the widget's saved data, and the bottom-up layout planner (docs/REFINE.md §3.3, §4.7):
 * the golden table (C3.3: devices × layouts × sample, live, no compass, locked, marked × text sizes, portrait and
 * landscape) must keep every gap at its token × k, leave at most 24 dp at the bottom, show no block partly, keep
 * tiles under their cap and every dial at or above its floor (the owner's rule: in one portrait column at text sizes
 * up to 1.3, no dial under min(0.40 H, C − 16)), and give four distinct layouts (each step changes the
 * grid, Medium → Large moves the map to the header, Large's dial is 16 or more over Medium's), as must the plan
 * for this screen; every tile row's widths and gaps add up to its column; the header time and the Sun times never
 * need "…" at text sizes 1.0, 1.3 and 2.0 (measured with the app's own font); the no-heading dash is rendered and
 * its ink found on the digits' centre-line (not the string compared); both Position lines share one size; the lock
 * row's label and cue never split; the map labels are one upright colour; coordinates never carry "…"; and night
 * mode's secondary text is 4.5:1 or better. Writes files/report.txt, first line "ALL PASSED" or "FAILED …"; CI
 * then photographs the screen.
 */
object SelfTest {
    suspend fun run(context: Context, nav: Navigator) {
        val lines = mutableListOf<String>()
        var failed = 0
        fun check(ok: Boolean, what: String) { lines += "${if (ok) "PASS" else "FAIL"} $what"; if (!ok) failed++ }

        for ((name, ok) in CoreChecks.run()) check(ok, name)

        // Naming the place: the bundled list (offline) and the whole chain (the phone's geocoder first).
        val listed = Places.nearby(39.09898, -106.94117, feet = true)
        check(Places.all.size > 30_000 && listed == "66 mi NE of Montrose, Colorado", "Nearest listed place (${Places.all.size} places: $listed)")
        val named = Places.name(context, 39.09898, -106.94117, feet = true)
        check(!named.isNullOrBlank(), "Place name at Maroon Bells ($named)")

        // The widget's data: saved and read back the same, then put back as it was.
        val before = WidgetData.raw(context)
        val snapshot = Snapshot(39.09898, -106.94117, 5.0, 2922.0, false, "Maroon Bells, Colorado", 1793548800000L)
        WidgetData.save(context, snapshot)
        val back = WidgetData.read(context)
        val entry = WidgetData.entry(context, now = Navigator.SAMPLE_TIME)
        WidgetData.restore(context, before)
        check(back == snapshot && entry.place == "Maroon Bells, Colorado" && entry.sunrise != null && entry.moonLine.endsWith("Last quarter"),
            "Widget data saved and read back (${entry.place}, ${entry.elevationMain}, ${entry.moonLine})")
        nav.refreshAccess(asked = true)
        nav.start()
        var waited = 0
        while (nav.fix == null && waited < 60) { delay(500); waited++ }
        val fix = nav.fix
        check(fix != null && abs(fix.latitude - 39.09898) < 0.01 && abs(fix.longitude + 106.94117) < 0.01,
            "Location fix (${fix?.let { "%.5f, %.5f".format(java.util.Locale.US, it.latitude, it.longitude) } ?: "none in 30 s; access ${nav.access}"})")
        waited = 0
        while (nav.groundState != GroundState.OK && nav.groundState != GroundState.FAILED && waited < 40) { delay(500); waited++ }
        when (val e = nav.elevation) {
            is ElevationReading.Value -> check(abs(e.metres - 2925) < 150, "Elevation ${e.metres.toInt()} m (${e.source})")
            is ElevationReading.Pending -> check(false, "Elevation (${nav.groundState})")
        }
        delay(4500)
        check(nav.compass != CompassStatus.STARTING, "Compass state (${nav.compass}, heading ${nav.heading?.let { Math.round(it) }})")
        if (nav.declination != null) check(abs(nav.declination!! - 7.6) < 2, "Declination at Maroon Bells (${"%.1f".format(nav.declination)}°)")
        waited = 0
        while (!nav.placeKnown && waited < 30) { delay(500); waited++ }
        check(nav.placeKnown && nav.title.isNotBlank(), "Header names the place (${nav.title})")
        check(nav.sunText != null, "Sunrise and sunset for the fix (${nav.sunText})")

        // The layout planner's golden table (C3.3): devices × layouts × states (sample, live, no compass, locked,
        // marked) × text sizes 1.0 to 2.0, portrait and landscape.
        val broken = LayoutPlan.tableFailures()
        check(broken.isEmpty(), "Layout planner golden table (${if (broken.isEmpty()) "all cases" else broken.take(3).joinToString("; ")})")
        // The plan for the screen as drawn now.
        val plan = LayoutPlan.last
        val h = LayoutPlan.lastHeight
        val s = LayoutPlan.lastSafeHeight
        if (plan == null || h <= 0f) {
            check(false, "Layout plan for this screen (none drawn)")
        } else {
            val f = { v: Float -> "%.0f".format(java.util.Locale.US, v) }
            val what = "layout ${plan.layout.id}: ${plan.resultLine} (floor ${f(plan.floor)}), tiles ${f(plan.tile)}, " +
                "over the dial ${f(plan.topExtra)}, bottom ${f(plan.bottomSpare)} dp, H ${f(h)} dp" +
                (if (plan.centred) ", centred" else "") + (if (plan.twoPane) ", two panes" else "") + (if (plan.list) ", one scrolling list" else "")
            val ok = plan.list || plan.twoPane ||
                ((plan.bottomSpare <= LayoutPlan.BOTTOM_SPARE_MAX + 0.5f || plan.centred) && plan.used <= s + 0.5f && plan.dial + 0.5f >= plan.floor)
            check(ok, "Layout plan for this screen ($what)")
            // The owner's rule on this screen: in one portrait column below accessibility sizes, the dial is at least
            // min(0.40 H, C − 16).
            val w0 = LayoutPlan.lastWidth
            val accessibility = context.resources.configuration.fontScale >= 1.5f
            if (w0 < h && !plan.twoPane && !accessibility) {
                val owner = LayoutPlan.ownerFloor(LayoutPlan.columnWidth(w0, h, false), h)
                check(plan.dial + 0.5f >= owner,
                    "Owner's rule: dial ≥ 40% of H on this screen (dial ${f(plan.dial)} = ${"%.1f".format(java.util.Locale.US, 100 * plan.dial / h)}% of H ${f(h)}, floor ${f(owner)})")
            }
            // The frozen gaps (C3.2 #1): every gap is its token × k, and the header sits 8 under the status bar.
            val k = plan.k
            val tokens = abs(plan.headerGap - plan.topExtra - 12f * k) < 0.01f && abs(plan.dialGap - 12f * k) < 0.01f &&
                abs(plan.statusGap - 6f * k) < 0.01f && abs(plan.lockGap - 8f * k) < 0.01f && abs(plan.spotGap - 8f * k) < 0.01f &&
                abs(plan.gridGap - 8f * k) < 0.01f && abs(plan.rowGap - 8f * k) < 0.01f && abs(plan.mapGap - 12f * k) < 0.01f
            val gapsOk = tokens && LayoutPlan.TOP == 8f && (plan.topExtra <= LayoutPlan.SLACK_MAX + 0.5f || plan.centred)
            check(gapsOk, "Gaps are tokens × k, header at safe top + 8 (12 / 12 / 6 / 8 / 8 / 8 / 8 / 12 × ${"%.2f".format(java.util.Locale.US, k)})")
            // The four layouts on this screen (C3.2 #2): each step changes the grid, and the map moves card → tile → header.
            val w = LayoutPlan.lastWidth
            val here = Layout.entries.map {
                LayoutPlan.plan(w, h, s, it, locked = plan.locked, hasSpot = plan.hasSpot, isLandscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE,
                    noHeading = plan.noHeading)
            }
            // A layout that gave up its grid or card for the owner's floor may share its neighbour's grid.
            val alike = here.zipWithNext().filter { (a, b) ->
                !a.list && !b.list && a.grid == b.grid && a.rung == LayoutPlan.Rung.OWN && b.rung == LayoutPlan.Rung.OWN
            }
            check(alike.isEmpty(), "Four distinct layouts on this screen (" + here.joinToString("; ") { "${it.layout.id}: ${it.resultLine}" } + ")")
        }
        // The owner's rule across the table: every portrait single-column plan at text sizes 1.0 to 1.3, in every
        // state, keeps the dial at min(0.40 H, C − 16) or more (the golden table fails on it too; this line reports
        // the smallest share).
        var leastShare = Float.MAX_VALUE; var leastName = ""
        val underOwner = mutableListOf<String>()
        for (d in LayoutPlan.devices.filter { it.w < it.h }) for (l in Layout.entries) for (st in LayoutPlan.State.entries) for (k in listOf(1f, 1.15f, 1.3f)) {
            val p = LayoutPlan.planFor(d, l, k, st)
            val owner = LayoutPlan.ownerFloor(LayoutPlan.columnWidth(d.w, d.h, false), d.h)
            if (p.dial + 0.5f < owner) underOwner += "${d.name} ${l.id} ${st.id} k$k: ${p.dial} < $owner"
            if (p.dial / d.h < leastShare) { leastShare = p.dial / d.h; leastName = "${d.name} ${l.id} ${st.id} k$k" }
        }
        check(underOwner.isEmpty(), "Owner's rule: dial ≥ min(0.40 H, C − 16) in every portrait plan (" +
            (underOwner.firstOrNull() ?: "least ${"%.1f".format(java.util.Locale.US, 100 * leastShare)}% of H, $leastName") + ")")
        // Every tile row's widths and 8 dp gaps add up to its column (C2.2 #1), on every device, layout, state and text size.
        val ks = listOf(1f, 1.3f, 2f)
        val offColumn = LayoutPlan.devices.flatMap { d ->
            Layout.entries.flatMap { l ->
                LayoutPlan.State.entries.flatMap { st ->
                    ks.flatMap { k ->
                        val p = LayoutPlan.planFor(d, l, k, st)
                        p.rows.mapNotNull { r ->
                            val sum = r.widths.sum() + LayoutPlan.ROW_GAP * (r.widths.size - 1)
                            if (abs(sum - p.column) > 0.01f) "${d.name} ${l.id} k$k ${st.id} ${r.tiles}: $sum in ${p.column}" else null
                        }
                    }
                }
            }
        }
        val compact = LayoutPlan.compactWidths(370f).joinToString(" | ") { "%.0f".format(java.util.Locale.US, it) }
        check(offColumn.isEmpty(), "Tile rows add up to the column (${offColumn.firstOrNull() ?: "all; compact row at C = 370: $compact"})")
        // No "…" anywhere: the header time and the Sun tile, at 1.0, 1.3 and 2.0, measured with Inter as the screen draws it.
        val regular = ResourcesCompat.getFont(context, R.font.inter_regular)
        val medium = ResourcesCompat.getFont(context, R.font.inter_medium)
        val semibold = ResourcesCompat.getFont(context, R.font.inter_semibold)
        fun width(text: String, size: Float, face: Typeface?): Float =
            Paint().apply { typeface = face; textSize = size; letterSpacing = -0.01f; fontFeatureSettings = "'tnum'" }.measureText(text)
        val dates = listOf(Triple(nav.dateText(), nav.dateText(short = true), nav.clock(nav.now)), Triple("Wed, Sep 30", "Sep 30", "12:59 PM"))
        val times = listOf(nav.clock(nav.now), "12:59 PM")
        val cutText = mutableListOf<String>()
        var wrapped = 0
        for (d in LayoutPlan.devices) for (l in Layout.entries) for (k in ks) {
            val p = LayoutPlan.planFor(d, l, k, LayoutPlan.State.SAMPLE)
            val name = "${d.name} ${l.id} k$k"
            // Header line 2: the bar's width less its 14 inset, the sky symbol and gaps, ⋯, the map button and
            // the Sample pill (13 semibold, 8 each side, 6 before it), which trails line 2 except in the list.
            val bar = if (p.twoPane || p.list) d.w - 2 * p.margin else p.column
            val pill = if (p.list) 0f else 6f + width("Sample", 13f * k, semibold) + 16f
            val room = bar - 14f - 8f - 20f - 4f - 48f - (if (p.mapButton) 48f else 0f) - pill
            for ((long, short, time) in dates) {
                val lines = TextFit.headerLines(long, short, time) { width(it, 13f * k, regular) <= room }
                if (lines.size > 1) wrapped++
                if (lines.any { '…' in it || width(it, 13f * k, regular) > room }) cutText += "$name header $lines in ${room.toInt()}"
            }
            // The Sun tile: "↑ 6:36 AM" at 0.85 or more, else "↑ 6:36" over "AM".
            val row = p.rows.firstOrNull { TileKind.SUN in it.tiles } ?: continue
            val cell = row.widths[row.tiles.indexOf(TileKind.SUN)]
            val inner = if (p.grid == GridMode.ROWS) (cell - 36f) * 0.6f else cell - 24f
            val small = p.grid == GridMode.COMPACT
            val size = (if (small) 15f else 17f) * k * 0.85f
            val face = if (small) semibold else medium
            for (t in times) {
                if (width("↑ $t", size, face) <= inner) continue
                val (main, suffix) = TextFit.splitClock(t)
                if (suffix != null) wrapped++
                if ('…' in t || suffix == null || width("↑ $main", size, face) > inner) cutText += "$name Sun \"↑ $t\" in ${inner.toInt()}"
            }
        }
        check(cutText.isEmpty(), "No \u2026 in the header time or the Sun tile at 1.0, 1.3 and 2.0 (" +
            (cutText.firstOrNull() ?: "all devices and layouts; $wrapped wrap at a space instead") + ")")
        // The no-heading dash, rendered (C3.2 #3): "228" and the bar drawn as the screen draws them (Inter at the
        // readout's size, the bar centred CAP_HEIGHT / 2 above the baseline), then the rows of ink found in the
        // pixels. The bar's centre must be within 4 dp of the digits' centre-line, and it must not sit on the
        // baseline (the "_ °" of cycles 1–3).
        val dashCases = listOf(56f, 64f, 70f, 80f * 1.3f)
        val dashOff = dashCases.mapNotNull { size ->
            val (centre, wide, high) = LayoutPlan.dash(size)
            val bmp = android.graphics.Bitmap.createBitmap(400, 200, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            val baseline = 150f
            val paint = Paint().apply { typeface = regular; textSize = size; isAntiAlias = true; color = android.graphics.Color.WHITE }
            canvas.drawText("228", 10f, baseline, paint)
            canvas.drawRoundRect(250f, baseline - centre - high / 2, 250f + wide, baseline - centre + high / 2, high / 2, high / 2, paint)
            fun inkRows(x0: Int, x1: Int): Pair<Int, Int>? {
                var top = -1; var bottom = -1
                for (y in 0 until bmp.height) for (x in x0 until x1) {
                    if (android.graphics.Color.alpha(bmp.getPixel(x, y)) > 128) { if (top < 0) top = y; bottom = y; break }
                }
                return if (top < 0) null else top to bottom
            }
            val digits = inkRows(0, 240); val bar = inkRows(240, 400)
            bmp.recycle()
            if (digits == null || bar == null) "size $size: nothing drawn"
            else {
                val dc = (digits.first + digits.second) / 2f; val bc = (bar.first + bar.second) / 2f
                if (abs(dc - bc) > 4f || bar.second >= baseline - 2f) "size $size: bar centre $bc vs digits $dc" else null
            }
        }
        check(dashOff.isEmpty(), "No-heading dash on the digits' centre-line, rendered (${dashOff.firstOrNull() ?: "56, 64, 70, 104 sp, within 4"})")
        // Both Position lines at one size (C3.4 #12): the shared scale is the longer line's.
        val narrow = 120f
        val pScale = { line: String ->
            var f = 1f
            while (f > 0.85f && width(line, 17f * f, medium) > narrow) f -= 0.05f
            f
        }
        val shared = TextFit.sharedScale(listOf("39.09898° N", "106.94117° W"), pScale)
        check(shared == minOf(pScale("39.09898° N"), pScale("106.94117° W")), "Both Position lines at one size (scale ${"%.2f".format(java.util.Locale.US, shared)})")
        // The lock row (C3.4 #7): "Locked 240°" and "turn 12° right" never split inside a value, and where the two
        // don't fit side by side (12 between, in the row less 14 + 48 + 4) the planner put the cue on a line of its
        // own, where each part fits whole: measured with Inter for every single-column plan up to text size 1.3.
        val lockCut = mutableListOf<String>()
        for (label in listOf("Locked 240° · turn 12° right", "Locked 360° · turn 180° right", "Locked 5° · on bearing")) {
            val (lead, cue) = TextFit.lockParts(label)
            if (cue == null || ' ' in lead || ' ' in cue) lockCut += "parts \"$lead\" / \"$cue\" can split"
        }
        val (lead, cue) = TextFit.lockParts("Locked 360° · turn 180° right")
        for (d in LayoutPlan.devices) for (l in Layout.entries) for (k in listOf(1f, 1.3f)) {
            val p = LayoutPlan.planFor(d, l, k, LayoutPlan.State.SAMPLE)
            // The merged lock-and-spot row (the owner's floor's last give-up) has its own short form.
            if (p.list || p.mergedRows || cue == null) continue
            val room = (if (p.twoPane) p.trailingWidth else p.column) - 14f - 48f - 4f
            val side = width(lead, 17f * k, regular) + 12f + width(cue, 17f * k, semibold) <= room
            if (!side && !p.lockTwoLines) lockCut += "${d.name} ${l.id} k$k: no room side by side in ${room.toInt()}, and not on two lines"
            if (p.lockTwoLines && (width(lead, 17f * k, regular) > room || width(cue, 15f * k, semibold) > room)) lockCut += "${d.name} ${l.id} k$k: a part is wider than ${room.toInt()}"
        }
        check(lockCut.isEmpty(), "Lock row: label and cue never split (${lockCut.firstOrNull() ?: "all plans"})")
        // The map's labels (C3.4 #8): one colour, upright regular, never italic or the style's cyan.
        val font = MapDark.labelFont
        check(MapDark.labelColor == "#C9D3D6" && font.isNotEmpty() && font.none { "Italic" in it || "Bold" in it },
            "Map labels ${MapDark.labelColor} in $font")
        // Coordinates are never cut short with "…" (the tiles shrink them to 0.85 and then wrap).
        val points = listOf(39.09898 to -106.94117, -33.86882 to 151.20929, 0.0 to -179.99999, -89.5 to 179.5)
        val cut = Geo.Format.entries.flatMap { fmt ->
            points.map { (lat, lon) ->
                when (val v = Geo.format(fmt, lat, lon)) { is Geo.Formatted.Pair -> v.lat + v.lon; is Geo.Formatted.Single -> v.text }
            }
        }.filter { it.contains('…') }
        check(cut.isEmpty(), "Coordinates never contain \u2026 (${if (cut.isEmpty()) "all formats" else cut.first()})")
        // Night mode's secondary text through the red multiply, on black (§4.3).
        val contrast = NightContrast.secondary
        check(contrast >= 4.5, "Night secondary text contrast ${"%.2f".format(java.util.Locale.US, contrast)}:1 (4.5 or better)")

        val head = if (failed == 0) "ALL PASSED (${lines.size} checks)" else "FAILED $failed of ${lines.size} checks"
        File(context.filesDir, "report.txt").writeText((listOf(head) + lines).joinToString("\n") + "\n")
    }
}
