package com.bradcowdrey.bearings.ui

import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The four layouts of Concept A, the instrument panel (docs/REFINE.md "Concept A (chosen)", A.3). Every layout
 * reads, top to bottom: dial → readout → status line → location card → Targets card (only with a lock or a spot)
 * → its own tiles or map.
 *
 * | | Small | Medium (default) | Large | Extra Large |
 * |---|---|---|---|---|
 * | Grid | [GridMode.BAND] over the map card | [GridMode.QUAD], 2 × 2 with the Map tile | [GridMode.SIX], 3 × 2 | [GridMode.STRIP] |
 * | Map | card, takes all spare | tile | location card button | location card button |
 * | Dial cap | ceil8(0.40 H) | ceil8(0.40 H) | ceil8(0.42 H) | W − 16 |
 * | Readout | 1.0 | 1.0 | 1.0 | 1.25 |
 *
 * The owner's rule: in one portrait column the dial is never under 0.40 H ([LayoutPlan.ownerFloor]), in every
 * layout, state and text size, the scrolling list included. [paneShare] is the dial's share of H in two panes.
 * Saved under "layout" as [id]; anything else reads as Medium. [subtitle] is the layout menu's line.
 */
enum class Layout(
    val id: String, val title: String, val subtitle: String, val readoutScale: Float,
    val paneShare: Float,
) {
    SMALL("small", "Small", "Compass + big map", 1.00f, 0.56f),
    MEDIUM("medium", "Medium", "Balanced · map tile", 1.00f, 0.62f),
    LARGE("large", "Large", "Bigger compass · map in header", 1.00f, 0.66f),
    EXTRA_LARGE("extraLarge", "Extra Large", "Biggest compass · one row", 1.25f, 0.72f);

    /** The next larger layout, or null at Extra Large. */
    val larger: Layout? get() = entries.getOrNull(ordinal + 1)
    /** The next smaller layout, or null at Small. */
    val smaller: Layout? get() = entries.getOrNull(ordinal - 1)

    companion object {
        val DEFAULT = MEDIUM
        fun of(id: String?): Layout = entries.firstOrNull { it.id == id } ?: DEFAULT
    }
}

/**
 * How the tiles are laid out (A.3, A.6, A.7):
 * - [BAND] Small: Position · DD | Elevation | Sun on a band along the map card's bottom (1.2 | 1 | 1);
 * - [QUAD] Medium: Position | Elevation, Sun | Map (Sun | Moon when the map is a card, on a tablet or in two panes);
 * - [SIX] Large: Latitude | Longitude | Elevation, Sun | Moon | Pressure or Speed (3 × 2 compact tiles);
 * - [STRIP] Extra Large: one summary tile, Position | Elevation | Sun (1.25 | 1 | 1, 1 dp dividers);
 * - [QUAD_COMPACT] Large given way (or at large text): Position | Elevation, Sun | Pressure or Speed;
 * - [ROW] the give-way row (A.6 step 6): Position (C − 16 − 2w) | Elevation (w) | Sun (w), the map in the card's button;
 * - [TWO_ROW] large text (k ≥ 1.3): Position full width, then Elevation | Sun; also Extra Large in a trailing pane
 *   too narrow for the strip's longitude;
 * - [ROWS] the scrolling list: one full-width row each.
 */
enum class GridMode { BAND, QUAD, SIX, STRIP, QUAD_COMPACT, ROW, TWO_ROW, ROWS }

/** Where the map is: a grid tile, a full-width card, or only the location card's map button (all open the map sheet). */
enum class MapMode { TILE, CARD, BUTTON }

/** The tiles, in the order a row lists them. */
enum class TileKind { POSITION, LATITUDE, LONGITUDE, ELEVATION, SUN, MOON, PRESSURE, SPEED, MAP }

/** Large's sixth tile (A.3): Speed while moving (0.5 m/s or more), otherwise Pressure. Never unrelated data. */
enum class Sixth { PRESSURE, SPEED }

/**
 * One row of the grid: the tiles and their widths in dp, [gap] apart, inside [inset] at each side (the band's 12
 * padding). The widths, the gaps and the insets add up to the column ([total]).
 */
data class TileRowPlan(val tiles: List<TileKind>, val widths: List<Float>, val gap: Float = LayoutPlan.ROW_GAP, val inset: Float = 0f) {
    val total: Float get() = widths.sum() + gap * (widths.size - 1) + 2 * inset
}

/**
 * The planner's answer. Every length is in dp, from the top of the safe area. The screen reads the dial, every
 * block's height and every gap from here and nowhere else (A.5).
 */
data class Plan(
    val layout: Layout,
    val twoPane: Boolean,
    /** Accessibility text, or nothing fits even with everything given way: one scrolling list (A.7). */
    val list: Boolean,
    val tablet: Boolean,
    /** The text multiplier the heights use (1 to 1.3; up to 2 in the list). */
    val k: Float,
    val dial: Float,
    /** The owner's floor, ceil(0.40 H) (W − 16 where the window is narrower). */
    val floor: Float,
    /** The layout's dial cap (A.3); spare beyond the layout's growth may take the dial on to [widthCap]. */
    val cap: Float,
    val widthCap: Float,
    /** The heading number's size before the text multiplier: 56 (64 on a tablet) × the readout scale. */
    val headingSize: Float,
    /** Safe top → dial top: 18, or 12 given way (A.6 step 2). */
    val dialTop: Float,
    /** Status line → location card: 12, or 8 given way. */
    val cardGap: Float,
    /** The location card's height (56 × k, a line more for a wrapped place or date). */
    val location: Float,
    /** Lines of the status line (1, or 2 when it wraps). */
    val statusLines: Int,
    /** The Targets card's rows (0, 1 or 2) and their height: 48, 64 (Extra Large), 56 (tablet), 40 / 48 compact. */
    val targetsRows: Int,
    val targetsRowHeight: Float,
    /** Side margin of the column: 16 (24 on a Mac; a tablet's column is min(W − 48, 720), centred). */
    val margin: Float,
    /** The column's width: the location card, the Targets card and the tiles (the trailing pane in two panes). */
    val column: Float,
    val grid: GridMode,
    val map: MapMode,
    /** The first grid row's height (the band's, the strip's, the row's). */
    val tile: Float,
    /** The second grid row's height (Medium's grows on to 176 when the Targets card is absent). */
    val tile2: Float,
    /** The map card's height (Small's includes its band), or the list's Map tile. 0 otherwise. */
    val mapHeight: Float,
    val sixth: Sixth,
    /** Decimal degrees: Large splits Position into Latitude and Longitude only for DD. */
    val decimal: Boolean,
    /** What step 4 left at the bottom (at most 24). */
    val bottomSpare: Float,
    /** The stack's end above the safe bottom: 8 on Android (16 at large text), 0 over a home indicator. */
    val endGap: Float,
    /** Two panes: the trailing pane's width (0 in a single column). */
    val trailingWidth: Float,
    val locked: Boolean,
    val hasSpot: Boolean,
    /** The content's planned height (single column); the safe height unless [list] or [twoPane]. */
    val used: Float,
    /** No compass: "No heading" in words takes the readout's place (A.2). */
    val noHeading: Boolean,
    /** What the layout gave up to keep the dial at the owner's floor (A.6), in order. */
    val given: Set<LayoutPlan.Step> = emptySet(),
    /** The dial was held under what the height allowed so a larger layout keeps the larger compass. */
    val held: Boolean = false,
    /** The Mac's update banner, between the location card and the Targets card. */
    val banner: Boolean = false,
) {
    /** The location card shows the map button: the map is neither a tile nor a card. */
    val mapButton: Boolean get() = map == MapMode.BUTTON
    /** The location card keeps the map button's slot (Large and Extra Large, hidden in two panes where a card shows the map). */
    val mapButtonSlot: Boolean get() = mapButton || layout == Layout.LARGE || layout == Layout.EXTRA_LARGE
    val readoutScale: Float get() = layout.readoutScale

    // The frozen gaps (A.1): never grown, given up only in A.6's order.
    val dialGap: Float get() = LayoutPlan.DIAL_GAP
    val statusGap: Float get() = LayoutPlan.STATUS_GAP * k
    val targetsGap: Float get() = LayoutPlan.TARGETS_GAP
    val gridGap: Float get() = LayoutPlan.GRID_GAP
    val rowGap: Float get() = LayoutPlan.ROW_GAP
    val mapGap: Float get() = LayoutPlan.MAP_GAP
    /** The readout's slot: the readout, or "No heading" (40 × k at least), so nothing below it moves. */
    val readout: Float get() = LayoutPlan.readoutBlock(headingSize, min(k, LayoutPlan.MAX_K), noHeading)
    val status: Float get() = LayoutPlan.statusHeight(k, statusLines)
    val targets: Float get() = targetsRows * targetsRowHeight
    val bannerHeight: Float get() = if (banner) LayoutPlan.BANNER + LayoutPlan.TARGETS_GAP else 0f
    /** Dial edge → readout → status line, as one group. */
    val group: Float get() = dialGap + readout + statusGap + status

    // Positions from the top of the safe area, single column (A.1). In two panes the location card is top-aligned with the dial.
    val readoutTop: Float get() = dialTop + dial + dialGap
    val statusTop: Float get() = readoutTop + readout + statusGap
    val locationTop: Float get() = if (twoPane) dialTop else statusTop + status + cardGap
    val targetsTop: Float get() = locationTop + location + targetsGap + bannerHeight
    val gridTop: Float get() = (if (targetsRows > 0) targetsTop + targets else locationTop + location + bannerHeight) + gridGap
    val gridHeight: Float get() = LayoutPlan.gridHeight(grid, tile, tile2)
    /** The map card's top: Small's card is where the grid starts (its band is inside it); otherwise under the grid. */
    val mapTop: Float get() = if (grid == GridMode.BAND || gridHeight == 0f) gridTop else gridTop + gridHeight + mapGap

    /** The grid's rows, with widths that add up (with their gaps and insets) to [column]. */
    val rows: List<TileRowPlan> get() = LayoutPlan.rows(grid, map, column, sixth, decimal)

    /** For the self-test's report and the layout menu: "dial 352 · 2 × 2 · map tile". */
    val resultLine: String
        get() {
            if (list) return "dial ${dial.roundToInt()} · list · scrolls"
            val where = when (map) {
                MapMode.BUTTON -> "map button"
                MapMode.CARD -> "map card ${mapHeight.roundToInt()}"
                MapMode.TILE -> "map tile"
            }
            val g = when (grid) {
                GridMode.BAND -> "band"; GridMode.QUAD -> "2 × 2"; GridMode.SIX -> "3 × 2"; GridMode.STRIP -> "strip"
                GridMode.QUAD_COMPACT -> "2 × 2 compact"; GridMode.ROW -> "compact"; GridMode.TWO_ROW -> "two rows"; GridMode.ROWS -> "list"
            }
            return "dial ${dial.roundToInt()} · $g · $where"
        }
}

/**
 * The layout planner (A.5), one pure function with no UI code and the same steps as LayoutPlan.swift:
 * 1. Anchors: the dial's top is the safe top + 18; the stack ends [Plan.endGap] above the safe bottom.
 * 2. Fixed blocks: the readout group (12 + readout + 6k + status), 12 + the location card, 8 + the Targets card
 *    (rows × row height, only with a lock or spot), 8 + the layout's grid at its minimum (Small: a 140 map card).
 * 3. Dial = min(cap, what is left). Under the owner's floor ceil(0.40 H), the layout gives way in A.6's order,
 *    re-planning after each step: spare gaps (18 → 12, 12 → 8), Targets rows to compact height, grid density
 *    (Large's six → 2 × 2 compact), the map tile or card → the location card's map button with one compact row, and
 *    only then the scrolling list. Given-up steps come back, in reverse order, where the height allows.
 * 4. Spare height goes to the layout's growth (Small's map card; Medium's rows to 88, row 2 on to 176; Large's to
 *    104; Extra Large's strip to 120), then — past 24 — to the dial up to its width cap, then the bottom (≤ 24).
 * The dials step up, Small ≤ Medium ≤ Large ≤ Extra Large: a layout's dial is held at the next larger one's.
 */
object LayoutPlan {
    // The frozen gap tokens (A.1).
    /** Safe top → dial top, and given way. */
    const val DIAL_TOP = 18f
    const val DIAL_TOP_TIGHT = 12f
    /** Dial edge → the readout's cap top. */
    const val DIAL_GAP = 12f
    /** Readout → status line, × k. */
    const val STATUS_GAP = 6f
    /** Status line → location card, and given way. */
    const val CARD_GAP = 12f
    const val CARD_GAP_TIGHT = 8f
    /** Location card → Targets card. */
    const val TARGETS_GAP = 8f
    /** Targets card (or location card) → the tiles or map. */
    const val GRID_GAP = 8f
    const val ROW_GAP = 8f
    /** Grid → map card (iPad Medium, two panes, Small at large text). */
    const val MAP_GAP = 8f
    /** Android: the stack ends this far above the navigation bar (16 at large text). */
    const val END = 8f
    const val END_LARGE_TEXT = 16f
    /** Step 4: the most left empty at the bottom. */
    const val BOTTOM_SPARE_MAX = 24f
    const val MARGIN = 16f
    const val MARGIN_MAC = 24f
    /** A tablet's column: min(W − 2 × 24, 720), centred. */
    const val TABLET_INSET = 24f
    const val MAX_COLUMN = 720f
    /** Two panes: 24 outer margins, 32 between the panes. */
    const val PANE_MARGIN = 24f
    const val PANE_GAP = 32f
    /** The owner's rule: in one portrait column the dial is at least 40% of H. */
    const val OWNER_SHARE = 0.40f
    const val LARGE_SHARE = 0.42f

    const val LOCATION = 56f
    const val TITLE_LINE = 22f
    const val DATE_LINE = 20f
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
    /** "No heading" (A.2): 34 sp semibold on a 40 line, white 55%. */
    const val NO_HEADING_SIZE = 34f
    const val NO_HEADING_LINE = 40f
    const val STATUS = 18f
    /** The Targets card's rows (A.2, A.9). */
    const val TARGET_ROW = 48f
    const val TARGET_ROW_XL = 64f
    const val TARGET_ROW_TABLET = 56f
    const val TARGET_ROW_COMPACT = 40f
    const val TARGET_ROW_XL_COMPACT = 48f
    const val TARGET_ROW_LIST = 84f
    const val TILE = 72f
    const val TILE_MEDIUM_MAX = 88f
    /**
     * Medium with no Targets card: row 2 grows on to 176; from 165 (the tall Sun tile's drawn height, as on Apple) the
     * Sun tile adds the daylight and the moon and the Map tile the speed. A shorter row keeps the plain Sun tile.
     */
    const val TILE_MEDIUM_TALL = 176f
    const val SUN_MOON_FROM = 165f
    const val TILE_LARGE_MAX = 104f
    const val TILE_TABLET = 96f
    const val QUAD_COMPACT = 64f
    const val BAND = 72f
    const val STRIP = 104f
    const val STRIP_MAX = 120f
    /** The strip's columns: 12 across each side. */
    const val STRIP_INSET = 12f
    /** "106.94117° W" on one line at 0.85 of the strip's 15 sp value, with a little to spare (Apple: the same at 15 pt). */
    const val POSITION_LINE = 88f
    const val MAP_MIN = 140f
    /** Two panes: the map card is at least this tall (Small: 60% of the pane too). */
    const val PANE_MAP = 240f
    const val PANE_SMALL_SHARE = 0.6f
    /** The scrolling list: 96 rows, a 176 Map tile. */
    const val LIST_TILE = 96f
    const val LIST_MAP = 176f
    const val DIAL_MIN = 140f
    /** The Mac's update banner (Apple only; Android has none, but the planner keeps the input). */
    const val BANNER = 44f
    const val TWO_PANE_WIDTH = 700f
    const val LANDSCAPE_PHONE = 480f
    const val TABLET_WIDTH = 600f
    const val PANE_MIN = 360f
    const val PANE_MAX = 560f
    const val PANE_SHARE = 0.4333f
    /** Extra Large's leading pane takes 60% of the width. */
    const val PANE_XL_LEADING = 0.6f
    /** The compact row's Elevation and Sun: w = max(104, round(0.27 C)). */
    const val COMPACT_MIN = 104f
    const val COMPACT_SHARE = 0.27f
    /** The text multiplier's cap for the fixed panel; font scale 1.5 and up is the scrolling list. */
    const val MAX_K = 1.3f
    /** From this text size every three-column compact arrangement becomes two rows (A.7). */
    const val TWO_ROW_K = 1.3f
    /** Moving: the sixth tile shows Speed from this speed (m/s). */
    const val MOVING = 0.5
    /** Below this column "Locked 240°" shortens to "240°". */
    const val SHORT_LOCK_COLUMN = 320f
    /** What TalkBack hears for the no-heading readout. */
    const val NO_HEADING_SPOKEN = "Heading unavailable"
    /** The words that take the readout's place with no compass (A.2). */
    const val NO_HEADING_TEXT = "No heading"
    /** The no-heading status line (A.2). */
    const val NO_COMPASS_STATUS = "Position, sun and map still work"

    /** What the layout gave up (A.6), in order. */
    enum class Step { GAPS, ROWS, DENSITY, MAP_CARD, BUTTON }

    /** The sixth tile for a speed in m/s (null: not moving). */
    fun sixth(speed: Double?): Sixth = if (speed != null && speed >= MOVING) Sixth.SPEED else Sixth.PRESSURE

    /** 8-dp steps, rounded up: ceil8(349.6) = 352. */
    fun ceil8(x: Float): Float = ceil(x / 8f - 1e-4f) * 8f

    /** The owner's rule: ceil(0.40 H), or W − 16 where the window is narrower than that. */
    fun ownerFloor(w: Float, h: Float): Float = min(ceil(OWNER_SHARE * h - 1e-3f), w - 16f)

    /** The dial's width cap: W − 32 for Small and Medium, W − 16 for Large and Extra Large. */
    fun widthCap(layout: Layout, w: Float): Float = if (layout == Layout.SMALL || layout == Layout.MEDIUM) w - 32f else w - 16f

    /** The layout's dial cap (A.3): ceil8(0.40 H) for Small and Medium, ceil8(0.42 H) for Large, the width cap for Extra Large. */
    fun cap(layout: Layout, w: Float, h: Float): Float {
        val wc = widthCap(layout, w)
        val base = when (layout) {
            Layout.SMALL, Layout.MEDIUM -> min(ceil8(OWNER_SHARE * h), wc)
            Layout.LARGE -> min(ceil8(LARGE_SHARE * h), wc)
            Layout.EXTRA_LARGE -> wc
        }
        return max(base, ownerFloor(w, h))
    }

    /** The column's width: W − 2 × margin on a phone, min(W − 48, 720) on a tablet. */
    fun columnWidth(w: Float, h: Float, isLandscapePhone: Boolean, margin: Float = MARGIN): Float {
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        return if (tablet) min(w - 2 * TABLET_INSET, MAX_COLUMN) else w - 2 * margin
    }

    /** The readout's height: the heading's 1.1 line, less the trim above the digits' cap height. */
    fun readoutHeight(headingSize: Float, k: Float) = headingSize * (READOUT_LINE - READOUT_TRIM) * k
    /** The readout's slot: with no heading, "No heading" on its 40 line when that is taller. */
    fun readoutBlock(headingSize: Float, k: Float, noHeading: Boolean) =
        if (noHeading) max(readoutHeight(headingSize, k), NO_HEADING_LINE * k) else readoutHeight(headingSize, k)
    fun statusHeight(k: Float, lines: Int) = STATUS * k * lines
    /** Dial edge → readout, the readout, readout → status and the status line. */
    fun groupHeight(headingSize: Float, k: Float, noHeading: Boolean, statusLines: Int) =
        DIAL_GAP + readoutBlock(headingSize, k, noHeading) + STATUS_GAP * k + statusHeight(k, statusLines)

    /** The location card: 56, or 14 + the place's 22 and the date's 20 lines × k; a line more for a wrapped place (bit 1) or date (bit 2). */
    fun locationHeight(k: Float, extraLines: Int = 0) =
        max(LOCATION, 14f + 42f * k) + (if (extraLines and 1 != 0) TITLE_LINE * k else 0f) + (if (extraLines and 2 != 0) DATE_LINE * k else 0f)

    /** A Targets row: [base] at text size 1, taller with the 22 line of 17 sp text. */
    fun targetRow(base: Float, k: Float) = max(base, base - 22f + 22f * k)
    fun targetRowHeight(layout: Layout, tablet: Boolean, k: Float, compact: Boolean): Float = when {
        layout == Layout.EXTRA_LARGE -> targetRow(if (compact) TARGET_ROW_XL_COMPACT else TARGET_ROW_XL, k)
        compact -> targetRow(TARGET_ROW_COMPACT, k)
        tablet -> targetRow(TARGET_ROW_TABLET, k)
        else -> targetRow(TARGET_ROW, k)
    }

    /** A tile: 10 above and below, a 13 caption line and two 19 value lines, at least 72 (96 on a tablet). */
    fun tileHeight(k: Float, tablet: Boolean = false) = if (tablet) max(TILE_TABLET, 24f + 64f * k) else max(TILE, 20f + 51f * k)
    /** Large given way: 2 × 2 tiles of 64, 6 above and below. */
    fun quadCompactHeight(k: Float) = max(QUAD_COMPACT, 12f + 51f * k)
    /** Small's band: 10 above and below, the caption, 3 and two 17 lines. */
    fun bandHeight(k: Float) = max(BAND, 23f + 47f * k)
    /** Extra Large's strip: 14 above and below, the caption, 6 and two 19 lines. */
    fun stripHeight(k: Float, tablet: Boolean = false) = max(STRIP, 34f + 51f * k) + (if (tablet) 0f else 0f)
    /**
     * The narrowest strip Position column that holds the longest longitude on one line at text size [k]. In two panes,
     * Extra Large's strip with a narrower Position column gives way to [GridMode.TWO_ROW] (as on Apple).
     */
    fun stripPositionNeed(k: Float) = POSITION_LINE * k + 2 * STRIP_INSET
    /** A row in the scrolling list: 96 at the accessibility sizes. */
    fun listTileHeight(k: Float) = max(64f, 20f + 38f * k)

    fun gridHeight(mode: GridMode, tile: Float, tile2: Float): Float = when (mode) {
        GridMode.BAND -> 0f
        GridMode.STRIP, GridMode.ROW -> tile
        GridMode.QUAD, GridMode.SIX, GridMode.QUAD_COMPACT, GridMode.TWO_ROW -> tile + ROW_GAP + tile2
        GridMode.ROWS -> 4 * tile + 3 * ROW_GAP
    }

    /** A grid's smallest row height (A.5 step 2). */
    private fun minTile(mode: GridMode, k: Float, tablet: Boolean): Float = when (mode) {
        GridMode.BAND -> bandHeight(k)
        GridMode.STRIP -> stripHeight(k, tablet)
        GridMode.QUAD_COMPACT -> quadCompactHeight(k)
        GridMode.ROWS -> listTileHeight(k)
        GridMode.QUAD, GridMode.SIX -> tileHeight(k, tablet)
        GridMode.ROW, GridMode.TWO_ROW -> tileHeight(k)
    }

    /**
     * The status line's lines when the screen hasn't measured them: two at k > 1.1, otherwise one.
     */
    fun estimateStatusLines(c: Float, k: Float, noHeading: Boolean): Int = when {
        k > 1.1f -> 2
        noHeading && NO_COMPASS_STATUS.length * 13f * k * 0.56f > c - 32f -> 2
        else -> 1
    }

    /** Two panes: the trailing pane's width, 360–560 (520 at 1200 wide; never over half), Extra Large's 40% of the panes. */
    fun trailingWidth(layout: Layout, w: Float): Float {
        val base = (PANE_SHARE * w).roundToInt().toFloat().coerceIn(PANE_MIN, PANE_MAX).coerceAtMost(w / 2)
        return if (layout == Layout.EXTRA_LARGE) min(base, ((1f - PANE_XL_LEADING) * (w - 2 * PANE_MARGIN - PANE_GAP)).roundToInt().toFloat()) else base
    }

    /**
     * [w] the window's (safe) width, [h] its full height including the system bars, [s] the safe height,
     * [k] the text multiplier (font scale), [accessibilityText] font scale 1.5 and up, [noHeading] no compass.
     * [statusLines] (0 lets the planner estimate them), [titleWraps] and [dateWraps] (the location card's place
     * or date runs to a second line) are measured by the screen. [moving] picks Large's sixth tile; [decimal] the
     * coordinate format is DD. [endGap] is where the stack ends above the safe bottom (Android 8, 16 at large text);
     * [margin] the phone column's side margin.
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
        statusLines: Int = 0,
        noHeading: Boolean = false,
        titleWraps: Boolean = false,
        dateWraps: Boolean = false,
        moving: Boolean = false,
        decimal: Boolean = true,
        endGap: Float = -1f,
        margin: Float = MARGIN,
    ): Plan {
        val kk = k.coerceIn(1f, MAX_K)
        val end = if (endGap >= 0f) endGap else if (kk >= TWO_ROW_K - 0.001f) END_LARGE_TEXT else END
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        val c = columnWidth(w, h, isLandscapePhone, margin)
        val lines = if (statusLines > 0) statusLines else estimateStatusLines(c, kk, noHeading)
        val inp = Input(w, h, s, kk, tablet, locked && !noHeading, hasSpot, hasUpdateBanner, lines, noHeading,
            (if (titleWraps) 1 else 0) + (if (dateWraps) 2 else 0), if (moving) Sixth.SPEED else Sixth.PRESSURE, decimal, end, margin)
        if (accessibilityText) return list(inp, layout, k)
        if (isLandscapePhone || (w > h && w >= TWO_PANE_WIDTH)) return twoPanes(inp, layout) ?: list(inp, layout, k)
        return column(inp, layout) ?: list(inp, layout, kk)
    }

    /** What every step of the planner needs to know. */
    private data class Input(
        val w: Float, val h: Float, val s: Float, val k: Float, val tablet: Boolean, val locked: Boolean, val spot: Boolean,
        val banner: Boolean, val statusLines: Int, val noHeading: Boolean, val locationLines: Int, val sixth: Sixth,
        val decimal: Boolean, val end: Float, val margin: Float,
    ) {
        val rows: Int get() = (if (locked) 1 else 0) + (if (spot) 1 else 0)
        val big: Boolean get() = k >= TWO_ROW_K - 0.001f
    }

    /** One grid level of A.6: the grid, the map, and the step that led to it (null: the layout's own). */
    private data class Level(val grid: GridMode, val map: MapMode, val step: Step?)

    /** A layout's grid levels in A.6's order (steps 4–6); the gaps and the Targets rows give way within each. */
    private fun levels(layout: Layout, inp: Input): List<Level> {
        val oneRow = if (inp.big) GridMode.TWO_ROW else GridMode.ROW
        return when (layout) {
            Layout.SMALL -> listOf(Level(if (inp.big) GridMode.TWO_ROW else GridMode.BAND, MapMode.CARD, null), Level(oneRow, MapMode.BUTTON, Step.BUTTON))
            Layout.MEDIUM -> if (inp.tablet) listOf(
                Level(GridMode.QUAD, MapMode.CARD, null), Level(GridMode.QUAD, MapMode.TILE, Step.MAP_CARD), Level(oneRow, MapMode.BUTTON, Step.BUTTON),
            ) else listOf(Level(GridMode.QUAD, MapMode.TILE, null), Level(oneRow, MapMode.BUTTON, Step.BUTTON))
            Layout.LARGE -> if (inp.big) listOf(Level(GridMode.QUAD_COMPACT, MapMode.BUTTON, null), Level(oneRow, MapMode.BUTTON, Step.BUTTON))
                else listOf(Level(GridMode.SIX, MapMode.BUTTON, null), Level(GridMode.QUAD_COMPACT, MapMode.BUTTON, Step.DENSITY), Level(oneRow, MapMode.BUTTON, Step.BUTTON))
            Layout.EXTRA_LARGE -> if (inp.big) listOf(Level(GridMode.TWO_ROW, MapMode.BUTTON, null))
                else listOf(Level(GridMode.STRIP, MapMode.BUTTON, null), Level(GridMode.ROW, MapMode.BUTTON, Step.BUTTON))
        }
    }

    /**
     * One column (portrait): steps 1–4. The larger layout is planned first and holds this one's dial, so the
     * dials step up. Null when nothing keeps the dial at the owner's floor: the list.
     */
    private fun column(inp: Input, layout: Layout): Plan? {
        val larger = layout.larger?.let { column(inp, it) ?: list(inp, it, inp.k) }
        return columnWith(inp, layout, larger?.dial ?: Float.MAX_VALUE)
    }

    private fun columnWith(inp: Input, layout: Layout, limit: Float): Plan? {
        val w = inp.w; val h = inp.h; val k = inp.k; val tablet = inp.tablet
        val c = columnWidth(w, h, false, inp.margin)
        val floor = ownerFloor(w, h)
        val cap = cap(layout, w, h)
        val wide = max(widthCap(layout, w), cap)
        val hold = max(limit, floor)
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val group = groupHeight(headingSize, k, inp.noHeading, inp.statusLines)
        val location = locationHeight(k, inp.locationLines)
        val banner = if (inp.banner) BANNER + TARGETS_GAP else 0f
        val avail = inp.s - inp.end
        for (level in levels(layout, inp)) {
            // Within a level: nothing given, then the gaps, then the gaps and the Targets rows (A.6 steps 2 and 3);
            // the first that keeps the floor wins, so given-up steps come back where the height allows.
            for ((gaps, compact) in listOf(false to false, true to false, true to true)) {
                if (compact && inp.rows == 0) continue
                val dialTop = if (gaps) DIAL_TOP_TIGHT else DIAL_TOP
                val cardGap = if (gaps) CARD_GAP_TIGHT else CARD_GAP
                val rowH = targetRowHeight(layout, tablet, k, compact)
                val targets = if (inp.rows > 0) TARGETS_GAP + inp.rows * rowH else 0f
                val t0 = minTile(level.grid, k, tablet)
                val gridMin = gridHeight(level.grid, t0, t0)
                val card = when {
                    level.map != MapMode.CARD -> 0f
                    level.grid == GridMode.BAND -> MAP_MIN
                    else -> MAP_GAP + MAP_MIN
                }
                val fixed = dialTop + group + cardGap + location + banner + targets + GRID_GAP + gridMin + card
                val room = avail - fixed
                if (room + 0.5f < floor) continue
                var dial = min(min(cap, hold), room)
                var spare = room - dial
                var tile = t0; var tile2 = t0
                var mapHeight = if (level.map == MapMode.CARD) MAP_MIN else 0f
                // Step 4.1: the layout's growth.
                fun grow(top: Float, both: Boolean = true) {
                    if (both) {
                        val g = min(spare, 2 * max(0f, top - tile)); tile += g / 2; tile2 += g / 2; spare -= g
                    } else {
                        val g = min(spare, max(0f, top - tile)); tile += g; spare -= g
                    }
                }
                when {
                    level.map == MapMode.CARD -> { mapHeight += spare; spare = 0f }
                    level.grid == GridMode.QUAD && !tablet -> {
                        if (inp.big) grow(TILE_MEDIUM_MAX) else {
                            val g1 = min(spare, max(0f, TILE_MEDIUM_MAX - tile)); tile += g1; spare -= g1
                            val g2 = min(spare, max(0f, TILE_MEDIUM_MAX - tile2)); tile2 += g2; spare -= g2
                            // No Targets card: row 2 on to 176, the Sun tile gaining the moon.
                            if (inp.rows == 0) { val g3 = min(spare, max(0f, TILE_MEDIUM_TALL - tile2)); tile2 += g3; spare -= g3 }
                        }
                    }
                    level.grid == GridMode.SIX && !tablet -> grow(TILE_LARGE_MAX)
                    level.grid == GridMode.STRIP -> grow(STRIP_MAX, both = false)
                    level.grid == GridMode.ROW -> grow(TILE_MEDIUM_MAX, both = false)
                }
                // Step 4.2: past 24 at the bottom, the dial grows on to its width cap (held under the larger layout's).
                var held = false
                if (spare > BOTTOM_SPARE_MAX) {
                    val more = min(spare - BOTTOM_SPARE_MAX, max(0f, min(wide, hold) - dial))
                    dial += more; spare -= more
                    if (spare > BOTTOM_SPARE_MAX + 0.5f && dial >= hold - 0.5f && hold < wide) held = true
                }
                // Step 4.3: still more than 24 (the dial at its width cap, or held under the larger layout's): the
                // tiles take it, so no empty band is wider than 24.
                if (spare > BOTTOM_SPARE_MAX && level.map != MapMode.CARD) {
                    val extra = spare - BOTTOM_SPARE_MAX
                    when (level.grid) {
                        GridMode.STRIP, GridMode.ROW -> tile += extra
                        GridMode.QUAD, GridMode.SIX, GridMode.QUAD_COMPACT, GridMode.TWO_ROW -> { tile += extra / 2; tile2 += extra / 2 }
                        else -> {}
                    }
                    spare = BOTTOM_SPARE_MAX
                }
                val given = buildSet {
                    if (gaps) add(Step.GAPS)
                    if (compact) add(Step.ROWS)
                    // Every step before this level's was taken too.
                    when (level.step) {
                        Step.DENSITY -> add(Step.DENSITY)
                        Step.MAP_CARD -> add(Step.MAP_CARD)
                        Step.BUTTON -> { if (layout == Layout.LARGE && !inp.big) add(Step.DENSITY); if (tablet && layout == Layout.MEDIUM) add(Step.MAP_CARD); add(Step.BUTTON) }
                        else -> {}
                    }
                }
                val used = dialTop + dial + group + cardGap + location + banner + targets + GRID_GAP +
                    gridHeight(level.grid, tile, tile2) + (if (level.map == MapMode.CARD) mapHeight + (if (level.grid == GridMode.BAND) 0f else MAP_GAP) else 0f) +
                    spare + inp.end
                return Plan(
                    layout = layout, twoPane = false, list = false, tablet = tablet, k = k, dial = dial, floor = floor, cap = cap,
                    widthCap = wide, headingSize = headingSize, dialTop = dialTop, cardGap = cardGap, location = location,
                    statusLines = inp.statusLines, targetsRows = inp.rows, targetsRowHeight = rowH, margin = inp.margin, column = c,
                    grid = level.grid, map = level.map, tile = tile, tile2 = tile2, mapHeight = mapHeight, sixth = inp.sixth,
                    decimal = inp.decimal, bottomSpare = spare, endGap = inp.end, trailingWidth = 0f, locked = inp.locked,
                    hasSpot = inp.spot, used = used, noHeading = inp.noHeading, given = given, held = held, banner = inp.banner,
                )
            }
        }
        return null
    }

    /**
     * The scrolling list (A.7): the dial (still at least 0.40 H), readout, status, the location card (wrapping),
     * Targets rows of 84 with the cue on line 2, one 96 row per tile (Position, Elevation, Sun, Moon), then a 176
     * Map tile. A 24 fade at the bottom says there is more.
     */
    private fun list(inp: Input, layout: Layout, k: Float): Plan {
        val kl = k.coerceIn(1f, 2f)
        val w = inp.w; val h = inp.h
        val c = columnWidth(w, h, false, inp.margin)
        val floor = ownerFloor(w, h)
        val dial = max(floor, min(ceil8(OWNER_SHARE * h), w - 32f))
        val headingSize = (if (inp.tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val row = listTileHeight(kl)
        return Plan(
            layout = layout, twoPane = false, list = true, tablet = inp.tablet, k = kl, dial = dial, floor = floor, cap = dial,
            widthCap = dial, headingSize = headingSize, dialTop = DIAL_TOP, cardGap = CARD_GAP, location = locationHeight(kl, 1),
            statusLines = 2, targetsRows = inp.rows, targetsRowHeight = targetRow(TARGET_ROW_LIST, kl), margin = inp.margin,
            column = c, grid = GridMode.ROWS, map = MapMode.TILE, tile = row, tile2 = row, mapHeight = LIST_MAP, sixth = inp.sixth,
            decimal = inp.decimal, bottomSpare = 0f, endGap = inp.end, trailingWidth = 0f, locked = inp.locked, hasSpot = inp.spot,
            used = inp.s, noHeading = inp.noHeading, banner = inp.banner,
        )
    }

    /**
     * Two panes (A.8): no full-width header. Left: the dial, readout and status, top-aligned at safe top + 18, the
     * dial min(pane − 48, the height under it, share × H). Right, top-aligned with the dial: the location card, 8,
     * the Targets card, 8, the grid (Medium Position | Elevation, Sun | Moon; Large six; Extra Large the strip;
     * Small none), 8 and a map card to the bottom (240 or more; Small 60% of the pane). Short of height the map
     * card gives way: compact Targets rows, a card of 140, then the map tile (Medium) or the card's map button.
     * Null when not even a 140 dial fits: the list.
     */
    private fun twoPanes(inp: Input, layout: Layout): Plan? {
        val k = inp.k; val w = inp.w; val h = inp.h; val tablet = inp.tablet
        val trailing = trailingWidth(layout, w)
        val pane = w - 2 * PANE_MARGIN - PANE_GAP - trailing
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val group = groupHeight(headingSize, k, inp.noHeading, inp.statusLines)
        val avail = inp.s - inp.end - DIAL_TOP
        if (avail - group < DIAL_MIN) return null
        val dial = min(min(pane - 48f, avail - group), max(DIAL_MIN, layout.paneShare * h))
        val location = locationHeight(k, inp.locationLines)
        val banner = if (inp.banner) BANNER + TARGETS_GAP else 0f
        // Extra Large in a narrow trailing pane: the strip's Position column is too narrow for a longitude, so the pane
        // takes two rows instead (Position full width, then Elevation | Sun) at the full tile height.
        val narrowStrip = layout == Layout.EXTRA_LARGE && !inp.big &&
            rows(GridMode.STRIP, MapMode.CARD, trailing)[0].widths[0] < stripPositionNeed(k) - 0.5f
        val own = when (layout) {
            Layout.SMALL -> if (inp.big) GridMode.TWO_ROW else GridMode.BAND
            Layout.MEDIUM -> GridMode.QUAD
            Layout.LARGE -> if (inp.big) GridMode.QUAD_COMPACT else GridMode.SIX
            Layout.EXTRA_LARGE -> if (inp.big || narrowStrip) GridMode.TWO_ROW else GridMode.STRIP
        }
        fun rowMin(g: GridMode) = if (narrowStrip && g == GridMode.TWO_ROW) tileHeight(k, tablet) else minTile(g, k, tablet)
        val t0 = rowMin(own)
        val gridH = gridHeight(own, t0, t0)
        val cardMin = if (layout == Layout.SMALL) max(PANE_MAP, PANE_SMALL_SHARE * avail) else PANE_MAP
        fun content(rowH: Float, grid: GridMode, g: Float, card: Float) =
            location + banner + (if (inp.rows > 0) TARGETS_GAP + inp.rows * rowH else 0f) +
                (if (grid == GridMode.BAND) 0f else GRID_GAP + g) + (if (card > 0f) (if (grid == GridMode.BAND) GRID_GAP else MAP_GAP) + card else 0f)
        var grid = own; var map = MapMode.CARD; var mapHeight = 0f; var compact = false
        var rowH = targetRowHeight(layout, tablet, k, false)
        val given = mutableSetOf<Step>()
        val full = avail - content(rowH, grid, gridH, 0f) - (if (grid == GridMode.BAND) GRID_GAP else MAP_GAP)
        if (full >= cardMin - 0.5f) mapHeight = full else {
            compact = inp.rows > 0
            if (compact) { rowH = targetRowHeight(layout, tablet, k, true); given += Step.ROWS }
            val left = avail - content(rowH, grid, gridH, 0f) - (if (grid == GridMode.BAND) GRID_GAP else MAP_GAP)
            if (left >= MAP_MIN - 0.5f) mapHeight = left else {
                given += Step.BUTTON
                when (layout) {
                    Layout.MEDIUM -> map = MapMode.TILE
                    Layout.SMALL -> { map = MapMode.BUTTON; grid = if (inp.big) GridMode.TWO_ROW else GridMode.ROW }
                    else -> map = MapMode.BUTTON
                }
            }
        }
        var t = rowMin(grid)
        var t2 = t
        if (map != MapMode.CARD && location + GRID_GAP + gridHeight(grid, t, t) > avail + 0.5f) return null
        if (map != MapMode.CARD) {
            // No card: the tiles take the pane's spare (Medium's Map tile grows with it), all but 24.
            val spare = avail - content(rowH, grid, gridHeight(grid, t, t), 0f) - BOTTOM_SPARE_MAX
            if (spare > 0f) when (grid) {
                GridMode.STRIP, GridMode.ROW -> t += spare
                GridMode.QUAD, GridMode.SIX, GridMode.QUAD_COMPACT, GridMode.TWO_ROW -> { t += spare / 2; t2 += spare / 2 }
                else -> {}
            }
        }
        val used = content(rowH, grid, gridHeight(grid, t, t2), if (map == MapMode.CARD) mapHeight else 0f)
        // Too tall for the pane even without a card: the list.
        if (used > avail + 0.5f) return null
        return Plan(
            layout = layout, twoPane = true, list = false, tablet = tablet, k = k, dial = dial, floor = DIAL_MIN, cap = dial,
            widthCap = dial, headingSize = headingSize, dialTop = DIAL_TOP, cardGap = CARD_GAP, location = location,
            statusLines = inp.statusLines, targetsRows = inp.rows, targetsRowHeight = rowH, margin = PANE_MARGIN, column = trailing,
            grid = grid, map = map, tile = t, tile2 = t2, mapHeight = mapHeight, sixth = inp.sixth, decimal = inp.decimal,
            bottomSpare = max(0f, avail - used), endGap = inp.end, trailingWidth = trailing, locked = inp.locked, hasSpot = inp.spot,
            used = inp.s, noHeading = inp.noHeading, given = given, banner = inp.banner,
        )
    }

    /** "Locked 240°" shortens to "240°" only in a column under 320 (A.2). */
    fun shortLock(column: Float): Boolean = column < SHORT_LOCK_COLUMN

    /**
     * The compact row's widths (A.6 step 6): Position = C − 2·8 − 2w | Elevation = w | Sun = w, with
     * w = max(104, round(0.27 C)): 146 | 104 | 104 at C = 370, 306 | 189 | 189 at 700.
     */
    fun compactWidths(c: Float): List<Float> {
        val w = max(COMPACT_MIN, (COMPACT_SHARE * c).roundToInt().toFloat())
        return listOf(c - 2 * ROW_GAP - 2 * w, w, w)
    }

    /** [total] split by [weights], every width but the last rounded to whole dp, the last taking the rest. */
    fun split(total: Float, weights: List<Float>): List<Float> {
        val sum = weights.sum()
        val out = weights.dropLast(1).map { (total * it / sum).roundToInt().toFloat() }
        return out + (total - out.sum())
    }

    /**
     * The grid's rows at column width [c] (A.3): band (12 insets, 8 gaps, 1.2 | 1 | 1), quad (C − 8) / 2, six
     * (C − 16) / 3 (Latitude and Longitude only for DD; otherwise one Position tile 2u + 8), strip (1 dp dividers,
     * 1.25 | 1 | 1), the compact row, two rows and the list.
     */
    fun rows(mode: GridMode, map: MapMode, c: Float, sixth: Sixth = Sixth.PRESSURE, decimal: Boolean = true): List<TileRowPlan> {
        val half = ((c - ROW_GAP) / 2).roundToInt().toFloat()
        val halves = listOf(half, c - ROW_GAP - half)
        val u = ((c - 2 * ROW_GAP) / 3).roundToInt().toFloat()
        val thirds = listOf(u, u, c - 2 * ROW_GAP - 2 * u)
        val last = if (sixth == Sixth.SPEED) TileKind.SPEED else TileKind.PRESSURE
        return when (mode) {
            GridMode.BAND -> listOf(TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN),
                split(c - 24f - 2 * ROW_GAP, listOf(1.2f, 1f, 1f)), ROW_GAP, 12f))
            GridMode.QUAD -> listOf(
                TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION), halves),
                TileRowPlan(listOf(TileKind.SUN, if (map == MapMode.TILE) TileKind.MAP else TileKind.MOON), halves),
            )
            GridMode.SIX -> listOf(
                if (decimal) TileRowPlan(listOf(TileKind.LATITUDE, TileKind.LONGITUDE, TileKind.ELEVATION), thirds)
                else TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION), listOf(2 * u + ROW_GAP, c - 2 * ROW_GAP - 2 * u)),
                TileRowPlan(listOf(TileKind.SUN, TileKind.MOON, last), thirds),
            )
            GridMode.STRIP -> listOf(TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN), split(c - 2f, listOf(1.25f, 1f, 1f)), 1f))
            GridMode.QUAD_COMPACT -> listOf(
                TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION), halves),
                TileRowPlan(listOf(TileKind.SUN, last), halves),
            )
            GridMode.ROW -> listOf(TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN), compactWidths(c)))
            GridMode.TWO_ROW -> listOf(
                TileRowPlan(listOf(TileKind.POSITION), listOf(c)),
                TileRowPlan(listOf(TileKind.ELEVATION, TileKind.SUN), halves),
            )
            GridMode.ROWS -> listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN, TileKind.MOON).map { TileRowPlan(listOf(it), listOf(c)) }
        }
    }

    /**
     * A device in the planner's table: width, full height, the safe insets at the top and bottom, and whether it
     * is an Android screen (the stack ends 8 above the navigation bar, 16 at large text) or a Mac window (24 margins,
     * a 28 title-bar band). Elsewhere the stack ends at a home indicator's inset, or 16 above the edge without one.
     */
    data class Device(val name: String, val w: Float, val h: Float, val top: Float, val bottom: Float,
                      val android: Boolean = false, val mac: Boolean = false) {
        val s: Float get() = h - top - bottom
        fun endGap(k: Float): Float = when {
            android -> if (k >= TWO_ROW_K - 0.001f) END_LARGE_TEXT else END
            mac -> 24f
            bottom > 0f -> 0f
            else -> 16f
        }
        val margin: Float get() = if (mac) MARGIN_MAC else MARGIN
    }

    /** The devices the self-test runs the planner on. */
    val devices = listOf(
        Device("iPhone SE", 375f, 667f, 20f, 0f),
        Device("iPhone 16", 393f, 852f, 59f, 34f),
        Device("iPhone 16 Pro", 402f, 874f, 62f, 34f),
        Device("iPhone 17 Pro Max", 440f, 956f, 62f, 34f),
        Device("Pixel 7", 412f, 915f, 24f, 24f, android = true),
        Device("Android 412x914", 412f, 914f, 24f, 48f, android = true),
        Device("Small Android", 360f, 640f, 24f, 48f, android = true),
        Device("Android tablet", 800f, 1280f, 24f, 48f, android = true),
        Device("iPad mini portrait", 744f, 1133f, 24f, 20f),
        Device("iPad 11 portrait", 834f, 1210f, 24f, 20f),
        Device("iPad 13 portrait", 1032f, 1376f, 24f, 20f),
        Device("iPad 11 landscape", 1210f, 834f, 24f, 20f),
        Device("iPad 13 landscape", 1376f, 1032f, 24f, 20f),
        Device("Android tablet landscape", 1280f, 800f, 24f, 48f, android = true),
        Device("Mac 380x720", 380f, 720f, 28f, 0f, mac = true),
        Device("Mac 420x840", 420f, 840f, 28f, 0f, mac = true),
        Device("Mac 1200x800", 1200f, 800f, 28f, 0f, mac = true),
        Device("Phone landscape", 915f, 412f, 24f, 0f, android = true),
    )

    /** The golden table's states: sample (locked and marked), live (neither), no compass (marked), and the halves. */
    enum class State(val id: String, val locked: Boolean, val spot: Boolean, val noHeading: Boolean) {
        SAMPLE("sample", true, true, false),
        LIVE("live", false, false, false),
        NO_COMPASS("no compass", false, true, true),
        LOCKED("locked", true, false, false),
        MARKED("marked", false, true, false),
    }

    /** The golden devices (A.4): the four layouts are told apart by grid and map surface. */
    val goldenDevices = setOf("iPhone 16", "iPhone 16 Pro", "Pixel 7")

    /** Where neighbouring layouts must still differ in grid, map surface or dial (A.4). */
    private val distinctDevices = setOf("iPhone 16", "iPhone 16 Pro", "iPhone 17 Pro Max", "Pixel 7", "Android 412x914",
        "iPad mini portrait", "iPad 11 portrait", "iPad 13 portrait", "Android tablet", "Mac 420x840", "Mac 1200x800",
        "iPad 11 landscape", "iPad 13 landscape", "Android tablet landscape")

    /** The plan for [d]; font scale 1.5 and up is the scrolling list, as on the phone. */
    fun planFor(d: Device, layout: Layout, k: Float = 1f, state: State = State.SAMPLE, moving: Boolean = false): Plan {
        val landscape = d.w > d.h && d.s < LANDSCAPE_PHONE
        return plan(d.w, d.h, d.s, layout, k, k >= 1.5f, state.locked, state.spot, false, landscape, noHeading = state.noHeading,
            moving = moving, endGap = d.endGap(k), margin = d.margin)
    }

    /** The frozen tokens a plan may use (A.1). */
    private fun tokensOk(p: Plan): Boolean =
        (p.dialTop == DIAL_TOP || (p.dialTop == DIAL_TOP_TIGHT && Step.GAPS in p.given)) &&
            (p.cardGap == CARD_GAP || (p.cardGap == CARD_GAP_TIGHT && Step.GAPS in p.given)) &&
            p.dialGap == DIAL_GAP && abs(p.statusGap - STATUS_GAP * p.k) < 0.01f && p.targetsGap == TARGETS_GAP &&
            p.gridGap == GRID_GAP && p.rowGap == ROW_GAP

    /**
     * Runs the golden table (devices × layouts × states × text sizes) and returns the cases that break a rule
     * (A.11): every row's widths, gaps and insets add up to the column; the gaps are A.1's tokens; the dial's top is
     * safe top + 18 (12 given way) and nothing sits above it; the location card is the status line's bottom + 12 (8);
     * the Targets card has a row for each of the lock and the spot, the lock first, at 48 / 40 / 56 / 64 / 48; the
     * content fills the safe height with at most 24 left at the bottom; in one portrait column the dial is at least
     * 0.40 H (every layout, state and text size, the list too); map cards are 140 or more; at k ≥ 1.3 no
     * three-column compact row and rows of equal height; Large's sixth tile is Pressure or Speed; in the sample
     * state on the golden devices the four layouts are band / quad / six / strip with card / tile / button / button
     * and dials that step up; elsewhere neighbours still differ. Empty when all is well.
     */
    fun tableFailures(): List<String> {
        val failures = mutableListOf<String>()
        for (d in devices) for (layout in Layout.entries) for (state in State.entries) for (k in listOf(1f, 1.15f, 1.3f, 1.5f, 2f)) {
            val p = planFor(d, layout, k, state)
            val name = "${d.name} ${layout.id} k$k ${state.id}"
            val portrait = d.w < d.h
            // The owner's rule: one portrait column, every layout, state and text size, the list included.
            if (portrait && !p.twoPane && p.dial + 0.5f < ownerFloor(d.w, d.h)) {
                failures += "$name: dial ${p.dial} is ${"%.1f".format(java.util.Locale.US, 100 * p.dial / d.h)}% of H, under ${ownerFloor(d.w, d.h)}"
            }
            for (row in p.rows) {
                if (abs(row.total - p.column) > 0.01f) failures += "$name: row ${row.tiles} is ${row.total} wide in a ${p.column} column"
                if (row.widths.any { it < 80f }) failures += "$name: a tile in ${row.tiles} is under 80 wide (${row.widths})"
            }
            if (!tokensOk(p)) failures += "$name: gaps ${p.dialTop} / ${p.cardGap} are not A.1's tokens"
            val wantRows = (if (state.locked && !state.noHeading) 1 else 0) + (if (state.spot) 1 else 0)
            if (p.targetsRows != wantRows) failures += "$name: ${p.targetsRows} Targets rows for $wantRows"
            if (p.targetsRows > 0) {
                val base = listOf(TARGET_ROW, TARGET_ROW_COMPACT, TARGET_ROW_TABLET, TARGET_ROW_XL, TARGET_ROW_XL_COMPACT, TARGET_ROW_LIST)
                if (base.none { abs(targetRow(it, if (p.list) p.k else min(p.k, MAX_K)) - p.targetsRowHeight) < 0.01f &&
                        (!p.list || it == TARGET_ROW_LIST) }) failures += "$name: Targets row ${p.targetsRowHeight}"
            }
            if (p.map == MapMode.CARD && p.mapHeight + 0.5f < MAP_MIN) failures += "$name: map card ${p.mapHeight}"
            if (p.k >= TWO_ROW_K - 0.001f && !p.list) {
                if (p.grid in setOf(GridMode.BAND, GridMode.SIX, GridMode.STRIP, GridMode.ROW)) failures += "$name: a three-column compact row (${p.grid}) at large text"
                if (p.gridHeight > 0f && p.grid != GridMode.STRIP && p.grid != GridMode.ROW && abs(p.tile - p.tile2) > 0.01f) failures += "$name: rows of ${p.tile} and ${p.tile2}"
            }
            if (p.list) continue
            if (!p.twoPane) {
                if (layout == Layout.EXTRA_LARGE && p.map != MapMode.BUTTON) failures += "$name: Extra Large's map is not the card's button"
                if (p.dialTop + 0.01f < DIAL_TOP_TIGHT) failures += "$name: something above the dial"
                if (abs(p.locationTop - (p.statusTop + p.status + p.cardGap)) > 0.01f) failures += "$name: the location card is not under the status line"
                if (p.bottomSpare > BOTTOM_SPARE_MAX + 0.5f && !p.held) failures += "$name: ${p.bottomSpare} empty at the bottom"
                if (abs(p.used - d.s) > 0.5f) failures += "$name: planned ${p.used} for a safe height of ${d.s}"
                val end = if (p.map == MapMode.CARD) p.mapTop + p.mapHeight else 0f
                val gridEnd = p.gridTop + p.gridHeight
                if (max(end, gridEnd) > d.s - p.endGap + 0.5f) failures += "$name: the last block ends at ${max(end, gridEnd)}, past ${d.s - p.endGap}"
                if (p.dial > d.w - 16f + 0.5f) failures += "$name: dial ${p.dial} closer than 8 to the edge"
            } else {
                // The trailing pane: the location card, Targets, grid and map card fit the pane.
                val avail = d.s - p.endGap - p.dialTop
                val content = p.location + p.bannerHeight + (if (p.targetsRows > 0) p.targetsGap + p.targets else 0f) +
                    (if (p.grid == GridMode.BAND) 0f else p.gridGap + p.gridHeight) +
                    (if (p.map == MapMode.CARD) p.mapGap + p.mapHeight else 0f)
                if (content > avail + 0.5f) failures += "$name: trailing pane $content taller than $avail"
                if (p.map == MapMode.CARD && p.bottomSpare > BOTTOM_SPARE_MAX + 0.5f) failures += "$name: ${p.bottomSpare} empty under the map card"
                if (p.map == MapMode.TILE && p.rows.none { TileKind.MAP in it.tiles }) failures += "$name: the Map tile has no cell"
            }
        }
        // A.4: the golden devices, sample state: band / quad / six / strip, card / tile / button / button, dials step up.
        for (d in devices.filter { it.name in goldenDevices }) {
            val plans = Layout.entries.map { planFor(d, it, 1f, State.SAMPLE) }
            val line = plans.joinToString { it.layout.id + " " + it.resultLine }
            if (plans.map { it.grid } != listOf(GridMode.BAND, GridMode.QUAD, GridMode.SIX, GridMode.STRIP)) failures += "${d.name}: grids ($line)"
            if (plans.map { it.map } != listOf(MapMode.CARD, MapMode.TILE, MapMode.BUTTON, MapMode.BUTTON)) failures += "${d.name}: maps ($line)"
            if (plans.any { it.bottomSpare > BOTTOM_SPARE_MAX + 0.5f }) failures += "${d.name}: an empty band over 24 ($line)"
        }
        // Neighbouring layouts differ in grid, map surface or dial, portrait and landscape, every state, text size 1.0.
        for (d in devices.filter { it.name in distinctDevices }) for (state in State.entries) {
            val plans = Layout.entries.map { planFor(d, it, 1f, state) }
            for ((a, b) in plans.zipWithNext()) {
                if (a.grid == b.grid && a.map == b.map && abs(a.dial - b.dial) < 8f) failures += "${d.name} ${state.id}: ${b.layout.id} is ${a.layout.id} (${b.resultLine})"
            }
        }
        // The dials step up, Small ≤ Medium ≤ Large ≤ Extra Large, in every portrait column at text sizes up to 1.3.
        for (d in devices.filter { it.w < it.h }) for (state in State.entries) for (k in listOf(1f, 1.15f, 1.3f)) {
            val plans = Layout.entries.map { planFor(d, it, k, state) }
            for ((a, b) in plans.zipWithNext()) if (a.dial > b.dial + 0.5f) {
                failures += "${d.name} ${state.id} k$k: ${a.layout.id}'s dial ${a.dial} over ${b.layout.id}'s ${b.dial}"
            }
        }
        // Large's sixth tile: Pressure when still (or no speed), Speed from 0.5 m/s.
        if (sixth(null) != Sixth.PRESSURE || sixth(0.49) != Sixth.PRESSURE || sixth(0.5) != Sixth.SPEED) failures += "Large's sixth tile"
        val pixel = devices.first { it.name == "Pixel 7" }
        val moving = planFor(pixel, Layout.LARGE, moving = true)
        if (moving.rows.last().tiles.last() != TileKind.SPEED || planFor(pixel, Layout.LARGE).rows.last().tiles.last() != TileKind.PRESSURE) failures += "Large's sixth tile on Pixel 7"
        // The worked numbers: Medium on the Pixel 7, sample: dial ceil8(0.40 H) = 368, 2 × 2 with the Map tile, tiles 88.
        val pm = planFor(pixel, Layout.MEDIUM)
        if (pm.grid != GridMode.QUAD || pm.map != MapMode.TILE || abs(pm.dial - 368f) > 0.5f || abs(pm.tile - 88f) > 0.5f) failures += "Medium on Pixel 7: ${pm.resultLine}, tiles ${pm.tile}"
        val compact = compactWidths(370f)
        if (compact != listOf(146f, 104f, 104f) || compactWidths(700f) != listOf(306f, 189f, 189f)) failures += "Compact widths: $compact"
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
        val i = t.indexOfLast { it == ' ' || it == '\u202F' || it == '\u00A0' }
        if (i <= 0) return t to null
        val tail = t.substring(i + 1)
        return if (tail.isNotEmpty() && tail.none { it.isDigit() }) t.substring(0, i).trimEnd() to tail else t to null
    }

    /**
     * The one size for lines that share a block (C3.4 #12): the smallest of each line's own fitting scale, so
     * the longer line decides and both Position lines are drawn at the same size.
     */
    fun sharedScale(lines: List<String>, scaleFor: (String) -> Float): Float = lines.minOfOrNull(scaleFor) ?: 1f

    /** A clock time that never breaks: a narrow no-break space before AM or PM ("6:36 AM" → "6:36\u202FAM"). */
    fun time(t: String): String = t.replace(' ', '\u202F').replace('\u00A0', '\u202F')

    /** "↑ 6:36 AM" with a no-break space after the arrow and the [time] rule inside. */
    fun sunLine(arrow: String, t: String): String = "$arrow\u00A0${time(t)}"

    /** "Locked 240°" → "240°", for a column under 320 (A.2). */
    fun shortLock(lead: String): String = lead.substringAfterLast('\u00A0').substringAfterLast(' ')

    /** "39.09898° N" → ("39.09898°", "North"): Large's Latitude and Longitude tiles. */
    fun hemisphere(s: String): Pair<String, String?> {
        val words = mapOf('N' to "North", 'S' to "South", 'E' to "East", 'W' to "West")
        val t = s.trim()
        val last = t.lastOrNull()
        return if (t.length > 2 && last != null && last in words && (t[t.length - 2] == ' ' || t[t.length - 2] == '\u00A0'))
            t.dropLast(2).trimEnd() to words.getValue(last) else t to null
    }

    /** "Locked 240° · turn 12° right" → ("Locked 240°", "turn 12° right"), with no-break spaces inside each (A.2). */
    fun lockParts(text: String): Pair<String, String?> {
        val i = text.indexOf(" · ")
        val nb = { s: String -> s.replace(' ', '\u00A0') }
        return if (i < 0) nb(text) to null else nb(text.substring(0, i)) to nb(text.substring(i + 3))
    }
}
