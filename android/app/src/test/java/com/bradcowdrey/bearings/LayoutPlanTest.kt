package com.bradcowdrey.bearings

import com.bradcowdrey.bearings.ui.GridMode
import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.ui.LayoutPlan
import com.bradcowdrey.bearings.ui.MapMode
import com.bradcowdrey.bearings.ui.TextFit
import com.bradcowdrey.bearings.ui.TileKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * The layout planner's golden table (docs/REFINE.md C3.3, C3.4's tests; docs/LAYOUTS.md §8): the frozen gaps,
 * the header at safe top + 8, at most 24 empty at the bottom (unless nothing can take it and the stack is
 * centred), nothing cut, every dial at its floor or more (in one portrait column at text sizes up to 1.3, the owner's
 * rule: min(0.40 H, C − 16)), map cards at least 140, rows that add up to the column,
 * four distinct layouts, and text that never ends in "…". The same table runs in the emulator self-test
 * (SelfTest.kt) and, on Apple, in Tests/BearingsTests/LayoutPlanTests.swift.
 */
class LayoutPlanTest {
    private val ks = listOf(1f, 1.15f, 1.3f, 1.5f, 2f)

    private fun everyPlan() = LayoutPlan.devices.flatMap { d ->
        Layout.entries.flatMap { l ->
            LayoutPlan.State.entries.flatMap { st -> ks.map { k -> "${d.name} ${l.id} ${st.id} k$k" to LayoutPlan.planFor(d, l, k, st) } }
        }
    }

    @Test fun goldenTable() {
        assertEquals(emptyList<String>(), LayoutPlan.tableFailures())
    }

    /** C2.2 #1: every row's widths and its 8 dp gaps add up to the column, in every cell of the table. */
    @Test fun rowsAddUpToTheColumn() {
        val off = everyPlan().flatMap { (name, p) ->
            p.rows.mapNotNull { r ->
                val sum = r.widths.sum() + LayoutPlan.ROW_GAP * (r.widths.size - 1)
                if (abs(sum - p.column) > 0.01f) "$name ${r.tiles}: $sum in ${p.column}" else null
            }
        }
        assertEquals(emptyList<String>(), off)
    }

    /** C3.2 #1: every gap is its token × k (only header → dial carries step 4's share), the header at safe top + 8. */
    @Test fun frozenGaps() {
        assertEquals(8f, LayoutPlan.TOP, 0f)
        val off = everyPlan().mapNotNull { (name, p) ->
            val k = p.k
            val ok = abs(p.headerGap - p.topExtra - 12f * k) < 0.01f && abs(p.dialGap - 12f * k) < 0.01f &&
                abs(p.statusGap - 6f * k) < 0.01f && abs(p.lockGap - 8f * k) < 0.01f && abs(p.spotGap - 8f * k) < 0.01f &&
                abs(p.gridGap - 8f * k) < 0.01f && abs(p.rowGap - 8f * k) < 0.01f && abs(p.mapGap - 12f * k) < 0.01f
            if (ok) null else name
        }
        assertEquals(emptyList<String>(), off)
    }

    /**
     * The owner's rule: the compass takes up at least 40% of the screen. In one portrait column, at text sizes 1.0,
     * 1.15 and 1.3, in every state, no layout's dial is under min(0.40 H, C − 16), whether the screen is the fixed
     * panel or the list it falls back to. Accessibility sizes and two panes are exempt.
     */
    @Test fun dialIsAtLeastFortyPercentOfTheScreen() {
        val under = LayoutPlan.devices.filter { it.w < it.h }.flatMap { d ->
            val c = LayoutPlan.columnWidth(d.w, d.h, false)
            val floor = minOf(0.40f * d.h, c - 16f)
            Layout.entries.flatMap { l ->
                LayoutPlan.State.entries.flatMap { st ->
                    listOf(1f, 1.15f, 1.3f).mapNotNull { k ->
                        val p = LayoutPlan.planFor(d, l, k, st)
                        if (p.dial + 0.5f < floor) "${d.name} ${l.id} ${st.id} k$k: dial ${p.dial} < $floor" else null
                    }
                }
            }
        }
        assertEquals(emptyList<String>(), under)
    }

    /**
     * Under pressure the layouts give things up in order rather than shrink the dial: Small's card becomes a map
     * tile, then the header's button; Medium's 3 columns and Large's 2 × 2 become the compact row; then the lock and
     * spot rows merge into one 44 row; only then the list (whose dial keeps the floor too).
     */
    @Test fun givesThingsUpBeforeTheDial() {
        fun plan(name: String, l: Layout, st: LayoutPlan.State = LayoutPlan.State.SAMPLE) =
            LayoutPlan.planFor(LayoutPlan.devices.first { it.name == name }, l, 1f, st)
        // Pixel 7, sample: Small's card is a map tile; Medium keeps its 3 columns at the floor (C − 16 = 364).
        plan("Pixel 7", Layout.SMALL).let { assertTrue(it.resultLine, it.mapStrip && it.rung == LayoutPlan.Rung.GIVEN_UP && abs(it.dial - 364f) < 0.5f) }
        plan("Pixel 7", Layout.MEDIUM).let { assertTrue(it.resultLine, it.grid == GridMode.FULL && it.rung == LayoutPlan.Rung.OWN && abs(it.dial - 364f) < 0.5f) }
        // iPhone 16, sample (H 852): Medium and Large give up their grids, the rows stay apart.
        for (l in listOf(Layout.MEDIUM, Layout.LARGE)) plan("iPhone 16", l).let {
            assertTrue("${l.id}: ${it.resultLine}", it.grid == GridMode.COMPACT && it.rung == LayoutPlan.Rung.GIVEN_UP && it.dial >= 340.8f - 0.5f)
        }
        // iPhone SE, sample: Large merges the lock and spot rows into one 44 row.
        plan("iPhone SE", Layout.LARGE).let { assertTrue(it.resultLine, it.mergedRows && abs(it.mergedHeight - 44f) < 0.01f && it.dial >= 0.40f * 667f - 0.5f) }
        // 360 × 640, sample: Extra Large's bigger readout leaves no room even merged: the list, its dial still 0.40 H.
        plan("Small Android", Layout.EXTRA_LARGE).let { assertTrue(it.resultLine, it.list && abs(it.dial - 256f) < 0.5f) }
        // Live (no rows to merge) on the same screen: no list.
        for (l in Layout.entries) assertTrue(l.id, !plan("Small Android", l, LayoutPlan.State.LIVE).list)
    }

    /**
     * Small ≤ Medium < Large ≤ Extra Large, on every portrait screen in every state at text sizes 1.0, 1.15 and 1.3.
     * The one tie: where Extra Large is held at the floor (on its row, or as the list it fell back to), Large may not
     * pass it, so Medium, Large and Extra Large share the floor (360 × 640 with the sample).
     */
    @Test fun dialsStepUp() {
        for (d in LayoutPlan.devices.filter { it.w < it.h }) for (st in LayoutPlan.State.entries) for (k in listOf(1f, 1.15f, 1.3f)) {
            val (s, m, l, xl) = Layout.entries.map { LayoutPlan.planFor(d, it, k, st) }
            val name = "${d.name} ${st.id} k$k: ${s.dial} ${m.dial} ${l.dial} ${xl.dial}"
            val xlHeld = xl.dial <= xl.floor + 0.5f
            if (!s.list && !m.list) assertTrue(name, s.dial <= m.dial + 0.5f)
            if (!m.list && !l.list && !xlHeld) assertTrue(name, l.dial > m.dial + 0.5f)
            if (!l.list) assertTrue(name, xl.dial >= l.dial - 0.5f)
        }
        // 360 × 640, sample: Extra Large falls back to the list at the floor, so Large stays at the floor too.
        val small = LayoutPlan.devices.first { it.name == "Small Android" }
        val xl = LayoutPlan.planFor(small, Layout.EXTRA_LARGE)
        val large = LayoutPlan.planFor(small, Layout.LARGE)
        assertTrue(xl.resultLine, xl.list)
        assertTrue(large.resultLine, large.dial <= xl.dial + 0.5f)
    }

    /** C3.2 #2: Large is its own layout: 2 × 2 with no Map tile and the map in the header, its dial 16 or more over Medium's. */
    @Test fun largeIsNotMedium() {
        for (name in listOf("iPhone 17 Pro Max", "Pixel 7", "Android 412x914")) {
            val d = LayoutPlan.devices.first { it.name == name }
            for (st in LayoutPlan.State.entries) {
                val m = LayoutPlan.planFor(d, Layout.MEDIUM, 1f, st)
                val l = LayoutPlan.planFor(d, Layout.LARGE, 1f, st)
                assertEquals("$name ${st.id}", GridMode.FULL, m.grid)
                assertEquals("$name ${st.id}", GridMode.QUAD, l.grid)
                assertEquals("$name ${st.id}", MapMode.BUTTON, l.map)
                assertTrue("$name ${st.id}: Large draws a Map tile", l.rows.none { TileKind.MAP in it.tiles })
                assertEquals("$name ${st.id}: Large's rows", listOf(2, 2), l.rows.map { it.tiles.size })
                assertTrue("$name ${st.id}: dial ${l.dial} vs ${m.dial}", l.dial >= m.dial + LayoutPlan.LARGE_STEP - 0.5f)
            }
        }
    }

    /** C3.2 #3: the no-heading dash is a bar 0.5 em × 0.08 em centred on the cap-height midline, well off the baseline. */
    @Test fun dashOnTheCapHeightMidline() {
        for (size in listOf(56f, 70f, 64f, 80f)) {
            val (centre, wide, high) = LayoutPlan.dash(size)
            assertEquals(LayoutPlan.CAP_HEIGHT * size / 2f, centre, 0.01f)
            assertEquals(0.5f * size, wide, 0.01f)
            assertEquals(0.08f * size, high, 0.01f)
            // The bar's bottom edge is far above the baseline (the "_ °" sat on it).
            assertTrue("size $size", centre - high / 2f > 0.25f * size)
        }
    }

    /** C2.3 #14: the header's time is never cut and nothing ends in "…", however narrow the bar. */
    @Test fun noEllipsis() {
        val dates = listOf(Triple("Sun, Nov 1", "Nov 1", "9:41 AM"), Triple("Wed, Sep 30", "Sep 30", "12:59 PM"))
        for ((long, short, time) in dates) for (room in 4..40) {
            val lines = TextFit.headerLines(long, short, time) { it.length <= room }
            assertTrue(lines.none { '…' in it })
            assertTrue("$room: $lines", lines.any { time in it })
        }
        val (lead, cue) = TextFit.lockParts("Locked 240° · turn 12° right")
        assertEquals("Locked 240°", lead)
        assertEquals("turn 12° right", cue)
        assertEquals("6:36" to "AM", TextFit.splitClock("6:36 AM"))
        assertEquals("06:36" to null, TextFit.splitClock("06:36"))
    }

    /** C3.4 #12: both Position lines at one size, the longer line's. */
    @Test fun positionLinesShareOneSize() {
        val scale = mapOf("39.09898° N" to 0.95f, "106.94117° W" to 0.9f)
        assertEquals(0.9f, TextFit.sharedScale(scale.keys.toList()) { scale.getValue(it) }, 0f)
    }

    @Test fun layoutIds() {
        // CI passes these ids as the "layout" extra; they are the stored values.
        assertEquals(listOf("small", "medium", "large", "extraLarge"), Layout.entries.map { it.id })
        assertEquals(Layout.MEDIUM, Layout.of(null))
        assertEquals(Layout.MEDIUM, Layout.of("bogus"))
        assertEquals(Layout.EXTRA_LARGE, Layout.of("extraLarge"))
        assertEquals(listOf("Compass + big map", "Balanced · map tile", "Bigger compass · map in header", "Biggest compass · one row"),
            Layout.entries.map { it.subtitle })
    }
}
