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
import com.bradcowdrey.bearings.widget.WidgetDial
import com.bradcowdrey.bearings.widget.WidgetLayout
import com.bradcowdrey.bearings.widget.widgetDialSize
import com.bradcowdrey.bearings.widget.widgetLayout
import kotlinx.coroutines.delay
import java.io.File
import kotlin.math.abs

/**
 * `--ez selftest true` in the emulator (CI): the core formats, sun, moon and distances, a real location
 * fix (CI places the emulator at Maroon Bells, Colorado), the live ground elevation and place name for it,
 * the compass state, the widget's saved data and its north-up dials (drawn to files/widget-*.png), and the layout planner of Concept A (docs/REFINE.md "Concept A
 * (chosen)", A.11): the golden table (devices × layouts × sample, live, no compass, locked, marked × text sizes,
 * portrait and landscape) must keep the slim location bar first (safe top + 8, 40 dp at text size 1) with the dial's
 * top 12 (8 given way) under it, the Targets card under the status line, every gap at its token, at most 24 dp at the bottom, the Targets card's rows, every
 * dial at 40% of H or more in one portrait column (the owner's rule, the list included), and four distinct layouts
 * (band / quad / six / strip with card / tile / button / button on the golden phones), as must the plan for this
 * screen; every tile row's widths, gaps and insets add up to its column; the location card's time and the Sun times
 * never need "…" and never break at text sizes 1.0, 1.3 and 2.0 (measured with the app's own font); "No heading" is
 * rendered and its ink measured (centred, 12 under the dial, cap height 24, 150–200 wide, white 55%, words not a
 * bar); both Position lines share one size; the lock row's label and cue never split or cut; the map labels are one
 * upright colour; coordinates never carry "…"; and night mode's secondary text is 4.5:1 or better. Writes
 * files/report.txt, first line "ALL PASSED" or "FAILED …"; CI then photographs the screen.
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
        widgetChecks(context, snapshot, ::check)
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

        // The layout planner's golden table (A.11): devices × layouts × states (sample, live, no compass, locked,
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
            val what = "layout ${plan.layout.id}: ${plan.resultLine} (floor ${f(plan.floor)}), tiles ${f(plan.tile)} / ${f(plan.tile2)}, " +
                "location bar at ${f(plan.locationTop)} (${f(plan.location)} tall), dial top ${f(plan.dialTop)}, bottom ${f(plan.bottomSpare)} dp, H ${f(h)} dp" +
                (if (plan.given.isEmpty()) "" else ", gave way: ${plan.given.joinToString { it.name.lowercase() }}") +
                (if (plan.twoPane) ", two panes" else "") + (if (plan.list) ", one scrolling list" else "")
            val ok = plan.list || plan.twoPane ||
                ((plan.bottomSpare <= LayoutPlan.BOTTOM_SPARE_MAX + 0.5f || plan.held) && plan.used <= s + 0.5f && plan.dial + 0.5f >= plan.floor)
            check(ok, "Layout plan for this screen ($what)")
            // The owner's rule on this screen: in one portrait column the dial is at least 40% of H.
            val w0 = LayoutPlan.lastWidth
            if (w0 < h && !plan.twoPane) {
                val owner = LayoutPlan.ownerFloor(w0, h)
                check(plan.dial + 0.5f >= owner,
                    "Owner's rule: dial ≥ 40% of H on this screen (dial ${f(plan.dial)} = ${"%.1f".format(java.util.Locale.US, 100 * plan.dial / h)}% of H ${f(h)}, floor ${f(owner)})")
            }
            // The frozen gaps (A.1, owner's mod): the location bar first, 8 under the status bar, 40 tall at text size 1;
            // the dial 12 (8 given way) under it; then 12, 6 × k, 12 (8) to the Targets card under the status line, 8, 8.
            val k = plan.k
            val barOk = abs(plan.locationTop - LayoutPlan.BAR_TOP) < 0.01f && plan.location + 0.01f >= LayoutPlan.LOCATION &&
                (k > 1f || plan.list || abs(plan.location - LayoutPlan.LOCATION) < 0.01f)
            val gapOk = plan.barGap == LayoutPlan.BAR_GAP || (plan.barGap == LayoutPlan.BAR_GAP_TIGHT && LayoutPlan.Step.GAPS in plan.given)
            val topOk = gapOk && abs(plan.dialTop - (plan.locationTop + plan.location + plan.barGap)) < 0.01f
            val cardOk = plan.twoPane || abs(plan.belowTop - (plan.statusTop + plan.status + plan.cardGap)) < 0.01f
            val tokens = plan.dialGap == 12f && abs(plan.statusGap - 6f * k) < 0.01f && plan.targetsGap == 8f && plan.gridGap == 8f && plan.rowGap == 8f
            check(barOk && topOk && cardOk && tokens, "Location bar first at safe top + ${f(plan.locationTop)}, ${f(plan.location)} tall; dial ${f(plan.barGap)} under it at " +
                "${f(plan.dialTop)}; Targets under the status line; gaps 12 / 6 × k / ${f(plan.cardGap)} / 8 / 8")
            // The four layouts on this screen (A.4): neighbours differ in grid, map surface or dial.
            val w = LayoutPlan.lastWidth
            val here = Layout.entries.map {
                LayoutPlan.plan(w, h, s, it, locked = plan.locked, hasSpot = plan.hasSpot, isLandscapePhone = w > h && s < LayoutPlan.LANDSCAPE_PHONE,
                    noHeading = plan.noHeading)
            }
            val alike = here.zipWithNext().filter { (a, b) -> !a.list && !b.list && a.grid == b.grid && a.map == b.map && abs(a.dial - b.dial) < 8f }
            check(alike.isEmpty(), "Four distinct layouts on this screen (" + here.joinToString("; ") { "${it.layout.id}: ${it.resultLine}" } + ")")
        }
        // The owner's rule across the table: every portrait single-column plan, every layout, state and text size
        // (the list included), keeps the dial at 40% of H or more (the golden table fails on it too; this line reports
        // the smallest share).
        var leastShare = Float.MAX_VALUE; var leastName = ""
        val underOwner = mutableListOf<String>()
        for (d in LayoutPlan.devices.filter { it.w < it.h }) for (l in Layout.entries) for (st in LayoutPlan.State.entries) for (k in listOf(1f, 1.15f, 1.3f, 1.5f, 2f)) {
            val p = LayoutPlan.planFor(d, l, k, st)
            val owner = LayoutPlan.ownerFloor(d.w, d.h)
            if (p.dial + 0.5f < owner) underOwner += "${d.name} ${l.id} ${st.id} k$k: ${p.dial} < $owner"
            if (p.dial / d.h < leastShare) { leastShare = p.dial / d.h; leastName = "${d.name} ${l.id} ${st.id} k$k" }
        }
        check(underOwner.isEmpty(), "Owner's rule: dial ≥ 40% of H in every portrait plan (" +
            (underOwner.firstOrNull() ?: "least ${"%.1f".format(java.util.Locale.US, 100 * leastShare)}% of H, $leastName") + ")")
        // Every tile row's widths, gaps and insets add up to its column, on every device, layout, state and text size.
        val ks = listOf(1f, 1.3f, 2f)
        val offColumn = LayoutPlan.devices.flatMap { d ->
            Layout.entries.flatMap { l ->
                LayoutPlan.State.entries.flatMap { st ->
                    ks.flatMap { k ->
                        val p = LayoutPlan.planFor(d, l, k, st)
                        p.rows.mapNotNull { r ->
                            if (abs(r.total - p.column) > 0.01f) "${d.name} ${l.id} k$k ${st.id} ${r.tiles}: ${r.total} in ${p.column}" else null
                        }
                    }
                }
            }
        }
        val six = LayoutPlan.rows(GridMode.SIX, com.bradcowdrey.bearings.ui.MapMode.BUTTON, 370f)[0].widths.joinToString(" | ") { "%.0f".format(java.util.Locale.US, it) }
        check(offColumn.isEmpty(), "Tile rows add up to the column (${offColumn.firstOrNull() ?: "all; six at C = 370: $six"})")
        // No "…" anywhere: the location card's time and every Sun time, at 1.0, 1.3 and 2.0, measured with Inter as the
        // screen draws it. Times never break: "↑ 6:36 AM" fits at 0.85 or more, or with AM at 11 on the same line.
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
            // Location bar line 2: the bar (full width in two panes) less its 12 inset, 8, the sky glyph's 24 slot, ⋯'s 48
            // slot, 2, the map button's slot and the Sample pill (10 semibold, 6 each side, 6 before it), which trails
            // line 2 except in the list.
            val pill = if (p.list) 0f else 6f + width("Sample", 10f * k, semibold) + 12f
            val room = p.barWidth - 12f - 8f - 24f - 48f - 2f - (if (p.mapButtonSlot) 48f else 0f) - pill
            for ((long, short, time) in dates) {
                val lines = TextFit.headerLines(long, short, time) { width(it, 12f * k, regular) <= room }
                if (lines.size > 1) wrapped++
                if (lines.any { '…' in it || width(it, 12f * k, regular) > room }) cutText += "$name location bar $lines in ${room.toInt()}"
            }
            // Every Sun time as drawn: the band (13 semibold), the strip (15 medium), Large's Sunrise (16), the tablet
            // and list ramps (22), otherwise 15 (semibold in the compact row).
            val row = p.rows.firstOrNull { TileKind.SUN in it.tiles } ?: continue
            val cell = row.widths[row.tiles.indexOf(TileKind.SUN)]
            val (inner, size) = when {
                p.list -> (cell - 32f) * 0.6f to 22f
                p.grid == GridMode.BAND -> cell to 13f
                p.grid == GridMode.STRIP -> cell - 24f to 15f
                p.tablet -> cell - 32f to 22f
                p.grid == GridMode.SIX -> cell - 20f to 16f
                else -> cell - 24f to 15f
            }
            val face = if (p.grid == GridMode.ROW || p.grid == GridMode.BAND) semibold else medium
            for (t in times) {
                val line = TextFit.sunLine("↑", t)
                if (width(line, size * k * 0.85f, face) <= inner) continue
                // A list row whose trailing 60% can't hold the time whole puts the times under the caption at the
                // tile's full width (MainScreen's SunTile, stacked).
                val sunRoom = if (p.list) cell - 32f else inner
                if (p.list && width(line, size * k * 0.85f, face) <= sunRoom) continue
                val (main, suffix) = TextFit.splitClock(t)
                if (suffix != null) wrapped++
                if ('…' in t || suffix == null || width("↑\u00A0$main\u202F", size * k * 0.85f, face) + width(suffix, 11f * k, medium) > sunRoom) {
                    cutText += "$name Sun \"$line\" in ${sunRoom.toInt()}"
                }
            }
        }
        check(cutText.isEmpty(), "No … in the location bar's time or the Sun times at 1.0, 1.3 and 2.0, times whole (" +
            (cutText.firstOrNull() ?: "all devices and layouts; $wrapped shorten or drop AM to 11 instead") + ")")
        // "No heading" (A.2), rendered: the words drawn as the screen draws them (Inter semibold 34 at white 55%, centred
        // in the column, the line box trimmed to the cap height so the ink starts at the readout slot's top, 12 under
        // the dial), then the ink found in the pixels: centred on the column ± 2, its top 12 ± 2 under the dial, a cap
        // height of 24 ± 3, 150 to 200 wide, white at 0.55 ± 0.03, and words, not one horizontal bar.
        val words = run {
            val column = 370; val dialBottom = 40; val size = LayoutPlan.NO_HEADING_SIZE
            val bmp = android.graphics.Bitmap.createBitmap(column, 120, android.graphics.Bitmap.Config.ARGB_8888)
            val canvas = android.graphics.Canvas(bmp)
            val paint = Paint().apply {
                typeface = semibold; textSize = size; isAntiAlias = true; letterSpacing = -0.2f / size; textAlign = Paint.Align.CENTER
                color = android.graphics.Color.argb(Math.round(com.bradcowdrey.bearings.ui.Op.NO_HEADING * 255), 255, 255, 255)
            }
            val slotTop = dialBottom + LayoutPlan.DIAL_GAP
            canvas.drawText(LayoutPlan.NO_HEADING_TEXT, column / 2f, slotTop + LayoutPlan.CAP_HEIGHT * size, paint)
            var top = -1; var bottom = -1; var left = column; var right = -1; var maxAlpha = 0; var rows = 0
            // The cap height from the "N" alone (the first ink columns), the box from everything.
            var nTop = -1; var nBottom = -1
            for (y in 0 until bmp.height) {
                var any = false
                for (x in 0 until column) {
                    val a = android.graphics.Color.alpha(bmp.getPixel(x, y))
                    if (a > 0) maxAlpha = maxOf(maxAlpha, a)
                    if (a > 100) { any = true; if (top < 0) top = y; bottom = y; left = minOf(left, x); right = maxOf(right, x) }
                }
                if (any) rows++
            }
            if (right >= 0) for (y in 0 until bmp.height) for (x in left until minOf(left + 6, column)) {
                if (android.graphics.Color.alpha(bmp.getPixel(x, y)) > 100) { if (nTop < 0) nTop = y; nBottom = y }
            }
            bmp.recycle()
            val centre = (left + right) / 2f; val wide = right - left + 1; val cap = nBottom - nTop + 1
            val alpha = maxAlpha / 255f
            val problems = listOfNotNull(
                "centre ${"%.1f".format(java.util.Locale.US, centre)} of ${column / 2}".takeIf { abs(centre - column / 2f) > 2f },
                "top ${top - dialBottom} under the dial".takeIf { abs(top - dialBottom - 12) > 2 },
                "cap height $cap".takeIf { abs(cap - 24) > 3 },
                "width $wide".takeIf { wide !in 150..200 },
                "white ${"%.2f".format(java.util.Locale.US, alpha)}".takeIf { abs(alpha - 0.55f) > 0.03f },
                "a single bar ($rows rows of ink)".takeIf { rows < 12 },
            )
            val summary = "ink $wide × $cap at ${top - dialBottom} under the dial, white ${"%.2f".format(java.util.Locale.US, alpha)}"
            (if (right < 0) "nothing drawn" else problems.joinToString().ifEmpty { null }) to summary
        }
        check(words.first == null, "\"No heading\" in words, rendered (${words.first ?: words.second})")
        // Both Position lines at one size (C3.4 #12): the shared scale is the longer line's.
        val narrow = 120f
        val pScale = { line: String ->
            var f = 1f
            while (f > 0.85f && width(line, 17f * f, medium) > narrow) f -= 0.05f
            f
        }
        val shared = TextFit.sharedScale(listOf("39.09898° N", "106.94117° W"), pScale)
        check(shared == minOf(pScale("39.09898° N"), pScale("106.94117° W")), "Both Position lines at one size (scale ${"%.2f".format(java.util.Locale.US, shared)})")
        // The Targets card's lock row (A.2): "Locked 240°" and "turn 12° right" never split inside a value; side by
        // side in the row less 16 + 18 + 8 and ✕'s 48 + 4, 12 between, at worst with the lead in its short form "240°"
        // and both at 0.85: measured with Inter for every single-column plan up to text size 1.3.
        val lockCut = mutableListOf<String>()
        for (label in listOf("Locked 240° · turn 12° right", "Locked 360° · turn 180° right", "Locked 5° · on bearing")) {
            val (lead, cue) = TextFit.lockParts(label)
            if (cue == null || ' ' in lead || ' ' in cue) lockCut += "parts \"$lead\" / \"$cue\" can split"
        }
        val (lead, cue) = TextFit.lockParts("Locked 360° · turn 180° right")
        for (d in LayoutPlan.devices) for (l in Layout.entries) for (k in listOf(1f, 1.3f)) {
            val p = LayoutPlan.planFor(d, l, k, LayoutPlan.State.SAMPLE)
            if (p.list || cue == null) continue
            val size = (if (p.tablet || l == Layout.EXTRA_LARGE) 19f else if (l == Layout.SMALL) 16f else 17f) * k
            val room = p.column - 16f - 18f - 8f - 48f - 4f
            val worst = width(TextFit.shortLock(lead), size * 0.85f, regular) + 12f + width(cue, size * 0.85f, semibold)
            if (worst > room) lockCut += "${d.name} ${l.id} k$k: ${worst.toInt()} in ${room.toInt()}"
        }
        check(lockCut.isEmpty(), "Lock row: label and cue never split or cut (${lockCut.firstOrNull() ?: "all plans"})")
        // The map's labels (C3.4 #8): one colour, upright regular, never italic or the style's cyan.
        val font = MapDark.labelFont
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.IO) { MapDark.probeAlphaTextures() }
        check(MapDark.labelColor == "#C9D3D6" && font.isNotEmpty() && font.none { "Italic" in it || "Bold" in it },
            "Map labels ${MapDark.labelColor} in $font; ${MapDark.labelState}")
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

    /**
     * The widget (docs/DESIGN.md, Widgets): the sample's entry (Maroon Bells at 9:41 with the spot near Aspen and
     * 240° locked) carries the true bearings the north-up dial needs; the size breakpoints and dial sizes match the
     * mock (Small 124 dp half dial at 170 × 170, Medium 120 at 364 × 170, Large 212 at 364 × 382); and every dial is
     * drawn (files/widget-*.png, which CI keeps as android-widget-*.png) with its marks where they belong: the spot's
     * pin on the rim at 46°, the sun on the disc, the lock's notch at 240°, and on Small's half dial the sun (144°)
     * and moon below the arc as edge marks past its ends with nothing drawn under the arc between them.
     */
    private fun widgetChecks(context: Context, snapshot: Snapshot, check: (Boolean, String) -> Unit) {
        val spot = 39.1911 to -106.8175
        val entry = WidgetData.entry(context, snapshot, spot, 240.0, Navigator.SAMPLE_TIME)
        val sun = entry.sunAzimuth ?: -1.0; val moon = entry.moonAzimuth ?: -1.0
        check(entry.markPoint == "46° NE" && (entry.markDistance == "9.2 mi" || entry.markDistance == "14.8 km") && entry.lock == 240.0 &&
            sun in 135.0..155.0 && moon in 180.0..300.0,
            "Widget entry: spot ${entry.markDistance} · ${entry.markPoint}, lock ${entry.lock}, sun ${Math.round(sun)}°, moon ${Math.round(moon)}° " +
                "(${entry.moonPercent} ${entry.moonName}), header \"${entry.shortPlace}\" / \"${entry.asOfLong}\"")
        val layouts = listOf(widgetLayout(172f, 172f), widgetLayout(360f, 172f), widgetLayout(360f, 382f), widgetLayout(250f, 299f), widgetLayout(249f, 400f))
        val sizes = listOf(
            widgetDialSize(WidgetLayout.SMALL, 170f, 170f, true, false),
            widgetDialSize(WidgetLayout.MEDIUM, 364f, 170f, true, false),
            widgetDialSize(WidgetLayout.LARGE, 364f, 382f, true, true),
        )
        check(layouts == listOf(WidgetLayout.SMALL, WidgetLayout.MEDIUM, WidgetLayout.LARGE, WidgetLayout.MEDIUM, WidgetLayout.SMALL) &&
            sizes == listOf(124f, 120f, 212f) && WidgetDial.density(212f) == WidgetDial.Density.BIG &&
            WidgetDial.density(124f) == WidgetDial.Density.MID && WidgetDial.density(80f) == WidgetDial.Density.SMALL,
            "Widget layouts by size (${layouts.joinToString { it.name.lowercase() }}) and dials ${sizes.joinToString(" / ") { "%.0f".format(java.util.Locale.US, it) }} dp")

        val scale = 2f
        fun marks(label: Boolean, lock: Boolean, withSpot: Boolean = true) = WidgetDial.Marks(
            sun = entry.sunAzimuth, sunUp = entry.sunUp, moon = entry.moonAzimuth, moonUp = entry.moonUp, moonPhase = entry.moonPhase,
            spot = if (withSpot) entry.markBearing else null, spotLabel = if (label && withSpot) entry.markDistance else null,
            lock = if (lock) entry.lock else null,
        )
        // Colour within 28 per channel (the bitmaps are RGB 565) somewhere in a box [half] dp around (x, y) dp.
        fun has(bitmap: android.graphics.Bitmap, x: Float, y: Float, half: Float, color: Int): Boolean {
            val x0 = ((x - half) * scale).toInt().coerceAtLeast(0); val x1 = ((x + half) * scale).toInt().coerceAtMost(bitmap.width - 1)
            val y0 = ((y - half) * scale).toInt().coerceAtLeast(0); val y1 = ((y + half) * scale).toInt().coerceAtMost(bitmap.height - 1)
            for (py in y0..y1) for (px in x0..x1) {
                val c = bitmap.getPixel(px, py)
                if (abs(android.graphics.Color.red(c) - android.graphics.Color.red(color)) < 28 &&
                    abs(android.graphics.Color.green(c) - android.graphics.Color.green(color)) < 28 &&
                    abs(android.graphics.Color.blue(c) - android.graphics.Color.blue(color)) < 28) return true
            }
            return false
        }
        fun at(cx: Float, cy: Float, deg: Double, r: Float) =
            (cx + (kotlin.math.sin(Math.toRadians(deg)) * r).toFloat()) to (cy - (kotlin.math.cos(Math.toRadians(deg)) * r).toFloat())
        fun save(name: String, dial: WidgetDial.Dial) = runCatching {
            File(context.filesDir, "$name.png").outputStream().use { dial.bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        }
        val problems = mutableListOf<String>()
        val b = entry.markBearing ?: 46.0
        // Large: 212, the full scale; R = 101 (5 for the notch), centre 106.
        val large = WidgetDial.draw(212f, half = false, marks = marks(label = true, lock = true), scale = scale)
        save("widget-large", large)
        at(106f, 106f, b, 91f).let { (x, y) -> if (!has(large.bitmap, x, y, 4f, WidgetDial.PINK)) problems += "large: no pin at ${Math.round(b)}°" }
        at(106f, 106f, sun, 50.5f).let { (x, y) -> if (!has(large.bitmap, x, y, 3f, WidgetDial.AMBER)) problems += "large: no sun at ${Math.round(sun)}°" }
        at(106f, 106f, 240.0, 101f).let { (x, y) -> if (!has(large.bitmap, x, y, 3f, WidgetDial.PINK)) problems += "large: no lock at 240°" }
        at(106f, 106f, 0.0, 101f - 2.5f - 11f - 3f - 9f).let { (x, y) -> if (!has(large.bitmap, x, y, 4f, WidgetDial.PINK)) problems += "large: no pink N" }
        // Large with no spot and no lock (R = 104): no pin.
        val bare = WidgetDial.draw(212f, half = false, marks = marks(label = false, lock = false, withSpot = false), scale = scale)
        save("widget-large-nospot", bare)
        at(106f, 106f, b, 94f).let { (x, y) -> if (has(bare.bitmap, x, y, 3f, WidgetDial.PINK)) problems += "large without a spot still has a pin" }
        // Medium: 120 with the notch (R = 55, centre 60).
        val medium = WidgetDial.draw(120f, half = false, marks = marks(label = false, lock = true), scale = scale)
        save("widget-medium", medium)
        at(60f, 60f, 240.0, 55f).let { (x, y) -> if (!has(medium.bitmap, x, y, 3f, WidgetDial.PINK)) problems += "medium: no lock at 240°" }
        at(60f, 60f, b, 52.5f - 6.1f).let { (x, y) -> if (!has(medium.bitmap, x, y, 3f, WidgetDial.PINK)) problems += "medium: no pin" }
        // Small: the half dial, 124 (R = 60), 20 each side: centre (82, 62).
        val small = WidgetDial.draw(124f, half = true, marks = marks(label = true, lock = false), scale = scale)
        save("widget-small", small)
        at(82f, 62f, b, 51.4f).let { (x, y) -> if (!has(small.bitmap, x, y, 3f, WidgetDial.PINK)) problems += "small: no pin on the arc" }
        val sunSide = if (sun < 180) 82f + 60f + 7f else 82f - 60f - 7f
        if (sun in 90.0..270.0 && !has(small.bitmap, sunSide, 64f, 3.5f, WidgetDial.AMBER)) problems += "small: no sun edge mark"
        if (moon in 90.0..270.0) {
            val moonSide = if (moon < 180) 82f + 60f + 7f else 82f - 60f - 7f
            if (!has(small.bitmap, moonSide, 64f, 5f, WidgetDial.CREAM) && !has(small.bitmap, moonSide, 50f, 5f, WidgetDial.CREAM)) problems += "small: no moon edge mark"
        }
        // Nothing under the arc between its ends (marks never move onto the dial's hidden half).
        var under = 0
        for (py in ((62f + 4f) * scale).toInt() until small.bitmap.height) for (px in ((82f - 50f) * scale).toInt()..((82f + 50f) * scale).toInt()) {
            if ((small.bitmap.getPixel(px, py) and 0xFFFFFF) != 0) under++
        }
        if (under > 0) problems += "small: $under px drawn under the arc"
        check(problems.isEmpty(), "Widget dials drawn north-up (${problems.firstOrNull() ?: "large ${large.bitmap.width} px, medium, small half dial with edge marks"})")
    }
}
