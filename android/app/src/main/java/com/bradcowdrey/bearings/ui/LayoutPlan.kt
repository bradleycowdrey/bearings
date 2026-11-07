package com.bradcowdrey.bearings.ui

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The four layouts (docs/REFINE.md §3.4, cycle 2 §C2.2 #2): one rule each, the same on every device.
 *
 * | Layout | Grid | Tiles | Map | Dial | Readout |
 * |---|---|---|---|---|---|
 * | Small | compact row | 72 | card of 140 or more | 0.36 H | 1.0 |
 * | Medium | full 2-row grid | 88 (96 on a tablet), 72 under pressure | tile, or a card when 160 or more is spare | to its cap, W − 40 (0.48 H on a tablet) | 1.0 |
 * | Large | full grid (compact row only when even the floor won't fit) | fixed 72 | tile | gets the saved height, up to W − 16 | 1.0 |
 * | Extra Large | compact row | 72 | the header's map button, on every device | W − 16 | 1.25 |
 *
 * [e] is the dial's side margin in dp, [floorShare] the share of the full height H under which the dial never
 * goes, [paneShare] the trailing pane's share of the width in two panes. Saved under "layout" as [id];
 * anything else reads as Medium.
 */
enum class Layout(
    val id: String, val title: String, val subtitle: String, val e: Float, val readoutScale: Float,
    val floorShare: Float, val paneShare: Float,
) {
    SMALL("small", "Small", "Compass and map", 16f, 1.00f, 0.30f, 0.48f),
    MEDIUM("medium", "Medium", "Balanced", 20f, 1.00f, 0.38f, 0.42f),
    LARGE("large", "Large", "Bigger compass", 8f, 1.00f, 0.42f, 0.36f),
    EXTRA_LARGE("extraLarge", "Extra Large", "Biggest compass", 8f, 1.25f, 0.42f, 0.36f);

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

/** Where the map is: a grid tile, a full-width card, or only the header's map button (all open the map sheet). */
enum class MapMode { TILE, CARD, BUTTON }

/** The tiles, in the order a row lists them. */
enum class TileKind { POSITION, ELEVATION, SUN, MOON, MAP }

/** One row of the grid: the tiles and their widths in dp (8 apart; the widths and gaps add up to the column). */
data class TileRowPlan(val tiles: List<TileKind>, val widths: List<Float>)

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
    /** A tile's height: 72, 88 for Medium (96 on a tablet), 80 in two panes (more at a larger font size). */
    val tile: Float,
    /** Added above the header (step 4d). */
    val topExtra: Float,
    val headerGap: Float,
    /** Dial → readout: 12, from the dial's bottom edge to the digits' cap height; never widened. */
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
    /** No compass (§4.2): the readout is "—°" with "NO HEADING" under it and a two-line status. */
    val noHeading: Boolean = false,
    /** Two panes: the trailing pane's content offset from the top (the dial's top, or centred against it). */
    val trailingTop: Float = 0f,
) {
    /** The header shows the map button: the map is neither a tile nor a card. */
    val mapButton: Boolean get() = map == MapMode.BUTTON

    /** The grid's rows, with widths that add up (with the 8 dp gaps) to [column]. */
    val rows: List<TileRowPlan> get() = LayoutPlan.rows(grid, gridColumns, map, column)

    /** The menu's subtitle for this layout (C2.2 #2): "Dial 386 · map in header". */
    val resultLine: String
        get() {
            val where = when {
                list -> "scrolls"
                map == MapMode.BUTTON -> "map in header"
                map == MapMode.CARD -> "map card"
                else -> "map tile"
            }
            return "Dial ${dial.roundToInt()} · $where"
        }
}

/**
 * The layout planner (docs/REFINE.md §3.3 and cycle 2), bottom-up: one pure function with no UI code and the
 * same constants and order as LayoutPlan.swift. The fixed blocks are placed first, the dial takes what is left
 * up to its cap, and spare height becomes a map card (Small and Medium) or widens two gaps. Nothing is left
 * empty at the bottom (24 at most) and nothing is cut. Android's heights use 48 dp touch targets (the spot row
 * and the lock row are 48, not 44).
 */
object LayoutPlan {
    // Spacing tokens (4 / 8 / 12 / 16 / 24 only).
    const val TOP = 4f
    const val HEADER_GAP = 12f
    const val DIAL_GAP = 12f
    const val STATUS_GAP = 6f
    /** Status line → lock row, × k. */
    const val CHIP_GAP = 8f
    /** Readout group → spot row or grid, × k. */
    const val GROUP_GAP = 16f
    const val ROW_GAP = 8f
    const val MAP_GAP = 12f
    const val BOTTOM = 8f
    const val MARGIN = 16f
    const val MARGIN_TABLET = 20f
    const val GAP_GROW = 12f
    const val BOTTOM_SPARE_MAX = 24f
    /** Readout → "NO HEADING" (no compass). */
    const val NO_HEADING_GAP = 4f
    const val NO_HEADING_LINE = 13f

    const val HEADER = 48f
    const val HEADER_TABLET = 52f
    const val HEADING = 56f
    const val HEADING_TABLET = 64f
    const val READOUT_LINE = 1.1f
    /**
     * Inter's cap height sits this far (× the heading size) under the top of the readout's 1.1 line box; the
     * line box is trimmed by it (0.15 in Inter; the planner counts 0.12 to keep a pixel or two in hand), so the 12
     * above the readout runs from the dial to the digits' cap height.
     */
    const val READOUT_TRIM = 0.12f
    /** Inter's cap height, × the font size (1490 / 2048). */
    const val CAP_HEIGHT = 0.7275f
    const val STATUS = 18f
    /**
     * The lock row and the spot row: one full-width row, 44 high on both platforms; Android's ✕ keeps its 48 dp
     * target, reaching 2 into the gaps around the row.
     */
    const val CHIP = 44f
    const val SPOT = 44f
    const val TILE = 72f
    /** Medium's grown tiles: 88 on a phone, 96 on a tablet (C2.2 #3). */
    const val TILE_GROW = 16f
    const val TILE_GROW_TABLET = 24f
    /** Tiles in two panes: fixed 80 rows (C2.3 #8). */
    const val PANE_TILE = 80f
    const val MAP_MIN = 140f
    const val MAP_PROMOTE = 160f
    const val LIST_MAP = 200f
    const val MAX_COLUMN = 640f
    const val DIAL_MIN = 140f
    const val SMALL_SHARE = 0.36f
    const val TABLET_SHARE = 0.48f
    const val LIST_SHARE = 0.40f
    /** In the scrolling list the fold should cut a block at least this far from its top and bottom (C2.3 #15). */
    const val FOLD_CUE = 24f
    /** The Mac's update banner (Apple only; Android has none, but the planner keeps the input). */
    const val BANNER = 44f
    const val TWO_PANE_WIDTH = 700f
    const val LANDSCAPE_PHONE = 480f
    const val TABLET_WIDTH = 600f
    const val PANE_MIN = 320f
    const val PANE_MAX = 480f
    const val PANE_THREE_COLUMNS = 360f
    /** The compact row's Elevation and Sun: w = max(104, round(0.27 C)) (C2.2 #1). */
    const val COMPACT_MIN = 104f
    const val COMPACT_SHARE = 0.27f
    /** The text multiplier's cap for the fixed panel; font scale 1.5 and up is the scrolling list. */
    const val MAX_K = 1.3f
    /** The readout with no heading: an em dash (U+2014) and a degree sign (§4.2, C2.3 #13). */
    const val NO_HEADING_READOUT = "—°"

    /**
     * [w] the window's (safe) width, [h] its full height including the system bars, [s] the safe height,
     * [k] the text multiplier (font scale), [accessibilityText] font scale 1.5 and up, [noHeading] no compass.
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
        noHeading: Boolean = false,
    ): Plan {
        val kk = k.coerceIn(1f, MAX_K)
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val c = min(w - 2 * margin, MAX_COLUMN)
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(kk, tablet)
        val banner = if (hasUpdateBanner) BANNER * kk + ROW_GAP else 0f
        val twoLines = twoLineStatus || noHeading
        val group = groupHeight(headingSize, kk, locked, twoLines, noHeading)
        val spot = if (hasSpot) spotHeight(kk) + ROW_GAP else 0f
        val tile = tileHeight(kk)
        // The dial's cap. Medium: the column and its margins less 2e (W − 40 on a phone), and 48% of H on a
        // tablet. Large and Extra Large: the window less 2e (W − 16), so Large is at least 24 bigger than
        // Medium wherever the width limits both. Small: 36% of H, within the same width.
        val widthCap = c + 2 * margin - 2 * layout.e
        val cap = when (layout) {
            Layout.MEDIUM -> if (tablet) min(widthCap, TABLET_SHARE * h) else widthCap
            Layout.LARGE, Layout.EXTRA_LARGE -> w - 2 * layout.e
            Layout.SMALL -> widthCap
        }
        val floor = min(layout.floorShare * h, cap)

        fun list(): Plan {
            // The list may run past 1.3 (font scale up to 2): estimate with the real multiplier.
            val kl = k.coerceIn(1f, 2f)
            val listHeader = headerHeight(kl, tablet) + 16f * kl
            val listGroup = groupHeight(headingSize, min(kl, MAX_K), locked, true, noHeading)
            val listSpot = if (hasSpot) spotHeight(kl) + ROW_GAP else 0f
            val first = max(DIAL_MIN, min(c - 32f, LIST_SHARE * h))
            val dial = listDial(first, s, TOP + listHeader + HEADER_GAP, listGroup + GROUP_GAP * kl + listSpot, listTileHeight(kl))
            return Plan(
                layout, false, true, tablet, dial, floor, layout.readoutScale, headingSize, header, margin, c,
                GridMode.ROWS, 1, MapMode.CARD, LIST_MAP, listTileHeight(kl), 0f, HEADER_GAP, DIAL_GAP, GROUP_GAP * kl, 0f, 0f, 0f, 0f,
                locked, hasSpot, s, noHeading,
            )
        }
        if (accessibilityText) return list()
        if (isLandscapePhone || (w > h && w >= TWO_PANE_WIDTH)) {
            return twoPanes(w, h, s, layout, kk, tablet, locked, hasSpot, hasUpdateBanner, twoLines, noHeading) ?: list()
        }

        var grid = when (layout) { Layout.SMALL, Layout.EXTRA_LARGE -> GridMode.COMPACT; else -> GridMode.FULL }
        var map = when (layout) { Layout.SMALL -> MapMode.CARD; Layout.EXTRA_LARGE -> MapMode.BUTTON; else -> MapMode.TILE }
        val groupGap0 = GROUP_GAP * kk
        fun fixed(g: GridMode, tileH: Float): Float =
            TOP + header + HEADER_GAP + banner + group + groupGap0 + spot + gridHeight(g, tileH, 3) + BOTTOM

        var dial: Float
        var mapHeight = 0f
        var tileH = tile
        var spare = 0f
        when (layout) {
            Layout.SMALL -> {
                // The dial at 36% of H, the map card fills the rest; the card shrinks toward 140, then the dial to its floor.
                val room = s - fixed(grid, tileH) - MAP_GAP
                dial = min(SMALL_SHARE * h, cap)
                mapHeight = room - dial
                if (mapHeight < MAP_MIN) { mapHeight = MAP_MIN; dial = room - MAP_MIN }
                if (dial + 0.5f < floor) return list()
            }
            Layout.MEDIUM -> {
                // "Balanced": the tiles grow first (to 88, 96 on a tablet), then the dial takes what is left up to
                // its cap. With no compass the tiles stay 72 and the spare becomes a map card (§4.2).
                val grown = tile + if (tablet) TILE_GROW_TABLET else TILE_GROW
                tileH = if (noHeading) tile else grown
                dial = min(cap, s - fixed(grid, tileH))
                if (dial + 0.5f < floor && tileH > tile) { tileH = tile; dial = min(cap, s - fixed(grid, tileH)) }
                if (dial + 0.5f < floor) return list()
                // Step 4a: 160 or more spare (with the tiles back at 72) becomes a whole map card.
                val spare72 = s - fixed(grid, tile) - dial
                if (spare72 >= MAP_PROMOTE) {
                    tileH = tile
                    map = MapMode.CARD
                    mapHeight = spare72 - MAP_GAP
                }
            }
            Layout.LARGE -> {
                // "Bigger compass": fixed 72 tiles, and the height that saves goes to the dial. Only when even the
                // floor won't fit does the grid give up its second row (Map moves to the header's button).
                dial = min(cap, s - fixed(grid, tileH))
                if (dial + 0.5f < floor) {
                    grid = GridMode.COMPACT; map = MapMode.BUTTON
                    dial = min(cap, s - fixed(grid, tileH))
                }
                if (dial + 0.5f < floor) return list()
            }
            Layout.EXTRA_LARGE -> {
                dial = min(cap, s - fixed(grid, tileH))
                if (dial + 0.5f < floor) return list()
            }
        }
        var top = 0f; var headerGap = HEADER_GAP; var groupGap = groupGap0; var bottom = 0f
        if (map != MapMode.CARD) {
            // Step 4c–d: what is left widens header → dial and readout group → grid (up to 12 each; dial →
            // readout stays 12), then goes above the header and below the grid, 24 at most each; anything still
            // left widens the same two gaps, so no band of black is left anywhere.
            spare = max(0f, s - fixed(grid, tileH) - dial)
            var left = spare
            var g = min(GAP_GROW, left / 2)
            left -= 2 * g
            top = min(BOTTOM_SPARE_MAX, left / 2)
            bottom = min(BOTTOM_SPARE_MAX, left - top)
            g += max(0f, left - top - bottom) / 2
            headerGap += g; groupGap += g
        }
        val used = top + fixed(grid, tileH) - HEADER_GAP - groupGap0 + headerGap + groupGap + dial +
            (if (map == MapMode.CARD) MAP_GAP + mapHeight else 0f) + bottom
        // On a tablet Large and Extra Large's dial can be wider than the 640 column: the header and the tiles
        // widen with it (never past the margins), so the panel keeps one edge.
        val column = if (tablet && (layout == Layout.LARGE || layout == Layout.EXTRA_LARGE)) min(w - 2 * margin, max(c, dial)) else c
        return Plan(
            layout, false, false, tablet, dial, floor, layout.readoutScale, headingSize, header, margin, column,
            grid, 3, map, mapHeight, tileH, top, headerGap, DIAL_GAP, groupGap, bottom, spare, 0f, 0f, locked, hasSpot, used,
            noHeading,
        )
    }

    /**
     * The scrolling list's dial (C2.3 #15): min(C − 32, 40% of H), made smaller (by up to 80, never under 140)
     * when the fold would fall within 24 of a block's edge, so the first screen visibly ends part-way into a
     * block rather than looking complete. [above] is everything over the dial, [between] the readout group
     * and spot row under it; then come four tile rows and the 200 map card.
     */
    fun listDial(first: Float, s: Float, above: Float, between: Float, tile: Float): Float {
        fun ok(dial: Float): Boolean {
            val edges = mutableListOf<Pair<Float, Float>>()
            var y = above
            edges += y to y + dial; y += dial + DIAL_GAP
            edges += y to y + between; y += between
            repeat(4) { edges += y to y + tile; y += tile + ROW_GAP }
            y += MAP_GAP - ROW_GAP
            edges += y to y + LIST_MAP
            val cut = edges.firstOrNull { (a, b) -> s > a && s < b } ?: return true
            return s - cut.first >= FOLD_CUE && cut.second - s >= FOLD_CUE
        }
        var d = first
        while (d >= max(DIAL_MIN, first - 80f)) { if (ok(d)) return d; d -= 2f }
        return first
    }

    /**
     * Two panes (§3.5, C2.3 #8): a full-width header; the dial group centred in the leading pane; in the
     * trailing pane, the spot row, the grid in fixed 80 rows and the map card with the rest (where 160 or more
     * is left; otherwise Map stays a tile and the pane's content is centred against the dial). Each layout keeps
     * its rule: Small the compact row, Medium and Large the full grid (Sun and Moon half each beside a card),
     * Extra Large the compact row with the map in the header. The panes' shares make the dials differ. Null when
     * not even a 140 dial fits: the caller shows the scrolling list.
     */
    private fun twoPanes(
        w: Float, h: Float, s: Float, layout: Layout, k: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        hasUpdateBanner: Boolean, twoLineStatus: Boolean, noHeading: Boolean,
    ): Plan? {
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val trailing = (layout.paneShare * w).coerceIn(PANE_MIN, PANE_MAX).coerceAtMost(w / 2)
        val pane = w - trailing - 3 * margin
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(k, tablet)
        val banner = if (hasUpdateBanner) BANNER * k + ROW_GAP else 0f
        val group = groupHeight(headingSize, k, locked, twoLineStatus, noHeading)
        val avail = s - TOP - header - HEADER_GAP - banner - BOTTOM
        // Too short for even the smallest dial: the caller falls back to the scrolling list (as on Apple).
        if (avail - group < DIAL_MIN) return null
        // Each layout keeps its dial rule here too (C2.2 #2), so the four differ in two panes as well: Small 36% of
        // H, Medium 48% of H, Large and Extra Large all the pane gives (never under the 140 minimum).
        val share = when (layout) { Layout.SMALL -> SMALL_SHARE; Layout.MEDIUM -> TABLET_SHARE; else -> Float.MAX_VALUE }
        val dial = min(min(pane - 32f, avail - group), max(DIAL_MIN, share * h))
        val leadingTop = max(0f, (avail - group - dial) / 2)
        val spot = if (hasSpot) spotHeight(k) + ROW_GAP else 0f
        val tile = max(PANE_TILE, tileHeight(k))
        val room = avail - leadingTop
        val grid = when (layout) { Layout.SMALL, Layout.EXTRA_LARGE -> GridMode.COMPACT; else -> GridMode.FULL }
        // 3 columns from 360 wide, otherwise 2; a short pane (a phone on its side, larger text) keeps 3 so the
        // grid's rows fit rather than scroll.
        val columns = if (trailing >= PANE_THREE_COLUMNS || spot + gridHeight(GridMode.FULL, tile, 2) > room) 3 else 2
        var map = if (layout == Layout.EXTRA_LARGE) MapMode.BUTTON else MapMode.TILE
        var content = spot + gridHeight(grid, tile, columns)
        var mapHeight = 0f
        var trailingTop = leadingTop
        var bottom: Float
        if (map != MapMode.BUTTON && room - content >= MAP_PROMOTE) {
            map = MapMode.CARD; mapHeight = room - content - MAP_GAP; bottom = 0f
        } else {
            if (grid == GridMode.COMPACT && map == MapMode.TILE) {
                // Small with no room for a card: the full grid, so the Map tile has a cell.
                content = spot + gridHeight(GridMode.FULL, tile, columns)
            }
            val left = max(0f, room - content)
            trailingTop = leadingTop + left / 2
            bottom = left - left / 2
        }
        val shownGrid = if (grid == GridMode.COMPACT && map == MapMode.TILE) GridMode.FULL else grid
        return Plan(
            layout, true, false, tablet, dial, DIAL_MIN, layout.readoutScale, headingSize, header, margin, trailing,
            shownGrid, columns, map, mapHeight, tile, 0f, HEADER_GAP, DIAL_GAP, GROUP_GAP * k, bottom, 0f, trailing, leadingTop,
            locked, hasSpot, s, noHeading, trailingTop,
        )
    }

    /** The header bar: 48 (52 on a tablet) × the text multiplier. */
    fun headerHeight(k: Float, tablet: Boolean) = (if (tablet) HEADER_TABLET else HEADER) * k
    /** The readout's height: the heading's 1.1 line, less the trim above the digits' cap height. */
    fun readoutHeight(headingSize: Float, k: Float) = headingSize * (READOUT_LINE - READOUT_TRIM) * k
    /** The status line: one 18 line, two at k > 1.1. */
    fun statusHeight(k: Float) = STATUS * k * (if (k > 1.1f) 2 else 1)
    /** The lock row (C2.3 #16): the spot row's form, 48 dp. */
    fun chipHeight(k: Float) = max(CHIP, 22f + 20f * k)
    fun spotHeight(k: Float) = max(SPOT, 22f + 20f * k)
    /** A tile: 10 above and below, a 13 caption line and two 19 value lines, at least 72. */
    fun tileHeight(k: Float) = max(TILE, 20f + 51f * k)
    /** A full-width row in the scrolling list: the same, with the larger text's lines. */
    fun listTileHeight(k: Float) = max(TILE, 20f + 51f * k)

    /** Dial → readout, the readout ("NO HEADING" under it with no compass), the status line and the lock row. */
    fun groupHeight(headingSize: Float, k: Float, locked: Boolean, twoLineStatus: Boolean = false, noHeading: Boolean = false) =
        DIAL_GAP + readoutHeight(headingSize, k) +
            (if (noHeading) NO_HEADING_GAP + NO_HEADING_LINE * k else 0f) +
            STATUS_GAP + (if (twoLineStatus) 2 * STATUS * k else statusHeight(k)) +
            (if (locked) CHIP_GAP * k + chipHeight(k) else 0f)

    fun gridRows(mode: GridMode, columns: Int) = when (mode) {
        GridMode.COMPACT -> 1
        GridMode.FULL -> if (columns >= 3) 2 else 3
        GridMode.ROWS -> 4
    }

    fun gridHeight(mode: GridMode, tile: Float, columns: Int): Float {
        val rows = gridRows(mode, columns)
        return rows * tile + (rows - 1) * ROW_GAP
    }

    /**
     * The compact row's widths (C2.2 #1): Position = C − 2·8 − 2w | Elevation = w | Sun = w, with
     * w = max(104, round(0.27 C)). They come from C, not from grid units, so the row is exactly as wide as the
     * column: 146 | 104 | 104 at C = 370, 156 | 104 | 104 at 380, 306 | 189 | 189 at 700.
     */
    fun compactWidths(c: Float): List<Float> {
        val w = max(COMPACT_MIN, (COMPACT_SHARE * c).roundToInt().toFloat())
        return listOf(c - 2 * ROW_GAP - 2 * w, w, w)
    }

    /**
     * The grid's rows at column width [c]. Full, 3 columns (u = (C − 16) / 3): Position (2u + 8) | Elevation,
     * then Sun | Moon | Map, or Sun | Moon at (C − 8) / 2 each when the map is a card or a header button.
     * 2 columns: Position; Elevation | Sun; Moon | Map (or Moon alone). Compact: [compactWidths]. Rows: one
     * full-width tile each.
     */
    fun rows(mode: GridMode, columns: Int, map: MapMode, c: Float): List<TileRowPlan> {
        val u = (c - 2 * ROW_GAP) / 3
        val half = (c - ROW_GAP) / 2
        val tileMap = map == MapMode.TILE
        return when (mode) {
            GridMode.ROWS -> listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN, TileKind.MOON).map { TileRowPlan(listOf(it), listOf(c)) }
            GridMode.COMPACT -> listOf(TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN), compactWidths(c)))
            GridMode.FULL -> if (columns >= 3) listOf(
                TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION), listOf(c - ROW_GAP - u, u)),
                if (tileMap) TileRowPlan(listOf(TileKind.SUN, TileKind.MOON, TileKind.MAP), listOf(u, u, c - 2 * ROW_GAP - 2 * u))
                else TileRowPlan(listOf(TileKind.SUN, TileKind.MOON), listOf(half, c - ROW_GAP - half)),
            ) else listOf(
                TileRowPlan(listOf(TileKind.POSITION), listOf(c)),
                TileRowPlan(listOf(TileKind.ELEVATION, TileKind.SUN), listOf(half, c - ROW_GAP - half)),
                if (tileMap) TileRowPlan(listOf(TileKind.MOON, TileKind.MAP), listOf(half, c - ROW_GAP - half))
                else TileRowPlan(listOf(TileKind.MOON), listOf(c)),
            )
        }
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

    /** The devices the "four distinct layouts" check runs on: phones, a Mac window, tablets, portrait. */
    private val distinctDevices = setOf("iPhone SE", "iPhone 16", "iPhone 16 Pro", "iPhone 17 Pro Max", "Pixel 7",
        "iPad 11 portrait", "iPad 13 portrait", "Mac 420x840")

    /** The plan for [d]; font scale 1.5 and up is the scrolling list, as on the phone. */
    fun planFor(d: Device, layout: Layout, k: Float = 1f, locked: Boolean = false, spot: Boolean = false, noHeading: Boolean = false): Plan {
        val landscape = d.w > d.h && d.s < LANDSCAPE_PHONE
        return plan(d.w, d.h, d.s, layout, k, k >= 1.5f, locked, spot, false, landscape, noHeading = noHeading)
    }

    /**
     * Runs the golden table (devices × layouts × states × text sizes) and returns the cases that break a rule
     * (§4.7 and C2's tests): more than 24 empty at the bottom, content taller than the safe height (a block
     * partly shown), the dial under its floor or wider than its cap, a map card under 140; every row's widths
     * and gaps adding up to its column; adjacent layouts differing by 24 or more of dial or by grid mode; Extra
     * Large keeping the map in the header everywhere; and the no-compass readout being "—°". Empty when all is
     * well.
     */
    fun tableFailures(): List<String> {
        val failures = mutableListOf<String>()
        for (d in devices) for (layout in Layout.entries) for ((locked, spot) in states) for (k in listOf(1f, 1.15f, 1.3f)) for (noHeading in listOf(false, true)) {
            if (noHeading && locked) continue
            val p = planFor(d, layout, k, locked, spot, noHeading)
            val name = "${d.name} ${layout.id} k$k${if (locked) " locked" else ""}${if (spot) " marked" else ""}${if (noHeading) " no compass" else ""}"
            // The rows add up to the column, in every mode (C2.2 #1).
            for (row in p.rows) {
                val sum = row.widths.sum() + ROW_GAP * (row.widths.size - 1)
                if (abs(sum - p.column) > 0.01f) failures += "$name: row ${row.tiles} is $sum wide in a ${p.column} column"
                if (row.widths.any { it < 80f }) failures += "$name: a tile in ${row.tiles} is under 80 wide (${row.widths})"
            }
            if (p.list) continue
            if (layout == Layout.EXTRA_LARGE && p.map != MapMode.BUTTON) failures += "$name: Extra Large's map is not in the header"
            if (p.dial + 0.5f < p.floor) failures += "$name: dial ${p.dial} under ${p.floor}"
            if (p.map == MapMode.CARD && p.mapHeight + 0.5f < MAP_MIN) failures += "$name: map card ${p.mapHeight}"
            if (!p.twoPane) {
                if (p.bottomSpare > BOTTOM_SPARE_MAX + 0.5f) failures += "$name: ${p.bottomSpare} empty at the bottom"
                if (p.used > d.s + 0.5f) failures += "$name: ${p.used} taller than ${d.s}"
                if (abs(p.used - d.s) > 0.5f) failures += "$name: ${d.s - p.used} not accounted for"
                if (p.dial > d.w - 2 * layout.e + 0.5f) failures += "$name: dial ${p.dial} wider than its cap"
                if (p.dialGap != DIAL_GAP) failures += "$name: dial → readout ${p.dialGap}"
            } else {
                // The trailing pane: the spot row, the grid and the map card fit under the dial's top.
                val room = d.s - TOP - p.header - HEADER_GAP - BOTTOM - p.trailingTop
                val content = (if (spot) spotHeight(k) + ROW_GAP else 0f) + gridHeight(p.grid, p.tile, p.gridColumns) +
                    (if (p.map == MapMode.CARD) MAP_GAP + p.mapHeight else 0f)
                if (content > room + 0.5f) failures += "$name: trailing pane $content taller than $room"
                if (p.map == MapMode.TILE && p.rows.none { TileKind.MAP in it.tiles }) failures += "$name: the Map tile has no cell"
            }
        }
        // Four distinct layouts (C2.2 #2): each next layout has a dial 24 or more larger, or a different grid.
        for (d in devices.filter { it.name in distinctDevices }) {
            val plans = Layout.entries.map { planFor(d, it) }
            for (i in 1 until plans.size) {
                val a = plans[i - 1]; val b = plans[i]
                if (a.list || b.list) continue
                if (b.dial - a.dial < 24f - 0.5f && a.grid == b.grid) failures += "${d.name}: ${b.layout.id} (${b.dial}, ${b.grid}) is not distinct from ${a.layout.id} (${a.dial}, ${a.grid})"
            }
        }
        // The worked numbers (iPhone 16 Pro, nothing locked or marked).
        val pro = devices.first { it.name == "iPhone 16 Pro" }
        val medium = planFor(pro, Layout.MEDIUM)
        if (medium.dial != 362f || medium.map != MapMode.TILE || medium.tile != TILE + TILE_GROW) failures += "Medium on iPhone 16 Pro: ${medium.dial}, ${medium.map}, ${medium.tile}"
        val large = planFor(pro, Layout.LARGE)
        if (large.dial != 386f || large.grid != GridMode.FULL || large.tile != TILE) failures += "Large on iPhone 16 Pro: ${large.dial}, ${large.grid}, ${large.tile}"
        val compact = compactWidths(370f)
        if (compact != listOf(146f, 104f, 104f) || compactWidths(380f) != listOf(156f, 104f, 104f) || compactWidths(700f) != listOf(306f, 189f, 189f)) {
            failures += "Compact widths: $compact, ${compactWidths(380f)}, ${compactWidths(700f)}"
        }
        if (NO_HEADING_READOUT != "—°") failures += "The no-compass readout is $NO_HEADING_READOUT"
        if (Layout.of(null) != Layout.MEDIUM || Layout.of("bogus") != Layout.MEDIUM) failures += "Medium is not the default"
        return failures
    }

    /** The last plan the main screen drew, for the self-test's report. */
    @Volatile var last: Plan? = null
    @Volatile var lastWidth: Float = 0f
    @Volatile var lastHeight: Float = 0f
    @Volatile var lastSafeHeight: Float = 0f
}

/**
 * Text that must never end in "…" (C2.2 #1, C2.3 #14), as pure functions so the self-test can run them with
 * its own measure: [fits] says whether a line fits on one line where it is shown.
 */
object TextFit {
    /**
     * Header line 2: "Sun, Nov 1 · 9:41 AM"; when that is too long, "Nov 1 · 9:41 AM"; then "Nov 1" over
     * "9:41 AM" (wrapped at the "·"). The time is never cut.
     */
    fun headerLines(longDate: String, shortDate: String, time: String, fits: (String) -> Boolean): List<String> {
        val long = "$longDate · $time"
        if (fits(long)) return listOf(long)
        val short = "$shortDate · $time"
        if (fits(short)) return listOf(short)
        return listOf(shortDate, time)
    }

    /** "6:36 AM" → ("6:36", "AM"), so a narrow Sun tile can put AM under the time; "06:36" → ("06:36", null). */
    fun splitClock(t: String): Pair<String, String?> {
        val i = t.indexOfLast { it == ' ' || it == ' ' || it == ' ' }
        if (i <= 0) return t to null
        val tail = t.substring(i + 1)
        return if (tail.isNotEmpty() && tail.none { it.isDigit() }) t.substring(0, i).trimEnd() to tail else t to null
    }
}
