package com.bradcowdrey.bearings.ui

import kotlin.math.max
import kotlin.math.min

/**
 * The four layouts (docs/REFINE.md §3.4): the dial's side margin [e] in dp, the readout's scale, the floor
 * under which the dial never goes (a share of the full height H), and the trailing pane's share of the width
 * in two panes. Saved under "layout" as [id]; anything else reads as Medium.
 */
enum class Layout(
    val id: String, val title: String, val subtitle: String, val e: Float, val readoutScale: Float,
    val floorShare: Float, val paneShare: Float,
) {
    SMALL("small", "Small", "Compass and map", 16f, 1.00f, 0.30f, 0.48f),
    MEDIUM("medium", "Medium", "Balanced", 16f, 1.00f, 0.38f, 0.42f),
    LARGE("large", "Large", "Bigger compass", 12f, 1.08f, 0.42f, 0.36f),
    EXTRA_LARGE("extraLarge", "Extra Large", "Biggest compass", 8f, 1.15f, 0.42f, 0.36f);

    /** The next larger layout, or null at Extra Large. */
    val larger: Layout? get() = entries.getOrNull(ordinal + 1)
    /** The next smaller layout, or null at Small. */
    val smaller: Layout? get() = entries.getOrNull(ordinal - 1)

    companion object {
        val DEFAULT = MEDIUM
        fun of(id: String?): Layout = entries.firstOrNull { it.id == id } ?: DEFAULT
    }
}

/** How the tiles are laid out: the full 2-row grid, the one compact row, or full-width rows (the scrolling list). */
enum class GridMode { FULL, COMPACT, ROWS }

/** Where the map is: a grid tile, a full-width card, or only the header's map button (both open the map sheet). */
enum class MapMode { TILE, CARD, BUTTON }

/** The planner's answer. Every length is in dp. */
data class Plan(
    val layout: Layout,
    val twoPane: Boolean,
    /** Accessibility text, or nothing fits even at the floor: the whole screen is one scrolling list (§3.6). */
    val list: Boolean,
    val tablet: Boolean,
    val dial: Float,
    val floor: Float,
    val readoutScale: Float,
    /** The heading number's size before the text multiplier: 56 (64 on a tablet) × the readout scale. */
    val headingSize: Float,
    val header: Float,
    /** Side margin of the header, readout and tiles: 16 (20 on a tablet). */
    val margin: Float,
    /** The tile column's width: min(W − 2 × margin, 640), or the trailing pane's width in two panes. */
    val column: Float,
    val grid: GridMode,
    val gridColumns: Int,
    val map: MapMode,
    /** The map card's height (0 unless [map] is CARD). */
    val mapHeight: Float,
    /** A tile's height: 72, grown up to 88 with spare height (more at a larger font size). */
    val tile: Float,
    /** Added above the header (step 4d). */
    val topExtra: Float,
    val headerGap: Float,
    val dialGap: Float,
    val groupGap: Float,
    /** What is left empty at the bottom, over the 8 dp bottom gap: never more than 24 in a single column. */
    val bottomSpare: Float,
    /** Step 4's spare height before it was spent (0 when the map card took it). */
    val spare: Float,
    /** Two panes: the trailing pane's width (0 in a single column). */
    val trailingWidth: Float,
    /** Two panes: the dial group's offset from the top of the content, so the trailing pane aligns with the dial. */
    val leadingTop: Float,
    val locked: Boolean,
    val hasSpot: Boolean,
    /** The content's planned height (single column); never more than the safe height unless [list]. */
    val used: Float,
) {
    /** The header shows the map button: the map is neither a tile nor a card. */
    val mapButton: Boolean get() = map == MapMode.BUTTON
}

/**
 * The layout planner (docs/REFINE.md §3.3), bottom-up: one pure function with no UI code and the same
 * constants and order as LayoutPlan.swift. The fixed blocks are placed first, the dial takes what is left up
 * to its cap, and spare height grows the tiles, then becomes a map card, then widens three gaps. Nothing is
 * left empty at the bottom (24 at most) and nothing is cut. Android's heights use 48 dp touch targets (the
 * spot row is 48, not 44).
 */
object LayoutPlan {
    // Spacing tokens (4 / 8 / 12 / 16 / 24 only).
    const val TOP = 4f
    const val HEADER_GAP = 12f
    const val DIAL_GAP = 12f
    const val STATUS_GAP = 6f
    const val CHIP_GAP = 8f
    const val GROUP_GAP = 16f
    const val ROW_GAP = 8f
    const val MAP_GAP = 12f
    const val BOTTOM = 8f
    const val MARGIN = 16f
    const val MARGIN_TABLET = 20f
    const val GAP_GROW = 12f
    const val BOTTOM_SPARE_MAX = 24f

    const val HEADER = 48f
    const val HEADER_TABLET = 52f
    const val HEADING = 56f
    const val HEADING_TABLET = 64f
    const val READOUT_LINE = 1.1f
    const val STATUS = 18f
    const val CHIP = 28f
    /** 44 on Apple; Android's ✕ target is 48 dp. */
    const val SPOT = 48f
    const val TILE = 72f
    const val TILE_GROW = 16f
    const val MAP_MIN = 140f
    const val MAP_PROMOTE = 160f
    const val LIST_MAP = 200f
    const val MAX_COLUMN = 640f
    const val DIAL_MIN = 140f
    const val SMALL_SHARE = 0.36f
    const val TABLET_SHARE = 0.48f
    const val LIST_SHARE = 0.40f
    /** The Mac's update banner (Apple only; Android has none, but the planner keeps the input). */
    const val BANNER = 44f
    const val TWO_PANE_WIDTH = 700f
    const val LANDSCAPE_PHONE = 480f
    const val TABLET_WIDTH = 600f
    const val PANE_MIN = 320f
    const val PANE_MAX = 480f
    const val PANE_THREE_COLUMNS = 360f
    /** The text multiplier's cap for the fixed panel; font scale 1.5 and up is the scrolling list. */
    const val MAX_K = 1.3f

    /**
     * [w] the window's (safe) width, [h] its full height including the system bars, [s] the safe height,
     * [k] the text multiplier (font scale), [accessibilityText] font scale 1.5 and up.
     */
    fun plan(
        w: Float,
        h: Float,
        s: Float,
        layout: Layout = Layout.DEFAULT,
        k: Float = 1f,
        accessibilityText: Boolean = false,
        locked: Boolean = false,
        hasSpot: Boolean = false,
        hasUpdateBanner: Boolean = false,
        isLandscapePhone: Boolean = false,
        twoLineStatus: Boolean = false,
    ): Plan {
        val kk = k.coerceIn(1f, MAX_K)
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val c = min(w - 2 * margin, MAX_COLUMN)
        // The cap is the column plus its margins, less 2e (as on Apple); tablets also cap at 0.48 H.
        val phoneCap = c + 2 * margin - 2 * layout.e
        val cap = if (tablet) min(phoneCap, TABLET_SHARE * h) else phoneCap
        val floor = min(layout.floorShare * h, cap)
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(kk, tablet)
        val banner = if (hasUpdateBanner) BANNER * kk + ROW_GAP else 0f
        val group = groupHeight(headingSize, kk, locked, twoLineStatus)
        val spot = if (hasSpot) spotHeight(kk) + ROW_GAP else 0f
        val tile = tileHeight(kk)

        fun list(): Plan {
            val dial = max(DIAL_MIN, min(c - 32f, LIST_SHARE * h))
            return Plan(
                layout, false, true, tablet, dial, floor, layout.readoutScale, headingSize, header, margin, c,
                GridMode.ROWS, 1, MapMode.CARD, LIST_MAP, tile, 0f, HEADER_GAP, DIAL_GAP, GROUP_GAP, 0f, 0f, 0f, 0f,
                locked, hasSpot, s,
            )
        }
        if (accessibilityText) return list()
        if (isLandscapePhone || (w > h && w >= TWO_PANE_WIDTH)) {
            return twoPanes(w, h, s, layout, kk, tablet, locked, hasSpot, hasUpdateBanner, twoLineStatus) ?: list()
        }

        var grid = when (layout) { Layout.SMALL, Layout.EXTRA_LARGE -> GridMode.COMPACT; else -> GridMode.FULL }
        var map = when (layout) { Layout.SMALL -> MapMode.CARD; Layout.EXTRA_LARGE -> MapMode.BUTTON; else -> MapMode.TILE }
        fun fixed(g: GridMode, tileH: Float): Float =
            TOP + header + HEADER_GAP + banner + group + GROUP_GAP + spot + gridHeight(g, tileH, 3) + BOTTOM

        var dial: Float
        var mapHeight = 0f
        var tileH = tile
        var top = 0f; var headerGap = HEADER_GAP; var dialGap = DIAL_GAP; var groupGap = GROUP_GAP; var bottom = 0f
        var spare = 0f
        if (layout == Layout.SMALL) {
            // Small: the dial at 36% of H, the map card fills the rest; the card shrinks toward 140, then the dial to its floor.
            val room = s - fixed(grid, tileH) - MAP_GAP
            dial = min(SMALL_SHARE * h, cap)
            mapHeight = room - dial
            if (mapHeight < MAP_MIN) { mapHeight = MAP_MIN; dial = room - MAP_MIN }
            if (dial + 0.5f < floor) return list()
        } else {
            // Large gives up its second row (Map moves to the header's button) before the dial shrinks.
            if (layout == Layout.LARGE && s - fixed(grid, tileH) < cap) { grid = GridMode.COMPACT; map = MapMode.BUTTON }
            dial = min(cap, s - fixed(grid, tileH))
            if (dial + 0.5f < floor) return list()
            // Step 4: spare height with the dial at its cap.
            spare = max(0f, s - fixed(grid, tileH) - dial)
            var left = spare
            // (a) 160 or more: the map becomes a full card (Extra Large's header button too: nothing is left empty).
            if (map != MapMode.CARD && left >= MAP_PROMOTE) {
                map = MapMode.CARD
                mapHeight = left - MAP_GAP
                left = 0f
            } else {
                val rows = if (grid == GridMode.FULL) 2 else 1
                val grow = min(TILE_GROW, left / rows)
                tileH += grow; left -= grow * rows
                var g = min(GAP_GROW, left / 3)
                left -= 3 * g
                // (d) The rest above the header and below the grid, at most 24 each (as on Apple); anything
                // still left widens the three gaps further, so no band of black is left anywhere.
                top = min(BOTTOM_SPARE_MAX, left / 2)
                bottom = min(BOTTOM_SPARE_MAX, left - top)
                g += max(0f, left - top - bottom) / 3
                headerGap += g; dialGap += g; groupGap += g
            }
        }
        val used = top + fixed(grid, tileH) - HEADER_GAP - DIAL_GAP - GROUP_GAP + headerGap + dialGap + groupGap + dial +
            (if (map == MapMode.CARD) MAP_GAP + mapHeight else 0f) + bottom
        return Plan(
            layout, false, false, tablet, dial, floor, layout.readoutScale, headingSize, header, margin, c,
            grid, 3, map, mapHeight, tileH, top, headerGap, dialGap, groupGap, bottom, spare, 0f, 0f, locked, hasSpot, used,
        )
    }

    /**
     * Two panes (§3.5): a full-width header; the dial group centred in the leading pane; the spot row, the grid
     * and the map card (where 160 or more is left, otherwise Map stays a tile) in the trailing pane, top-aligned with
     * the dial. Null when not even a 140 dial fits: the caller shows the scrolling list.
     */
    private fun twoPanes(
        w: Float, h: Float, s: Float, layout: Layout, k: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        hasUpdateBanner: Boolean, twoLineStatus: Boolean,
    ): Plan? {
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val trailing = (layout.paneShare * w).coerceIn(PANE_MIN, PANE_MAX).coerceAtMost(w / 2)
        val pane = w - trailing - 3 * margin
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(k, tablet)
        val banner = if (hasUpdateBanner) BANNER * k + ROW_GAP else 0f
        val group = groupHeight(headingSize, k, locked, twoLineStatus)
        val avail = s - TOP - header - HEADER_GAP - banner - BOTTOM
        // Too short for even the smallest dial: the caller falls back to the scrolling list (as on Apple).
        if (avail - group < DIAL_MIN) return null
        val dial = min(pane - 32f, avail - group)
        val leadingTop = max(0f, (avail - group - dial) / 2)
        val spot = if (hasSpot) spotHeight(k) + ROW_GAP else 0f
        var tile = tileHeight(k)
        val room = avail - leadingTop
        // 3 columns from 360 wide, otherwise 2; a short pane (a phone on its side, larger text) keeps 3 so the
        // grid's two rows fit rather than scroll.
        val columns = if (trailing >= PANE_THREE_COLUMNS || spot + gridHeight(GridMode.FULL, tile, 2) > room) 3 else 2
        val content = spot + gridHeight(GridMode.FULL, tile, columns)
        var map = MapMode.TILE
        var mapHeight = 0f
        var bottom = 0f
        // A whole card where 160 or more is left under the grid (§3.5); otherwise Map stays a tile.
        if (room - content >= MAP_PROMOTE) {
            map = MapMode.CARD; mapHeight = room - content - MAP_GAP
        } else {
            val rows = gridRows(GridMode.FULL, columns)
            val grow = max(0f, min(TILE_GROW, (room - content) / rows))
            tile += grow
            bottom = max(0f, room - content - grow * rows)
        }
        return Plan(
            layout, true, false, tablet, dial, DIAL_MIN, layout.readoutScale, headingSize, header, margin, trailing,
            GridMode.FULL, columns, map, mapHeight, tile, 0f, HEADER_GAP, DIAL_GAP, GROUP_GAP, bottom, 0f, trailing, leadingTop,
            locked, hasSpot, s,
        )
    }

    /** The header bar: 48 (52 on a tablet) × the text multiplier. */
    fun headerHeight(k: Float, tablet: Boolean) = (if (tablet) HEADER_TABLET else HEADER) * k
    /** The readout's height: the heading's line (1.1 × its size). */
    fun readoutHeight(headingSize: Float, k: Float) = headingSize * READOUT_LINE * k
    /** The status line: one 18 line, two at k > 1.1. */
    fun statusHeight(k: Float) = STATUS * k * (if (k > 1.1f) 2 else 1)
    fun chipHeight(k: Float) = max(CHIP, 10f + 18f * k)
    fun spotHeight(k: Float) = max(SPOT, 24f + 20f * k)
    /** A tile: 10 above and below, a 13 caption line and two 19 value lines, at least 72. */
    fun tileHeight(k: Float) = max(TILE, 20f + 51f * k)

    /** Dial → readout, the readout, the status line and the lock chip. */
    fun groupHeight(headingSize: Float, k: Float, locked: Boolean, twoLineStatus: Boolean = false) =
        DIAL_GAP + readoutHeight(headingSize, k) + STATUS_GAP + (if (twoLineStatus) 2 * STATUS * k else statusHeight(k)) +
            (if (locked) CHIP_GAP + chipHeight(k) else 0f)

    fun gridRows(mode: GridMode, columns: Int) = when (mode) {
        GridMode.COMPACT -> 1
        GridMode.FULL -> if (columns >= 3) 2 else 3
        GridMode.ROWS -> 5
    }

    fun gridHeight(mode: GridMode, tile: Float, columns: Int): Float {
        val rows = gridRows(mode, columns)
        return rows * tile + (rows - 1) * ROW_GAP
    }

    /** A device in the planner's table: width, full height, safe height. */
    data class Device(val name: String, val w: Float, val h: Float, val s: Float)

    /** The devices the self-test runs the planner on. Safe heights are typical insets. */
    val devices = listOf(
        Device("iPhone SE", 375f, 667f, 647f),
        Device("iPhone 16", 393f, 852f, 759f),
        Device("iPhone 16 Pro", 402f, 874f, 778f),
        Device("iPhone 17 Pro Max", 440f, 956f, 862f),
        Device("Pixel 7", 412f, 915f, 915f - 52f - 24f),
        Device("Small Android", 360f, 640f, 640f - 24f - 48f),
        Device("iPad 11 portrait", 834f, 1210f, 1166f),
        Device("iPad 13 portrait", 1032f, 1376f, 1332f),
        Device("iPad 11 landscape", 1210f, 834f, 790f),
        Device("iPad 13 landscape", 1376f, 1032f, 988f),
        Device("Mac 380x720", 380f, 720f, 720f),
        Device("Mac 420x840", 420f, 840f, 840f),
        Device("Phone landscape", 915f, 412f, 412f - 24f),
    )

    /** The four states of the golden table: nothing, locked, marked, both. */
    val states = listOf(false to false, true to false, false to true, true to true)

    /**
     * Runs the golden table (devices × layouts × states × text sizes) and returns the cases that break a rule
     * (§4.7): more than 24 empty at the bottom, content taller than the safe height (a block partly shown),
     * the dial under its floor or wider than its cap, a map card under 140. Empty when all is well.
     */
    fun tableFailures(): List<String> {
        val failures = mutableListOf<String>()
        for (d in devices) for (layout in Layout.entries) for ((locked, spot) in states) for (k in listOf(1f, 1.15f, 1.3f)) {
            val landscape = d.w > d.h && d.s < LANDSCAPE_PHONE
            val p = plan(d.w, d.h, d.s, layout, k, false, locked, spot, false, landscape)
            val name = "${d.name} ${layout.id} k$k${if (locked) " locked" else ""}${if (spot) " marked" else ""}"
            if (p.list) continue
            if (p.dial + 0.5f < p.floor) failures += "$name: dial ${p.dial} under ${p.floor}"
            if (p.map == MapMode.CARD && p.mapHeight + 0.5f < MAP_MIN) failures += "$name: map card ${p.mapHeight}"
            if (!p.twoPane) {
                if (p.bottomSpare > BOTTOM_SPARE_MAX + 0.5f) failures += "$name: ${p.bottomSpare} empty at the bottom"
                if (p.used > d.s + 0.5f) failures += "$name: ${p.used} taller than ${d.s}"
                if (p.dial > d.w - 2 * layout.e + 0.5f) failures += "$name: dial ${p.dial} wider than its cap"
            } else {
                // The trailing pane: the spot row, the grid and the map card fit under the dial's top.
                val room = d.s - TOP - p.header - HEADER_GAP - BOTTOM - p.leadingTop
                val content = (if (spot) spotHeight(k) + ROW_GAP else 0f) + gridHeight(p.grid, p.tile, p.gridColumns) +
                    (if (p.map == MapMode.CARD) MAP_GAP + p.mapHeight else 0f)
                if (content > room + 0.5f) failures += "$name: trailing pane ${content} taller than ${room}"
            }
        }
        // The worked numbers (§3.4, iPhone 16 Pro, Medium): the dial fills its cap, and the sample's is about 352.
        val medium = plan(402f, 874f, 778f)
        if (medium.dial != 370f || medium.map != MapMode.TILE || medium.tile != TILE + TILE_GROW) failures += "Medium on iPhone 16 Pro: ${medium.dial}, ${medium.map}, ${medium.tile}"
        if (plan(412f, 915f, 839f).layout != Layout.MEDIUM || Layout.of(null) != Layout.MEDIUM || Layout.of("bogus") != Layout.MEDIUM) failures += "Medium is not the default"
        return failures
    }

    /** The last plan the main screen drew, for the self-test's report. */
    @Volatile var last: Plan? = null
    @Volatile var lastHeight: Float = 0f
    @Volatile var lastSafeHeight: Float = 0f
}
