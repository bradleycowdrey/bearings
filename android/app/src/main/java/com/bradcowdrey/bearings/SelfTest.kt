package com.bradcowdrey.bearings

import android.content.Context
import com.bradcowdrey.bearings.ui.LayoutPlan
import com.bradcowdrey.bearings.widget.Snapshot
import com.bradcowdrey.bearings.widget.WidgetData
import kotlinx.coroutines.delay
import java.io.File
import kotlin.math.abs

/**
 * `--ez selftest true` in the emulator (CI): the core formats, sun, moon and distances, a real location
 * fix (CI places the emulator at Maroon Bells, Colorado), the live ground elevation and place name for it,
 * the compass state, the widget's saved data, and the layout planner (docs/LAYOUTS.md): the whole device
 * table, and the plan for this screen, which must give the dial at least 40% of the height in portrait. Writes files/report.txt, first line "ALL PASSED" or
 * "FAILED …"; CI then photographs the screen.
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
        val entry = WidgetData.entry(context, now = 1793548800000L)
        WidgetData.restore(context, before)
        check(back == snapshot && entry.place == "Maroon Bells, Colorado" && entry.sunrise != null && entry.moonLine.startsWith("Last Quarter"),
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

        // The layout planner: every device, layout, text size, marked spot and banner keeps the 40% floor.
        val broken = LayoutPlan.tableFailures()
        check(broken.isEmpty(), "Layout planner table keeps the 40% floor (${if (broken.isEmpty()) "all cases" else broken.take(3).joinToString("; ")})")
        // The plan for the screen as drawn now.
        val plan = LayoutPlan.last
        val h = LayoutPlan.lastHeight
        if (plan == null || h <= 0f) {
            check(false, "Layout plan for this screen (none drawn)")
        } else {
            val share = plan.dial / h * 100
            val what = "layout ${plan.layout.id}: dial ${"%.0f".format(java.util.Locale.US, plan.dial)} dp, " +
                "${"%.1f".format(java.util.Locale.US, share)}% of H ${"%.0f".format(java.util.Locale.US, h)} dp" +
                (if (plan.twoPane) ", two panes" else "") + (if (plan.scrollsWhole) ", scrolls whole" else "")
            check(plan.twoPane || plan.dial + 0.5f >= 0.40f * h, "Layout plan for this screen ($what)")
        }

        val head = if (failed == 0) "ALL PASSED (${lines.size} checks)" else "FAILED $failed of ${lines.size} checks"
        File(context.filesDir, "report.txt").writeText((listOf(head) + lines).joinToString("\n") + "\n")
    }
}
