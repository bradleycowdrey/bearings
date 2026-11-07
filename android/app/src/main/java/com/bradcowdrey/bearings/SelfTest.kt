package com.bradcowdrey.bearings

import android.content.Context
import com.bradcowdrey.bearings.ui.LayoutPlan
import com.bradcowdrey.bearings.ui.NightContrast
import com.bradcowdrey.bearings.widget.Snapshot
import com.bradcowdrey.bearings.widget.WidgetData
import kotlinx.coroutines.delay
import java.io.File
import kotlin.math.abs

/**
 * `--ez selftest true` in the emulator (CI): the core formats, sun, moon and distances, a real location
 * fix (CI places the emulator at Maroon Bells, Colorado), the live ground elevation and place name for it,
 * the compass state, the widget's saved data, and the bottom-up layout planner (docs/REFINE.md §3.3, §4.7):
 * the golden table (devices × layouts × none, locked, marked, both × text sizes) must leave at most 24 dp empty
 * at the bottom, show no block partly and keep every dial at or above its floor, as must the plan for this
 * screen; coordinates never carry "…"; and night mode's secondary text is 4.5:1 or better. Writes
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

        // The layout planner's golden table (§4.7): ≤ 24 dp empty at the bottom, nothing partly shown, no dial under its floor.
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
            val what = "layout ${plan.layout.id}: dial ${f(plan.dial)} dp (floor ${f(plan.floor)}), ${plan.grid.name.lowercase()} grid, " +
                "map ${plan.map.name.lowercase()}${if (plan.map == com.bradcowdrey.bearings.ui.MapMode.CARD) " ${f(plan.mapHeight)}" else ""}, " +
                "bottom ${f(plan.bottomSpare)} dp, H ${f(h)} dp" +
                (if (plan.twoPane) ", two panes" else "") + (if (plan.list) ", one scrolling list" else "")
            val ok = plan.list || plan.twoPane ||
                (plan.bottomSpare <= LayoutPlan.BOTTOM_SPARE_MAX + 0.5f && plan.used <= s + 0.5f && plan.dial + 0.5f >= plan.floor)
            check(ok, "Layout plan for this screen ($what)")
        }
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
