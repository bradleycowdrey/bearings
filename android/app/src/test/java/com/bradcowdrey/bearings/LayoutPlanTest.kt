package com.bradcowdrey.bearings

import com.bradcowdrey.bearings.ui.GridMode
import com.bradcowdrey.bearings.ui.Layout
import com.bradcowdrey.bearings.ui.LayoutPlan
import com.bradcowdrey.bearings.ui.MapMode
import com.bradcowdrey.bearings.ui.Sixth
import com.bradcowdrey.bearings.ui.TextFit
import com.bradcowdrey.bearings.ui.TileKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

/**
 * The layout planner's golden table (docs/REFINE.md "Concept A (chosen)", A.11, and the owner's mod): location bar
 * (40, at safe top + 8) → dial (12 under it) → readout → status line → Targets card → tiles or map; the frozen gaps; at most 24 empty
 * at the bottom; every dial at least 0.40 H in one portrait column (every layout, state and text size, the list
 * included); rows that add up to the column; four distinct layouts; and text that never ends in "…". The same
 * table runs in the emulator self-test (SelfTest.kt) and, on Apple, in Tests/BearingsTests/LayoutPlanTests.swift.
 */
class LayoutPlanTest {
    private val ks = listOf(1f, 1.15f, 1.3f, 1.5f, 2f)

    private fun device(name: String) = LayoutPlan.devices.first { it.name == name }

    private fun everyPlan() = LayoutPlan.devices.flatMap { d ->
        Layout.entries.flatMap { l ->
            LayoutPlan.State.entries.flatMap { st -> ks.map { k -> Triple("${d.name} ${l.id} ${st.id} k$k", d, LayoutPlan.planFor(d, l, k, st)) } }
        }
    }

    @Test fun goldenTable() {
        assertEquals(emptyList<String>(), LayoutPlan.tableFailures())
    }

    /** Every row's widths, gaps and insets add up to the column: band 3 columns + 24 + 2 × 8, six 3u + 16, the strip's dividers, two rows. */
    @Test fun rowsAddUpToTheColumn() {
        val off = everyPlan().flatMap { (name, _, p) ->
            p.rows.mapNotNull { r -> if (abs(r.total - p.column) > 0.01f) "$name ${r.tiles}: ${r.total} in ${p.column}" else null }
        }
        assertEquals(emptyList<String>(), off)
        val band = LayoutPlan.rows(GridMode.BAND, MapMode.CARD, 370f).single()
        assertEquals(370f, band.widths.sum() + 24f + 2 * 8f, 0.01f)
        val six = LayoutPlan.rows(GridMode.SIX, MapMode.BUTTON, 370f)
        assertTrue(six.all { abs(it.widths.sum() + 16f - 370f) < 0.01f })
        assertEquals(listOf(118f, 118f, 118f), six[0].widths)
        assertEquals(listOf(181f, 181f), LayoutPlan.rows(GridMode.QUAD, MapMode.TILE, 370f)[0].widths)
        val strip = LayoutPlan.rows(GridMode.STRIP, MapMode.BUTTON, 370f).single()
        assertEquals(370f, strip.widths.sum() + 2f, 0.01f)
        // 1.2 | 1 | 1, as on Apple (review 2.3.0, 11).
        assertEquals(listOf(138f, 115f, 115f), strip.widths)
        val two = LayoutPlan.rows(GridMode.TWO_ROW, MapMode.BUTTON, 370f)
        assertEquals(listOf(370f), two[0].widths)
        assertEquals(listOf(181f, 181f), two[1].widths)
    }

    /** A.1: the dial's top is the bar's 8 + the bar + 12 (8 given way), and the other gaps are the frozen tokens. */
    @Test fun frozenGaps() {
        val off = everyPlan().mapNotNull { (name, _, p) ->
            val barGap = p.barGap == 12f || (p.barGap == 8f && LayoutPlan.Step.GAPS in p.given)
            val top = barGap && abs(p.dialTop - (8f + p.location + p.barGap)) < 0.01f
            val card = p.cardGap == 12f || (p.cardGap == 8f && LayoutPlan.Step.GAPS in p.given)
            val ok = top && card && p.dialGap == 12f && abs(p.statusGap - 6f * p.k) < 0.01f && p.targetsGap == 8f &&
                p.gridGap == 8f && p.rowGap == 8f
            if (ok) null else "$name: ${p.dialTop} / ${p.cardGap}"
        }
        assertEquals(emptyList<String>(), off)
    }

    /**
     * The owner's rule: the compass takes up at least 40% of the screen. In one portrait column, in every layout,
     * state and text size, the scrolling list included, no dial is under ceil(0.40 H).
     */
    @Test fun dialIsAtLeastFortyPercentOfTheScreen() {
        val under = everyPlan().mapNotNull { (name, d, p) ->
            if (d.w < d.h && !p.twoPane && p.dial + 0.5f < LayoutPlan.ownerFloor(d.w, d.h)) "$name: dial ${p.dial} < ${0.40f * d.h}" else null
        }
        assertEquals(emptyList<String>(), under)
    }

    /**
     * The owner's mod: in every plan (two panes and the list too) the location bar is first, at safe top + 8, 40 tall
     * at text size 1 (8 + 32 × k at larger text, a line more when wrapped), and the dial's top is 12 (8 given way)
     * under it; in one column the Targets card (or the grid) is the status line's bottom + 12 (8 given way).
     */
    @Test fun locationBarFirst() {
        val off = everyPlan().mapNotNull { (name, d, p) ->
            val bar = abs(p.locationTop - 8f) < 0.01f && p.location >= 40f - 0.01f &&
                (p.k > 1f || p.list || abs(p.location - 40f) < 0.01f) && p.dialTop >= p.locationTop + p.location + 8f - 0.01f
            val gap = p.belowTop - (p.statusTop + p.status)
            val below = p.twoPane || p.list || abs(gap - 12f) < 0.01f || (abs(gap - 8f) < 0.01f && LayoutPlan.Step.GAPS in p.given)
            if (bar && below && (d.w > d.h || p.twoPane || p.belowTop > p.dialTop + p.dial)) null
            else "$name: bar at ${p.locationTop} ${p.location} tall, dial at ${p.dialTop}, below at ${p.belowTop}"
        }
        assertEquals(emptyList<String>(), off)
        assertEquals(40f, LayoutPlan.locationHeight(1f), 0.01f)
        assertEquals(8f + 32f * 1.3f, LayoutPlan.locationHeight(1.3f), 0.01f)
    }

    /** The Targets card: 0, 1 or 2 rows by state, 48 (64 Extra Large, 56 tablet; 40 / 48 compact). */
    @Test fun targetsCardRows() {
        val pixel = device("Pixel 7")
        for (st in LayoutPlan.State.entries) {
            val want = (if (st.locked && !st.noHeading) 1 else 0) + (if (st.spot) 1 else 0)
            for (l in Layout.entries) assertEquals("${st.id} ${l.id}", want, LayoutPlan.planFor(pixel, l, 1f, st).targetsRows)
        }
        assertEquals(48f, LayoutPlan.planFor(pixel, Layout.MEDIUM).targetsRowHeight, 0.01f)
        assertEquals(64f, LayoutPlan.planFor(pixel, Layout.EXTRA_LARGE).targetsRowHeight, 0.01f)
        val heights = setOf(48f, 40f, 56f, 64f)
        for ((name, _, p) in everyPlan()) if (p.targetsRows > 0 && p.k == 1f && !p.list) assertTrue("$name: ${p.targetsRowHeight}", p.targetsRowHeight in heights)
        // Compact rows come only with the gaps already given (A.6: step 2 before step 3).
        for ((name, _, p) in everyPlan()) if (LayoutPlan.Step.ROWS in p.given && !p.twoPane) assertTrue(name, LayoutPlan.Step.GAPS in p.given)
    }

    /** Large's sixth tile is Pressure when still and Speed when moving (0.5 m/s or more), never unrelated data. */
    @Test fun largeSixthTile() {
        assertEquals(Sixth.PRESSURE, LayoutPlan.sixth(null))
        assertEquals(Sixth.PRESSURE, LayoutPlan.sixth(0.49))
        assertEquals(Sixth.SPEED, LayoutPlan.sixth(0.5))
        val d = device("Pixel 7")
        val still = LayoutPlan.planFor(d, Layout.LARGE)
        val moving = LayoutPlan.planFor(d, Layout.LARGE, moving = true)
        assertEquals(GridMode.SIX, still.grid)
        assertEquals(listOf(TileKind.SUN, TileKind.MOON, TileKind.PRESSURE), still.rows[1].tiles)
        assertEquals(listOf(TileKind.SUN, TileKind.MOON, TileKind.SPEED), moving.rows[1].tiles)
        assertEquals(listOf(TileKind.LATITUDE, TileKind.LONGITUDE, TileKind.ELEVATION), still.rows[0].tiles)
        // Other formats: one Position tile across two columns.
        val dms = LayoutPlan.rows(GridMode.SIX, MapMode.BUTTON, 370f, Sixth.PRESSURE, decimal = false)
        assertEquals(listOf(TileKind.POSITION, TileKind.ELEVATION), dms[0].tiles)
        assertEquals(2 * 118f + 8f, dms[0].widths[0], 0.01f)
    }

    /** A.7: at k 1.3 and 2.0 no three-column compact row, rows of equal height, "6:36 AM" never split, the last row above the safe bottom. */
    @Test fun largeTextTwoRows() {
        for (d in LayoutPlan.devices) for (l in Layout.entries) for (st in LayoutPlan.State.entries) for (k in listOf(1.3f, 2f)) {
            val p = LayoutPlan.planFor(d, l, k, st)
            val name = "${d.name} ${l.id} ${st.id} k$k: ${p.resultLine}"
            if (p.list) { assertEquals(name, GridMode.ROWS, p.grid); continue }
            assertTrue(name, p.grid !in setOf(GridMode.BAND, GridMode.SIX, GridMode.STRIP, GridMode.ROW))
            if (p.grid != GridMode.QUAD || p.map != MapMode.CARD) assertEquals(name, p.tile, p.tile2, 0.01f)
            if (!p.twoPane) {
                val end = if (p.map == MapMode.CARD) p.mapTop + p.mapHeight else p.gridTop + p.gridHeight
                assertTrue(name, end <= d.s - p.endGap + 0.5f)
                if (d.android) assertEquals(name, 16f, p.endGap, 0.01f)
            }
        }
        // Times use no-break spaces: "6:36 AM" never splits.
        val t = TextFit.time("6:36 AM")
        assertTrue(t, ' ' !in t)
        assertEquals("6:36\u202FAM", t)
        assertEquals("↑\u00A06:36\u202FAM", TextFit.sunLine("↑", "6:36 AM"))
    }

    /**
     * Review 2.3.0, 2: no layout overflows. The heights the single column stacks add up to the safe height exactly,
     * in every layout, state and text size on every portrait screen; and rounded to whole pixels at the usual screen
     * densities, the column is never more than its empty end gap can absorb (8 dp) taller than the screen, so nothing
     * scrolls and no fade is drawn over the last tiles.
     */
    @Test fun noLayoutOverflows() {
        val off = mutableListOf<String>()
        for ((name, d, p) in everyPlan()) {
            if (p.list || p.twoPane) continue
            val sum = LayoutPlan.columnPieces(p).sum()
            if (abs(sum - d.s) > 0.5f) off += "$name: the column is $sum dp for a safe height of ${d.s}"
            for (density in listOf(1f, 1.5f, 2f, 2.625f, 2.75f, 3f, 3.5f, 4f)) {
                val over = LayoutPlan.pixelOverflow(p, d.s, density)
                val slack = Math.round(minOf(LayoutPlan.OVERFLOW_SLACK, p.endGap + p.bottomSpare) * density)
                // Android's column ends 8 above the navigation bar; that gap takes the rounding.
                if (d.android && over > slack) off += "$name at $density px per dp: $over px over, $slack to spare"
                if (over > Math.round(LayoutPlan.OVERFLOW_SLACK * density)) off += "$name at $density px per dp: $over px over"
            }
        }
        assertEquals(emptyList<String>(), off)
        // The emulator CI photographs: 412 × 914 at 2.625, sample, where Large and Small looked cut off.
        val ci = device("Android 412x914")
        for (l in Layout.entries) {
            val p = LayoutPlan.planFor(ci, l)
            assertTrue("${l.id}: ${LayoutPlan.pixelOverflow(p, ci.s, 2.625f)} px", LayoutPlan.pixelOverflow(p, ci.s, 2.625f) <= Math.round(8f * 2.625f))
        }
    }

    /** Review 2.3.0, 11: the strip's values are one size, the largest from the top down to 15 that fits. */
    @Test fun stripValueSize() {
        assertEquals(20f, LayoutPlan.stripValueSize(20f) { true }, 0f)
        assertEquals(15f, LayoutPlan.stripValueSize(20f) { false }, 0f)
        assertEquals(17f, LayoutPlan.stripValueSize(20f) { it <= 17f }, 0f)
        assertEquals(26f, LayoutPlan.stripValueSize(LayoutPlan.STRIP_VALUE_MAX_TABLET) { true }, 0f)
        // Never under the old 15, so Extra Large's values are never smaller than Medium's.
        assertTrue(LayoutPlan.STRIP_VALUE_MIN >= 15f && LayoutPlan.STRIP_VALUE_MAX > 17f)
        // The strip holds its caption, the gap and two lines of the largest values between its 14 paddings.
        val need = 2 * LayoutPlan.STRIP_PAD + 13f + LayoutPlan.STRIP_CAPTION_GAP + 2 * (LayoutPlan.STRIP_VALUE_MAX + 2f)
        assertTrue("$need in ${LayoutPlan.STRIP}", need <= LayoutPlan.STRIP)
    }

    /** No portrait golden plan leaves an empty band wider than 24. */
    @Test fun noEmptyBandOver24() {
        for (name in LayoutPlan.goldenDevices) for (l in Layout.entries) for (st in LayoutPlan.State.entries) {
            val p = LayoutPlan.planFor(device(name), l, 1f, st)
            assertTrue("$name ${l.id} ${st.id}: ${p.bottomSpare}", p.bottomSpare <= 24.5f)
        }
    }

    /**
     * A.6: the layouts give way in order rather than shrink the dial: tile growth, the spare gaps, the Targets
     * rows, Large's grid density, then the map goes to the location card's button with one compact row; only then
     * the list (whose dial keeps 0.40 H too).
     */
    @Test fun givesThingsUpBeforeTheDial() {
        fun plan(name: String, l: Layout, st: LayoutPlan.State = LayoutPlan.State.SAMPLE) = LayoutPlan.planFor(device(name), l, 1f, st)
        // Pixel 7, sample: everything kept.
        for (l in Layout.entries) assertTrue(l.id, plan("Pixel 7", l).given.isEmpty())
        // iPhone 16 (Android type), sample: the gaps give way (bar → dial 8); the grids and the Targets rows stay.
        plan("iPhone 16", Layout.MEDIUM).let {
            assertTrue(it.resultLine, it.grid == GridMode.QUAD && it.given == setOf(LayoutPlan.Step.GAPS) && it.dial >= 340.8f)
            assertEquals(8f + 40f + 8f, it.dialTop, 0.01f)
        }
        // iPhone SE, sample: Medium's map goes to the button with one compact row, and the gaps and rows come back.
        plan("iPhone SE", Layout.MEDIUM).let {
            assertTrue(it.resultLine, it.grid == GridMode.ROW && it.map == MapMode.BUTTON && it.given == setOf(LayoutPlan.Step.BUTTON))
            assertEquals(60f, it.dialTop, 0f)
            assertTrue(it.resultLine, it.dial >= 0.40f * 667f)
        }
        // iPhone SE, sample: Large gives up its density (2 × 2 compact) before the button.
        plan("iPhone SE", Layout.LARGE).let {
            assertTrue(it.resultLine, LayoutPlan.Step.DENSITY in it.given && LayoutPlan.Step.BUTTON in it.given)
        }
        // 360 × 640, sample: nothing fits at 0.40 H: the list, its dial still 0.40 H.
        plan("Small Android", Layout.EXTRA_LARGE).let { assertTrue(it.resultLine, it.list && it.dial >= 256f) }
        // Live (no Targets card) on the same screen: no list for Small to Large.
        for (l in listOf(Layout.SMALL, Layout.MEDIUM, Layout.LARGE)) assertTrue(l.id, !plan("Small Android", l, LayoutPlan.State.LIVE).list)
    }

    /** A.4: Small ≤ Medium ≤ Large ≤ Extra Large on every portrait screen in every state at text sizes up to 1.3. */
    @Test fun dialsStepUp() {
        for (d in LayoutPlan.devices.filter { it.w < it.h }) for (st in LayoutPlan.State.entries) for (k in listOf(1f, 1.15f, 1.3f)) {
            val (s, m, l, xl) = Layout.entries.map { LayoutPlan.planFor(d, it, k, st) }
            val name = "${d.name} ${st.id} k$k: ${s.dial} ${m.dial} ${l.dial} ${xl.dial}"
            assertTrue(name, s.dial <= m.dial + 0.5f && m.dial <= l.dial + 0.5f && l.dial <= xl.dial + 0.5f)
        }
    }

    /** A.4: on the golden devices the sample state gives band / quad / six / strip with card / tile / button / button. */
    @Test fun layoutsAreDistinct() {
        for (name in LayoutPlan.goldenDevices) {
            val plans = Layout.entries.map { LayoutPlan.planFor(device(name), it) }
            assertEquals(name, listOf(GridMode.BAND, GridMode.QUAD, GridMode.SIX, GridMode.STRIP), plans.map { it.grid })
            assertEquals(name, listOf(MapMode.CARD, MapMode.TILE, MapMode.BUTTON, MapMode.BUTTON), plans.map { it.map })
            for (p in plans) assertTrue("$name ${p.layout.id}", p.dial + 0.5f >= LayoutPlan.ownerFloor(device(name).w, device(name).h))
            // Large is its own layout: no Map tile, the map in the location card.
            assertTrue(plans[2].rows.none { TileKind.MAP in it.tiles })
        }
    }

    /** The worked numbers on the Pixel 7 (A.9), sample: the golden cells. */
    @Test fun workedNumbersPixel7() {
        val d = device("Pixel 7")
        val (s, m, l, xl) = Layout.entries.map { LayoutPlan.planFor(d, it) }
        // The 40 bar frees 22 dp: Small's map card and Medium's dial (to its W − 32 cap) and tiles take it.
        assertEquals(368f, s.dial, 0.5f); assertTrue(s.resultLine, s.map == MapMode.CARD && s.mapHeight >= 220f)
        assertEquals(380f, m.dial, 0.5f); assertTrue("${m.tile}", m.tile >= 88f && abs(m.tile - m.tile2) < 0.01f)
        assertEquals(392f, l.dial, 0.5f); assertEquals(GridMode.SIX, l.grid); assertEquals(96f, l.tile, 0.5f)
        assertEquals(396f, xl.dial, 0.5f); assertTrue("${xl.tile}", xl.tile >= 120f)
        // The bar at safe top + 8, 40 tall; the dial 12 under it (60); the Targets card 12 under the status line;
        // the stack ends 8 over the navigation bar.
        assertEquals(8f, m.locationTop, 0f)
        assertEquals(40f, m.location, 0.01f)
        assertEquals(60f, m.dialTop, 0f)
        assertEquals(m.statusTop + m.status + 12f, m.targetsTop, 0.01f)
        assertEquals(d.s - 8f - m.bottomSpare, m.gridTop + m.gridHeight, 0.5f)
    }

    /** A.8 with the owner's mod: the location bar full width at the top, the trailing pane top-aligned with the dial, a map card ≥ 240 on a tablet. */
    @Test fun twoPanes() {
        for (name in listOf("iPad 11 landscape", "iPad 13 landscape", "Android tablet landscape", "Mac 1200x800")) for (l in Layout.entries) {
            val d = device(name)
            val p = LayoutPlan.planFor(d, l)
            assertTrue("$name ${l.id}", p.twoPane)
            assertEquals("$name ${l.id}", 8f, p.locationTop, 0.01f)
            assertEquals("$name ${l.id}", d.w - 48f, p.barWidth, 0.01f)
            assertEquals("$name ${l.id}", p.locationTop + p.location + 12f, p.dialTop, 0.01f)
            assertEquals("$name ${l.id}", p.dialTop, p.belowTop, 0.01f)
            assertTrue("$name ${l.id}: ${p.resultLine}", p.map == MapMode.CARD && p.mapHeight >= 240f && p.bottomSpare <= 24.5f)
            assertTrue("$name ${l.id}: trailing ${p.trailingWidth}", p.trailingWidth in 360f..560f)
        }
    }

    /** Two panes: Extra Large keeps its strip only where the strip's Position column holds a longitude; else two rows. */
    @Test fun narrowPaneStripGivesWayToTwoRows() {
        for (d in LayoutPlan.devices) for (k in listOf(1f, 1.15f)) {
            val p = LayoutPlan.planFor(d, Layout.EXTRA_LARGE, k)
            if (p.grid == GridMode.STRIP) assertTrue("${d.name} k$k", p.rows[0].widths[0] >= LayoutPlan.stripPositionNeed(k) - 0.5f)
        }
        // A 760 × 700 window: Extra Large's pane is 272 wide, its strip's Position column 104 (a longitude needs 112).
        val narrow = LayoutPlan.plan(760f, 700f, 652f, Layout.EXTRA_LARGE, locked = true, hasSpot = true)
        assertTrue(narrow.twoPane)
        assertEquals(GridMode.TWO_ROW, narrow.grid)
        assertEquals(listOf(TileKind.POSITION), narrow.rows[0].tiles)
        assertEquals(LayoutPlan.tileHeight(1f, narrow.tablet), narrow.tile, 0.01f)
        assertEquals(GridMode.STRIP, LayoutPlan.planFor(device("Android tablet landscape"), Layout.EXTRA_LARGE).grid)
    }

    /** A.8: a tablet column is at most 720 wide, tiles 96. */
    @Test fun tablet() {
        val p = LayoutPlan.planFor(device("iPad 11 portrait"), Layout.MEDIUM)
        assertTrue(p.tablet)
        assertTrue(p.column <= 720f)
        assertEquals(96f, p.tile, 0.01f)
        assertEquals(MapMode.CARD, p.map)
        assertEquals(listOf(TileKind.SUN, TileKind.MOON), p.rows[1].tiles)
    }

    /** A.7: accessibility text is one scrolling list, the location bar first (wrapping, ≥ 40), the dial still 0.40 H. */
    @Test fun accessibilityTextScrollsAsOneList() {
        val d = device("Pixel 7")
        val p = LayoutPlan.planFor(d, Layout.MEDIUM, 2f)
        assertTrue(p.list)
        assertTrue(p.locationTop < p.dialTop && p.location >= 40f)
        assertTrue(p.belowTop > p.statusTop)
        assertTrue(p.dial >= 0.40f * d.h)
        assertEquals(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN, TileKind.MOON), p.rows.map { it.tiles.single() })
    }

    /** "No heading" replaces the readout; its slot keeps the readout's height or its own 40 × k line. */
    @Test fun noHeadingSlot() {
        assertEquals("No heading", LayoutPlan.NO_HEADING_TEXT)
        assertEquals(0.55f, com.bradcowdrey.bearings.ui.Op.NO_HEADING, 0f)
        for (size in listOf(56f, 64f, 70f, 80f)) for (k in listOf(1f, 1.3f)) {
            assertEquals(maxOf(LayoutPlan.readoutHeight(size, k), 40f * k), LayoutPlan.readoutBlock(size, k, true), 0.01f)
            assertEquals(LayoutPlan.readoutHeight(size, k), LayoutPlan.readoutBlock(size, k, false), 0.01f)
        }
    }

    /** A.2: nothing ends in "…": the location card's time is never cut; the lock row's label and cue never split. */
    @Test fun noEllipsis() {
        val dates = listOf(Triple("Sun, Nov 1", "Nov 1", "9:41 AM"), Triple("Wed, Sep 30", "Sep 30", "12:59 PM"))
        for ((long, short, time) in dates) for (room in 4..40) {
            val lines = TextFit.headerLines(long, short, time) { it.length <= room }
            assertTrue(lines.none { '…' in it })
            assertTrue("$room: $lines", lines.any { time in it })
        }
        val (lead, cue) = TextFit.lockParts("Locked 240° · turn 12° right")
        assertEquals("Locked\u00A0240°", lead)
        assertEquals("turn\u00A012°\u00A0right", cue)
        assertEquals("240°", TextFit.shortLock(lead))
        assertEquals("6:36" to "AM", TextFit.splitClock("6:36 AM"))
        assertEquals("06:36" to null, TextFit.splitClock("06:36"))
        assertTrue(LayoutPlan.shortLock(300f))
        assertTrue(!LayoutPlan.shortLock(370f))
    }

    /** Both Position lines at one size, the longer line's. */
    @Test fun positionLinesShareOneSize() {
        val scale = mapOf("39.09898° N" to 0.95f, "106.94117° W" to 0.9f)
        assertEquals(0.9f, TextFit.sharedScale(scale.keys.toList()) { scale.getValue(it) }, 0f)
        assertEquals("39.09898°" to "North", TextFit.hemisphere("39.09898° N"))
        assertEquals("106.94117°" to "West", TextFit.hemisphere("106.94117° W"))
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
