package com.bradcowdrey.bearings.ui

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The four layouts (docs/REFINE.md C3.3): the map surface shrinks as the compass grows, one step per layout,
 * and every step changes the grid.
 *
 * | | Small | Medium | Large | Extra Large |
 * |---|---|---|---|---|
 * | Grid | compact row | 3 columns, 2 rows (Position 2u, Elevation; Sun, Moon, Map) | 2 × 2 | compact row |
 * | Tiles | 72 | 72, grows to 88 (96 tablet) from spare only | fixed 72 | 72 |
 * | Map | card ≥ 140, takes all spare | tile; a card (≥ 200, from the dial down to its floor) when ≥ 160 × k is spare | header button | header button |
 * | Dial cap | the floor | C − 32 (tablet min(C − 32, 0.48 H)) | C − 16 (tablet min(C − 16, 0.54 H)), ≥ floor + 16 | C − 16 (tablet min(C − 16, 0.64 H), the column widens to the dial) |
 * | Readout | 1.0 | 1.0 | 1.0 | 1.25 |
 *
 * The floor is the owner's rule, "the compass takes up at least 40% of the screen": in one portrait column, at
 * text sizes up to 1.3, every layout's dial is at least min(0.40 H, C − 16) ([LayoutPlan.ownerFloor]); no cap
 * is under it. Short of height, a layout gives up, in order, tile growth, spare gaps, then ([LayoutPlan.Rung])
 * Small's card (a map tile, then the header's button) and Medium's and Large's grids (the compact row), then the
 * separate lock and spot rows (one 44 row), and only then becomes the scrolling list, whose dial keeps the floor
 * too. Accessibility sizes and two panes are exempt. [paneShare] is the trailing pane's share of the width in two panes.
 * Saved under "layout" as [id]; anything else reads as Medium. [subtitle] is the layout menu's line.
 */
enum class Layout(
    val id: String, val title: String, val subtitle: String, val readoutScale: Float,
    val paneShare: Float,
) {
    SMALL("small", "Small", "Compass + big map", 1.00f, 0.48f),
    MEDIUM("medium", "Medium", "Balanced · map tile", 1.00f, 0.42f),
    LARGE("large", "Large", "Bigger compass · map in header", 1.00f, 0.42f),
    EXTRA_LARGE("extraLarge", "Extra Large", "Biggest compass · one row", 1.25f, 0.40f);

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
 * How the tiles are laid out: [FULL] 3 columns in 2 rows (Medium), [QUAD] 2 × 2 at (C − 8) / 2 (Large), [COMPACT]
 * the one row (Small, Extra Large), [ROWS] one full-width row each (the scrolling list).
 */
enum class GridMode { FULL, QUAD, COMPACT, ROWS }

/** Where the map is: a grid tile, a full-width card, or only the header's map button (all open the map sheet). */
enum class MapMode { TILE, CARD, BUTTON }

/** The tiles, in the order a row lists them. */
enum class TileKind { POSITION, ELEVATION, SUN, MOON, MAP }

/** One row of the grid: the tiles and their widths in dp (8 apart; the widths and gaps add up to the column). */
data class TileRowPlan(val tiles: List<TileKind>, val widths: List<Float>)

/**
 * The planner's answer. Every length is in dp. The screen reads the dial, the grid, the map, the tile height
 * and every gap from here and nowhere else (C3.3).
 */
data class Plan(
    val layout: Layout,
    val twoPane: Boolean,
    /** Accessibility text, or nothing fits even at the floor: the whole screen is one scrolling list (§3.6). */
    val list: Boolean,
    val tablet: Boolean,
    /** The text multiplier the gaps and heights use (1 to 1.3; up to 2 in the list). */
    val k: Float,
    val dial: Float,
    val floor: Float,
    /** The dial's cap for this layout (step 3); the dial passes it only in step 5 (see [LayoutPlan]). */
    val cap: Float,
    /** The heading number's size before the text multiplier: 56 (64 on a tablet) × the readout scale. */
    val headingSize: Float,
    /** The header bar's planned height (one more line for a wrapped place name or date). */
    val header: Float,
    /** Side margin of the header, readout and tiles: 16 (20 on a tablet). */
    val margin: Float,
    /** The tile column's width: min(W − 2 × margin, 640), the dial's width for Extra Large on a tablet, or the trailing pane's width. */
    val column: Float,
    val grid: GridMode,
    val gridColumns: Int,
    val map: MapMode,
    /** The map card's height (0 unless [map] is CARD, or Small's map tile: [mapStrip]). */
    val mapHeight: Float,
    /** A tile's height: 72 (more at a larger font size), Medium's grown 88 (96 on a tablet), 80 in two panes. */
    val tile: Float,
    /** The most a tile may be: 88 (96 on a tablet), or the text's own need when that is more. */
    val tileCap: Float,
    /** Lines of the status line (1, or 2 when it wraps). */
    val statusLines: Int,
    /** Step 4's share of spare height added to header → dial (at most 24; more only when [centred]). */
    val topExtra: Float,
    /** Step 4's share of spare height left at the bottom, over the bottom inset (at most 24 unless [centred]). */
    val bottomSpare: Float,
    /**
     * Nothing could take the rest of the height: the dial is at its widest (8 dp from each edge), the layout has
     * no card and its tiles are fixed. The stack is then centred under the pinned header (header → dial and the
     * bottom share it evenly).
     */
    val centred: Boolean,
    /** Two panes: the trailing pane's width (0 in a single column). */
    val trailingWidth: Float,
    /** Two panes: the dial group's offset from the top of the content (centred in the leading pane). */
    val leadingTop: Float,
    /** Two panes: the trailing pane's content offset from the top (0 with a map card, otherwise centred). */
    val trailingTop: Float,
    val locked: Boolean,
    val hasSpot: Boolean,
    /** The content's planned height (single column); the safe height unless [list]. */
    val used: Float,
    /** No compass (§4.2, C3.2 #3): the readout is a drawn dash and "°", the status line says why. */
    val noHeading: Boolean,
    /** The lock row's cue, and the spot row's distance, under the label (they don't fit side by side; C3.4 #7). */
    val lockTwoLines: Boolean = false,
    val spotTwoLines: Boolean = false,
    /**
     * What the layout gave up to keep the dial at the owner's floor (0.40 H): nothing, its card or grid (the
     * compact row, the map in the header), or also the lock and spot rows, merged into one 44 row.
     */
    val rung: LayoutPlan.Rung = LayoutPlan.Rung.OWN,
) {
    /** The lock and the spot share one 44 row under the status line ([LayoutPlan.Rung.MERGED]). */
    val mergedRows: Boolean get() = rung == LayoutPlan.Rung.MERGED
    val mergedHeight: Float get() = LayoutPlan.mergedHeight(k)
    /** The header shows the map button: the map is neither a tile nor a card. */
    val mapButton: Boolean get() = map == MapMode.BUTTON
    /**
     * Small under pressure: its card shrank to a map tile, a strip [mapHeight] high (a tile or more, under 140)
     * as wide as the column, under the compact row.
     */
    val mapStrip: Boolean get() = map == MapMode.TILE && grid == GridMode.COMPACT
    val readoutScale: Float get() = layout.readoutScale

    // The frozen gaps (C3.2 #1): tokens × k, never widened.
    val headerGap: Float get() = LayoutPlan.HEADER_GAP * k + topExtra
    val dialGap: Float get() = LayoutPlan.DIAL_GAP * k
    val statusGap: Float get() = LayoutPlan.STATUS_GAP * k
    val lockGap: Float get() = LayoutPlan.LOCK_GAP * k
    val spotGap: Float get() = LayoutPlan.SPOT_GAP * k
    val gridGap: Float get() = LayoutPlan.GRID_GAP * k
    val rowGap: Float get() = LayoutPlan.ROW_GAP * k
    val mapGap: Float get() = LayoutPlan.MAP_GAP * k
    /** The bottom inset (16, 24 on a tablet) and what step 4 left there. */
    val bottom: Float get() = (if (tablet) LayoutPlan.BOTTOM_TABLET else LayoutPlan.BOTTOM) + bottomSpare
    val lockHeight: Float get() = LayoutPlan.lockHeight(k, lockTwoLines)
    val spotHeight: Float get() = LayoutPlan.spotHeight(k, spotTwoLines)

    /** The grid's rows, with widths that add up (with the 8 dp gaps) to [column]. */
    val rows: List<TileRowPlan> get() = LayoutPlan.rows(grid, gridColumns, map, column)

    /** For the self-test's report: "dial 338 · 3 columns · map tile". */
    val resultLine: String
        get() {
            val where = when {
                list -> "scrolls"
                map == MapMode.BUTTON -> "map in header"
                map == MapMode.CARD -> "map card ${mapHeight.roundToInt()}"
                mapStrip -> "map tile ${mapHeight.roundToInt()}"
                else -> "map tile"
            }
            val g = when (grid) { GridMode.FULL -> "3 columns"; GridMode.QUAD -> "2 × 2"; GridMode.COMPACT -> "one row"; GridMode.ROWS -> "list" }
            return "dial ${dial.roundToInt()} · $g · $where"
        }
}

/**
 * The layout planner (docs/REFINE.md C3.3), one pure function with no UI code and the same constants and steps
 * as LayoutPlan.swift:
 * 1. The header is pinned at the safe top + 8.
 * 2. The fixed blocks are placed with the frozen gap tokens × k: header → dial 12, dial → readout 12, readout →
 *    status 6, status → lock 8, lock → spot 8, readout group (or spot) → grid 8, rows 8, grid → map card 12,
 *    bottom 16 (24 on a tablet).
 * 3. Dial = min(cap, what is left), never under the owner's floor min(0.40 H, C − 16): short of it, the layout
 *    takes the next [Rung] (gives up its card or grid, then merges the lock and spot rows), and past the last, the list.
 * 4. Spare height goes, in order, to the dial (up to its cap), the map card (Small and Medium), tile growth
 *    (Medium, 72 → 88, 96 on a tablet), then header → dial and the bottom, at most 24 each.
 * 5. Where a screen is taller than a layout's content even then (a 20:9 phone with no lock row), the map tile
 *    becomes a card (Medium), and Large's and Extra Large's dial goes on growing past its cap up to 8 dp from each
 *    edge; whatever is still left centres the stack under the pinned header ([Plan.centred]). Gaps never grow.
 * Medium's dial is kept at least 16 under Large's on the same screen, so Large is visibly the bigger compass.
 */
object LayoutPlan {
    // The frozen gap tokens (C3.2 #1), × k.
    /** The header's top, under the status bar. Not × k. */
    const val TOP = 8f
    const val HEADER_GAP = 12f
    const val DIAL_GAP = 12f
    const val STATUS_GAP = 6f
    /** Status line → lock row. */
    const val LOCK_GAP = 8f
    /** Lock row (or status line) → spot row. */
    const val SPOT_GAP = 8f
    /** Readout group (or spot row) → grid. */
    const val GRID_GAP = 8f
    const val ROW_GAP = 8f
    const val MAP_GAP = 12f
    const val BOTTOM = 16f
    const val BOTTOM_TABLET = 24f
    /** Step 4: header → dial and the bottom take at most this much spare each. */
    const val SLACK_MAX = 24f
    const val BOTTOM_SPARE_MAX = 24f
    const val MARGIN = 16f
    const val MARGIN_TABLET = 20f
    /** Step 5: the dial never comes closer than this to the screen's edge. */
    const val DIAL_EDGE = 8f
    /**
     * The owner's rule: the compass takes up at least 40% of the screen. In one portrait column, at text sizes up
     * to 1.3, every layout's dial is at least min(0.40 H, C − 16) ([ownerFloor]); accessibility sizes and two
     * panes are exempt.
     */
    const val OWNER_SHARE = 0.40f
    /** The lock and spot rows merged into one row, the last thing given up before the list. */
    const val MERGED_ROW = 44f

    const val HEADER = 48f
    const val HEADER_TABLET = 52f
    /** A wrapped place name or date adds a line to the header: 22 and 16 × k. */
    const val TITLE_LINE = 22f
    const val DATE_LINE = 16f
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
    /** The lock row and the spot row (C3.4 #7): 52 high, one component. */
    const val LOCK = 52f
    const val SPOT = 52f
    const val TILE = 72f
    /** Medium's grown tiles: 88 on a phone, 96 on a tablet. */
    const val TILE_GROWN = 88f
    const val TILE_GROWN_TABLET = 96f
    /** Tiles in two panes: fixed 80 rows (C3.4 #5). */
    const val PANE_TILE = 80f
    /** The scrolling list's rows (C3.4 #6): 64, caption leading, value trailing. */
    const val LIST_TILE = 64f
    const val MAP_MIN = 140f
    /** Medium: a map card when this much is spare (C3.3). */
    const val MAP_PROMOTE = 160f
    /** …and the card is then at least this tall, taken from the dial down to its floor (as on Apple). */
    const val MAP_PROMOTED = 200f
    /** Two panes: Medium's card is at least this tall (C3.4 #5), else the map stays a tile. */
    const val PANE_MAP = 240f
    const val LIST_MAP = 200f
    const val MAX_COLUMN = 640f
    const val DIAL_MIN = 140f
    const val SMALL_SHARE = 0.36f
    const val MEDIUM_TABLET_SHARE = 0.48f
    const val LARGE_TABLET_SHARE = 0.54f
    const val XL_TABLET_SHARE = 0.64f
    /** Medium's dial stays this far under Large's (the golden test: dial(L) ≥ dial(M) + 16). */
    const val LARGE_STEP = 16f
    /**
     * At k ≥ 1.3 the dial was min(C − 48, 0.36 H) (C3.4 #6); in one column the owner's floor now lifts it to
     * min(0.40 H, C − 16). The accessibility list still starts from it.
     */
    const val BIG_TEXT_SHARE = 0.36f
    const val BIG_TEXT_INSET = 48f
    /** In the scrolling list the fold lands at least this far from a block's edge (C2.3 #15, C3.4 #6). */
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
    /** What TalkBack hears for the no-heading readout (the dash itself is drawn, C3.2 #3). */
    const val NO_HEADING_SPOKEN = "Heading unavailable"
    /** The no-heading dash (C3.2 #3): a rounded bar 0.5 em × 0.08 em at the readout's size, centred on the cap-height midline. */
    const val DASH_WIDTH = 0.5f
    const val DASH_HEIGHT = 0.08f
    /** The no-heading status line (C3.2 #3). */
    const val NO_COMPASS_STATUS = "No compass · position, sun and map still work"

    /**
     * The no-heading dash, as the screen draws it at readout size [size]: (centre above the baseline, width,
     * height). The readout's inline placeholder is cap height tall and sits on the baseline, and the bar is
     * drawn at its middle, so its centre is half the cap height above the baseline, where the middle of "228" is.
     */
    fun dash(size: Float): Triple<Float, Float, Float> = Triple(CAP_HEIGHT * size / 2f, DASH_WIDTH * size, DASH_HEIGHT * size)

    /**
     * [w] the window's (safe) width, [h] its full height including the system bars, [s] the safe height,
     * [k] the text multiplier (font scale), [accessibilityText] font scale 1.5 and up, [noHeading] no compass.
     * [statusLines] (0 lets the planner estimate them), [titleWraps] and [dateWraps] (the header's place name
     * or date runs to a second line), [lockTwoLines] and [spotTwoLines] (the lock and spot rows' two columns
     * don't fit side by side; null lets the planner estimate them) are measured by the screen.
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
        lockTwoLines: Boolean? = null,
        spotTwoLines: Boolean? = null,
    ): Plan {
        val headerLines = (if (titleWraps) 1 else 0) + (if (dateWraps) 2 else 0)
        val rowWidth = if (isLandscapePhone || (w > h && w >= TWO_PANE_WIDTH)) trailingWidth(layout, w) else columnWidth(w, h, isLandscapePhone)
        val two = Rows(lockTwoLines ?: estimateTwoLines(rowWidth, k.coerceIn(1f, MAX_K), LOCK_CHARS),
            spotTwoLines ?: estimateTwoLines(rowWidth, k.coerceIn(1f, MAX_K), SPOT_CHARS))
        val kk = k.coerceIn(1f, MAX_K)
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val c = min(w - 2 * margin, MAX_COLUMN)
        val lines = if (statusLines > 0) statusLines else estimateStatusLines(c, kk, noHeading)
        if (accessibilityText) return list(w, h, s, layout, k, tablet, locked, hasSpot, noHeading, headerLines)
        if (isLandscapePhone || (w > h && w >= TWO_PANE_WIDTH)) {
            return twoPanes(w, h, s, layout, kk, tablet, locked, hasSpot, hasUpdateBanner, lines, noHeading, headerLines, two)
                ?: list(w, h, s, layout, k, tablet, locked, hasSpot, noHeading, headerLines)
        }
        return column(w, h, s, layout, kk, tablet, locked, hasSpot, hasUpdateBanner, lines, noHeading, headerLines, two)
            ?: list(w, h, s, layout, k, tablet, locked, hasSpot, noHeading, headerLines, accessibility = false)
    }

    /** The dial's cap for [layout] (step 3), before step 5. */
    fun cap(layout: Layout, c: Float, h: Float, tablet: Boolean, k: Float, w: Float = c + 2 * MARGIN): Float {
        val base = when (layout) {
            Layout.SMALL -> min(SMALL_SHARE * h, c - 16f)
            Layout.MEDIUM -> if (tablet) min(c - 32f, MEDIUM_TABLET_SHARE * h) else c - 32f
            Layout.LARGE -> if (tablet) min(c - 16f, LARGE_TABLET_SHARE * h) else c - 16f
            // On a tablet the column widens to the dial, so the cap is in the window's terms.
            Layout.EXTRA_LARGE -> if (tablet) min(w - 2 * MARGIN_TABLET - 16f, XL_TABLET_SHARE * h) else c - 16f
        }
        return if (k >= MAX_K - 0.001f) min(base, min(c - BIG_TEXT_INSET, BIG_TEXT_SHARE * h)) else base
    }

    /**
     * The owner's rule: in one portrait column, at text sizes up to 1.3, the dial is never under
     * min(0.40 × H, C − 2 × 8) (H the full screen or window height, C the column).
     */
    fun ownerFloor(c: Float, h: Float): Float = min(OWNER_SHARE * h, c - 2 * DIAL_EDGE)

    /**
     * What a layout gives up, in this order, rather than take its dial under [ownerFloor]: [OWN] its own grid
     * and map; [GIVEN_UP] Small's map card becomes the header's map button, Medium's and Large's grids become the
     * compact row (Medium's map goes to the header); [MERGED] the lock and spot rows become one 44 row.
     */
    enum class Rung { OWN, GIVEN_UP, MERGED }

    /** One column (portrait): steps 1–5, on each rung in turn. Null when no rung keeps the dial at its floor: the list. */
    private fun column(
        w: Float, h: Float, s: Float, layout: Layout, kk: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        hasUpdateBanner: Boolean, statusLines: Int, noHeading: Boolean, headerLines: Int, two: Rows,
    ): Plan? {
        val c = min(w - 2 * (if (tablet) MARGIN_TABLET else MARGIN), MAX_COLUMN)
        val floor = ownerFloor(c, h)
        // What each layout wants before it stops giving things up: Small and Medium the floor, Large 16 over it
        // (so it stays a step over Medium), Extra Large at least Large's dial. At k ≥ 1.3 all of them the floor.
        val want = when {
            kk >= MAX_K - 0.001f -> floor
            layout == Layout.LARGE -> min(floor + LARGE_STEP, w - 2 * DIAL_EDGE)
            layout == Layout.EXTRA_LARGE -> max(floor,
                column(w, h, s, Layout.LARGE, kk, tablet, locked, hasSpot, hasUpdateBanner, statusLines, noHeading, headerLines, two)?.dial ?: 0f)
            else -> floor
        }
        // Large never outgrows Extra Large's best dial on this screen (Extra Large's bigger readout can leave it
        // less room), so Extra Large stays the biggest compass.
        val limit = if (layout == Layout.LARGE && kk < MAX_K - 0.001f) {
            Rung.entries.mapNotNull {
                columnOn(it, w, h, s, Layout.EXTRA_LARGE, kk, tablet, locked, hasSpot, hasUpdateBanner, statusLines, noHeading, headerLines, two)?.dial
            }.maxOrNull()?.let { max(it, floor) } ?: Float.MAX_VALUE
        } else Float.MAX_VALUE
        // The first rung that gives the layout what it wants; failing that, the rung with the biggest dial that is
        // still at the floor; failing that (null), the list.
        var best: Plan? = null
        for (rung in Rung.entries) {
            if (rung == Rung.GIVEN_UP && layout == Layout.EXTRA_LARGE) continue
            if (rung == Rung.MERGED && !locked && !hasSpot) continue
            val p = columnOn(rung, w, h, s, layout, kk, tablet, locked, hasSpot, hasUpdateBanner, statusLines, noHeading, headerLines, two, limit)
                ?: continue
            if (p.dial + 0.5f >= min(want, limit)) return p
            if (best == null || p.dial > best.dial + 0.5f) best = p
        }
        return best
    }

    private fun columnOn(
        rung: Rung, w: Float, h: Float, s: Float, layout: Layout, kk: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        hasUpdateBanner: Boolean, statusLines: Int, noHeading: Boolean, headerLines: Int, two: Rows, limit: Float = Float.MAX_VALUE,
    ): Plan? {
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val c = min(w - 2 * margin, MAX_COLUMN)
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(kk, tablet, headerLines)
        val banner = if (hasUpdateBanner) BANNER * kk + ROW_GAP else 0f
        val bottomInset = if (tablet) BOTTOM_TABLET else BOTTOM
        val merged = rung == Rung.MERGED
        // Merged: the readout group is the readout and status only; the one row sits a lock gap under the status.
        val group = groupHeight(headingSize, kk, locked && !merged, statusLines, two.lock)
        val spot = when {
            merged -> LOCK_GAP * kk + mergedHeight(kk)
            hasSpot -> SPOT_GAP * kk + spotHeight(kk, two.spot)
            else -> 0f
        }
        val base = TOP + header + HEADER_GAP * kk + banner + group + spot + GRID_GAP * kk + bottomInset
        val tile = tileHeight(kk)
        val tileCap = max(if (tablet) TILE_GROWN_TABLET else TILE_GROWN, tile)
        fun fixed(g: GridMode): Float = base + gridHeight(g, tile, 3, kk)
        val big = kk >= MAX_K - 0.001f
        // The owner's rule: no layout's dial under min(0.40 H, C − 16), at any text size up to 1.3.
        val floor = ownerFloor(c, h)
        val widestEdge = w - 2 * DIAL_EDGE
        val cap = when {
            big -> max(cap(layout, c, h, tablet, kk, w), floor)
            // Large stays a step over Medium even where Medium sits at the floor.
            layout == Layout.LARGE -> max(cap(layout, c, h, tablet, kk, w), min(floor + LARGE_STEP, widestEdge))
            layout == Layout.SMALL -> floor
            else -> max(cap(layout, c, h, tablet, kk, w), floor)
        }.coerceAtMost(max(limit, floor))
        // Step 5's limit: 8 dp from each edge (at k ≥ 1.3 the dial stays at its cap), and [limit].
        fun widest(cap: Float) = if (big) cap else min(max(cap, widestEdge), max(limit, cap))
        // Large's dial on this same screen (its whole plan, any rung): Medium's dial stays 16 under it.
        fun largeDial(): Float? =
            column(w, h, s, Layout.LARGE, kk, tablet, locked, hasSpot, hasUpdateBanner, statusLines, noHeading, headerLines, two)?.dial

        val own = rung == Rung.OWN
        var grid = when (layout) {
            Layout.SMALL, Layout.EXTRA_LARGE -> GridMode.COMPACT
            Layout.MEDIUM -> if (own) GridMode.FULL else GridMode.COMPACT
            Layout.LARGE -> if (own) GridMode.QUAD else GridMode.COMPACT
        }
        var map = when (layout) {
            Layout.SMALL -> if (own) MapMode.CARD else MapMode.BUTTON
            Layout.MEDIUM -> if (own) MapMode.TILE else MapMode.BUTTON
            else -> MapMode.BUTTON
        }
        var dial: Float
        var mapHeight = 0f
        var tileH = tile
        var top = 0f
        var bottom = 0f
        var centred = false
        // Step 4d: header → dial and the bottom, at most 24 each; step 5's last resort centres the rest.
        fun slack(spare: Float) {
            top = min(SLACK_MAX, spare / 2); bottom = min(SLACK_MAX, spare - top)
            val left = spare - top - bottom
            if (left > 0.5f) { centred = true; top += left / 2; bottom += left / 2 }
        }
        when {
            layout == Layout.SMALL && map == MapMode.CARD -> {
                // The dial at the floor; the map card takes all the rest, 140 or more, or the card gives way.
                val room = s - fixed(grid) - MAP_GAP * kk
                dial = cap
                if (room - dial + 0.5f < MAP_MIN) return null
                mapHeight = room - dial
            }
            layout == Layout.SMALL -> {
                // The card gave way: a map tile (a strip as wide as the column, a tile high or more) where one fits,
                // otherwise the header's map button. The dial stays at the floor.
                val room = s - fixed(grid)
                dial = min(cap, room)
                if (dial + 0.5f < floor) return null
                val strip = room - dial - MAP_GAP * kk
                when {
                    strip + 0.5f >= MAP_MIN -> { map = MapMode.CARD; mapHeight = strip }
                    strip + 0.5f >= tile -> { map = MapMode.TILE; mapHeight = strip }
                    else -> slack(room - dial)
                }
            }
            layout == Layout.MEDIUM -> {
                val room = s - fixed(grid)
                // 16 under Large's dial on this screen, never under the floor.
                dial = max(floor, min(min(cap, (largeDial() ?: room) - LARGE_STEP), room))
                if (room + 0.5f < dial) return null
                var spare = room - dial
                if (own && spare >= MAP_PROMOTE * kk) {
                    // A card of 200 or more, the difference taken from the dial down to its floor (C3.3).
                    map = MapMode.CARD; mapHeight = spare - MAP_GAP * kk; spare = 0f
                    if (mapHeight < MAP_PROMOTED * kk) {
                        val take = min(MAP_PROMOTED * kk - mapHeight, max(0f, dial - floor))
                        dial -= take; mapHeight += take
                    }
                } else if (own) {
                    val grow = min(spare, 2 * (tileCap - tile))
                    tileH = tile + grow / 2; spare -= grow
                }
                if (map != MapMode.CARD && spare > 2 * SLACK_MAX + 0.5f) {
                    if (own && room - dial - MAP_GAP * kk >= MAP_MIN) {
                        // Step 5: more than the tiles and the 24s can take, and a card of 140 fits: the map becomes a card.
                        map = MapMode.CARD; tileH = tile; mapHeight = room - dial - MAP_GAP * kk; spare = 0f
                    } else {
                        // Otherwise the dial grows on toward 16 from each edge, staying 16 under Large's.
                        val limit = min(if (big) cap else max(cap, w - 4 * DIAL_EDGE), (largeDial() ?: Float.MAX_VALUE) - LARGE_STEP)
                        val more = min(spare - 2 * SLACK_MAX, max(0f, limit - dial))
                        dial += more; spare -= more
                    }
                }
                slack(spare)
            }
            else -> {
                val room = s - fixed(grid)
                dial = min(cap, room)
                if (dial + 0.5f < floor) return null
                // Step 5: past the 24s, the dial grows on toward the edges (8 from each).
                if (room - dial > 2 * SLACK_MAX) dial = max(dial, min(widest(cap), room - 2 * SLACK_MAX))
                slack(room - dial)
            }
        }
        val gridH = gridHeight(grid, tileH, 3, kk)
        val used = base + gridH + dial + top + bottom + (if (mapHeight > 0f) MAP_GAP * kk + mapHeight else 0f)
        // On a tablet Extra Large's dial can be wider than the 640 column: the header and the tiles widen with
        // it (never past the margins), so the panel keeps one edge.
        val column = if (tablet && layout == Layout.EXTRA_LARGE) min(w - 2 * margin, max(c, dial)) else c
        return Plan(
            layout = layout, twoPane = false, list = false, tablet = tablet, k = kk, dial = dial, floor = floor, cap = cap,
            headingSize = headingSize, header = header, margin = margin, column = column, grid = grid, gridColumns = 3,
            map = map, mapHeight = mapHeight, tile = tileH, tileCap = tileCap, statusLines = statusLines, topExtra = top,
            bottomSpare = bottom, centred = centred, trailingWidth = 0f, leadingTop = 0f, trailingTop = 0f,
            locked = locked, hasSpot = hasSpot, used = used, noHeading = noHeading, lockTwoLines = two.lock, spotTwoLines = two.spot,
            rung = rung,
        )
    }

    /**
     * The scrolling list (§3.6, C3.4 #6): the header, the dial at min(C − 48, 0.36 H) (smaller where needed so
     * Position and Elevation are whole on the first screen and the fold lands 24 or more inside a block), the
     * readout, one "Targets" card for the lock and the spot, the tiles as 64 rows, then a 200 map card. Under
     * accessibility text ([accessibility]) that is all; when the list is only the last resort of a text size up to
     * 1.3, the owner's rule holds here too: the dial stays at [ownerFloor] (0.40 H, or C − 16 where the width is
     * less), even where Position and Elevation then run past the fold.
     */
    private fun list(
        w: Float, h: Float, s: Float, layout: Layout, k: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        noHeading: Boolean, headerLines: Int, accessibility: Boolean = true,
    ): Plan {
        val kl = k.coerceIn(1f, 2f)
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val c = min(w - 2 * margin, MAX_COLUMN)
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        // The list's header wraps its place and date: two more lines.
        val header = headerHeight(kl, tablet, 3)
        val statusLines = 2
        val group = groupHeight(headingSize, min(kl, MAX_K), false, statusLines, false)
        val targets = targetsHeight(kl, locked, hasSpot)
        val above = TOP + header + HEADER_GAP * kl
        val between = group + (if (targets > 0f) SPOT_GAP * kl + targets else 0f) + GRID_GAP * kl
        val owner = ownerFloor(c, h)
        val first = max(DIAL_MIN, min(c - BIG_TEXT_INSET, BIG_TEXT_SHARE * h)).let { if (accessibility) it else max(it, owner) }
        val floor = if (accessibility) min(DIAL_MIN, first) else owner
        val row = listTileHeight(kl)
        val dial = listDial(first, s, above, between, row, ROW_GAP * kl, max(DIAL_MIN, floor))
        return Plan(
            layout = layout, twoPane = false, list = true, tablet = tablet, k = kl, dial = dial, floor = floor, cap = first,
            headingSize = headingSize, header = header, margin = margin, column = c, grid = GridMode.ROWS, gridColumns = 1,
            map = MapMode.CARD, mapHeight = LIST_MAP, tile = row, tileCap = row, statusLines = statusLines, topExtra = 0f,
            bottomSpare = 0f, centred = false, trailingWidth = 0f, leadingTop = 0f, trailingTop = 0f,
            locked = locked, hasSpot = hasSpot, used = s, noHeading = noHeading, lockTwoLines = true, spotTwoLines = true,
        )
    }

    /**
     * The scrolling list's dial: from [first] down (never under 140) until Position and Elevation end on the first
     * screen with the fold at least 24 below them, and the fold doesn't fall within 24 of a block's edge. [above]
     * is everything over the dial, [between] the readout group, Targets card and gaps under it; then four rows
     * [row] high, [gap] apart, and the 200 map card. Never under [least].
     */
    fun listDial(first: Float, s: Float, above: Float, between: Float, row: Float, gap: Float, least: Float = DIAL_MIN): Float {
        fun ok(dial: Float): Boolean {
            val edges = mutableListOf<Pair<Float, Float>>()
            var y = above
            edges += y to y + dial; y += dial
            edges += y to y + between; y += between
            val rowTops = mutableListOf<Float>()
            repeat(4) { rowTops += y; edges += y to y + row; y += row + gap }
            y += MAP_GAP - gap
            edges += y to y + LIST_MAP
            // Position and Elevation whole, 24 above the fold.
            if (rowTops[1] + row + FOLD_CUE > s) return false
            val cut = edges.firstOrNull { (a, b) -> s > a && s < b } ?: return true
            return s - cut.first >= FOLD_CUE && cut.second - s >= FOLD_CUE
        }
        var d = first
        while (d >= least) { if (ok(d)) return d; d -= 2f }
        return least
    }

    /**
     * Two panes (C3.4 #5): a full-width header; the dial and readout centred in the leading pane (24 or more from
     * the bottom); in the trailing pane the lock row, the spot row, tile rows at a fixed 80 and the map card with
     * the rest. Small: the compact row and a map card (the header's button where a card of 140 won't fit).
     * Medium: Position | Elevation, then Sun | Moon at (C − 8) / 2 over a card of 240 or more (otherwise Sun | Moon
     * | Map). Large: 2 × 2, the map in the header, the pane's stack centred. Extra Large: a 60% leading pane, the
     * compact row, the map in the header, centred. Null when not even a 140 dial fits: the scrolling list.
     */
    private fun twoPanes(
        w: Float, h: Float, s: Float, layout: Layout, k: Float, tablet: Boolean, locked: Boolean, hasSpot: Boolean,
        hasUpdateBanner: Boolean, statusLines: Int, noHeading: Boolean, headerLines: Int, two: Rows,
    ): Plan? {
        val margin = if (tablet) MARGIN_TABLET else MARGIN
        val trailing = trailingWidth(layout, w)
        val pane = w - trailing - 3 * margin
        val headingSize = (if (tablet) HEADING_TABLET else HEADING) * layout.readoutScale
        val header = headerHeight(k, tablet, headerLines)
        val banner = if (hasUpdateBanner) BANNER * k + ROW_GAP else 0f
        val bottomInset = if (tablet) BOTTOM_TABLET else BOTTOM
        // The lock row is in the trailing pane here, so the leading group is the readout and status only.
        val group = groupHeight(headingSize, k, false, statusLines, false)
        val avail = s - TOP - header - HEADER_GAP * k - banner - bottomInset
        if (avail - group < DIAL_MIN) return null
        // Each layout keeps its own dial rule: Small 36% of H, Medium 48%, Large and Extra Large all the pane gives.
        val share = when (layout) { Layout.SMALL -> SMALL_SHARE; Layout.MEDIUM -> MEDIUM_TABLET_SHARE; else -> Float.MAX_VALUE }
        val dial = min(min(pane - 32f, avail - group), max(DIAL_MIN, share * h))
        val leadingTop = max(0f, (avail - group - dial) / 2)
        val rows = (if (locked) lockHeight(k, two.lock) + ROW_GAP * k else 0f) + (if (hasSpot) spotHeight(k, two.spot) + ROW_GAP * k else 0f)
        val tile = max(PANE_TILE, tileHeight(k))
        val columns = if (trailing >= PANE_THREE_COLUMNS) 3 else 2
        var grid: GridMode
        var map: MapMode
        var mapHeight = 0f
        when (layout) {
            Layout.SMALL -> {
                grid = GridMode.COMPACT
                val card = avail - rows - gridHeight(grid, tile, columns, k) - MAP_GAP * k
                if (card >= MAP_MIN) { map = MapMode.CARD; mapHeight = card } else map = MapMode.BUTTON
            }
            Layout.MEDIUM -> {
                grid = GridMode.FULL
                val card = avail - rows - gridHeight(grid, tile, columns, k) - MAP_GAP * k
                if (card >= PANE_MAP) { map = MapMode.CARD; mapHeight = card } else map = MapMode.TILE
            }
            Layout.LARGE -> { grid = GridMode.QUAD; map = MapMode.BUTTON }
            Layout.EXTRA_LARGE -> { grid = GridMode.COMPACT; map = MapMode.BUTTON }
        }
        val content = rows + gridHeight(grid, tile, columns, k) + (if (map == MapMode.CARD) MAP_GAP * k + mapHeight else 0f)
        // Too tall for the pane even without a card: the list.
        if (content > avail + 0.5f) return null
        val trailingTop = if (map == MapMode.CARD) 0f else (avail - content) / 2
        return Plan(
            layout = layout, twoPane = true, list = false, tablet = tablet, k = k, dial = dial, floor = DIAL_MIN, cap = dial,
            headingSize = headingSize, header = header, margin = margin, column = trailing, grid = grid, gridColumns = columns,
            map = map, mapHeight = mapHeight, tile = tile, tileCap = tile, statusLines = statusLines, topExtra = 0f,
            bottomSpare = 0f, centred = map != MapMode.CARD, trailingWidth = trailing, leadingTop = leadingTop,
            trailingTop = trailingTop, locked = locked, hasSpot = hasSpot, used = s, noHeading = noHeading,
            lockTwoLines = two.lock, spotTwoLines = two.spot,
        )
    }

    /**
     * The header bar: 48 (52 on a tablet) × k, and a line more for a wrapped place name (22, bit 1 of
     * [extraLines]) or date (16, bit 2).
     */
    fun headerHeight(k: Float, tablet: Boolean, extraLines: Int = 0) =
        (if (tablet) HEADER_TABLET else HEADER) * k + (if (extraLines and 1 != 0) TITLE_LINE * k else 0f) +
            (if (extraLines and 2 != 0) DATE_LINE * k else 0f)

    /** The tile column's width for a window: min(W − 2 × margin, 640) (the screen measures the header against it). */
    fun columnWidth(w: Float, h: Float, isLandscapePhone: Boolean): Float {
        val tablet = min(w, h) >= TABLET_WIDTH && !isLandscapePhone
        return min(w - 2 * (if (tablet) MARGIN_TABLET else MARGIN), MAX_COLUMN)
    }
    /** The readout's height: the heading's 1.1 line, less the trim above the digits' cap height. */
    fun readoutHeight(headingSize: Float, k: Float) = headingSize * (READOUT_LINE - READOUT_TRIM) * k
    fun statusHeight(k: Float, lines: Int) = STATUS * k * lines
    /**
     * The lock row (C3.4 #7): 52, more where the text needs it; with [twoLines] the cue's 15 line (20) under the
     * label's 17 (22), 6 above and below.
     */
    fun lockHeight(k: Float, twoLines: Boolean = false) = if (twoLines) max(LOCK, 12f + 42f * k) else max(LOCK, 24f + 22f * k)
    fun spotHeight(k: Float, twoLines: Boolean = false) = if (twoLines) max(SPOT, 12f + 42f * k) else max(SPOT, 24f + 22f * k)
    /**
     * The merged lock-and-spot row: 44 at text size 1.0 (a 15 label over a 13 value, 18 + 16, and 4 above and
     * below; 6 + 38 × k), taller at larger text.
     */
    fun mergedHeight(k: Float) = max(MERGED_ROW, 6f + 38f * k)

    /** Whether the lock and spot rows' two columns go on two lines. */
    data class Rows(val lock: Boolean, val spot: Boolean)

    /** "Locked 360°" + "turn 180° right" and "Marked spot" + "0.4 mi · 245° SW": their letters, for the estimate. */
    const val LOCK_CHARS = 26
    const val SPOT_CHARS = 27

    /**
     * Whether a two-column row of about [chars] letters at 17 × k (about 0.52 em each) and 12 between fits a row
     * [row] wide less its 14 inset and the ✕'s 48 + 4, when the screen hasn't measured it.
     */
    fun estimateTwoLines(row: Float, k: Float, chars: Int): Boolean = chars * 17f * k * 0.52f + 12f > row - 66f

    /** Two panes: the trailing pane's width, [Layout.paneShare] of the window between 320 and 480 (half at most). */
    fun trailingWidth(layout: Layout, w: Float): Float = (layout.paneShare * w).coerceIn(PANE_MIN, PANE_MAX).coerceAtMost(w / 2)
    /** A tile: 10 above and below, a 13 caption line and two 19 value lines, at least 72. */
    fun tileHeight(k: Float) = max(TILE, 20f + 51f * k)
    /** A row in the scrolling list: 10 above and below and two 19 value lines, at least 64. */
    fun listTileHeight(k: Float) = max(LIST_TILE, 20f + 38f * k)
    /** The list's Targets card: one row each for the lock and the spot (two lines at accessibility sizes). */
    fun targetsHeight(k: Float, locked: Boolean, spot: Boolean): Float {
        val n = (if (locked) 1 else 0) + (if (spot) 1 else 0)
        return n * max(LOCK, 12f + 42f * k)
    }

    /**
     * The status line's lines when the screen hasn't measured them: two at k > 1.1, and with no compass when
     * "No compass · position, sun and map still work" (about 0.56 em a letter) won't fit in C − 32.
     */
    fun estimateStatusLines(c: Float, k: Float, noHeading: Boolean): Int = when {
        k > 1.1f -> 2
        noHeading && NO_COMPASS_STATUS.length * 13f * k * 0.56f > c - 32f -> 2
        else -> 1
    }

    /** Dial → readout, the readout, readout → status, the status line and, when locked, the lock row. */
    fun groupHeight(headingSize: Float, k: Float, locked: Boolean, statusLines: Int, lockTwoLines: Boolean) =
        DIAL_GAP * k + readoutHeight(headingSize, k) + STATUS_GAP * k + statusHeight(k, statusLines) +
            (if (locked) LOCK_GAP * k + lockHeight(k, lockTwoLines) else 0f)

    fun gridRows(mode: GridMode, columns: Int) = when (mode) {
        GridMode.COMPACT -> 1
        GridMode.QUAD -> 2
        GridMode.FULL -> if (columns >= 3) 2 else 3
        GridMode.ROWS -> 4
    }

    fun gridHeight(mode: GridMode, tile: Float, columns: Int, k: Float = 1f): Float {
        val rows = gridRows(mode, columns)
        return rows * tile + (rows - 1) * ROW_GAP * k
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
     * then Sun | Moon | Map, or Sun | Moon at (C − 8) / 2 each when the map is a card. Full in a pane under 360:
     * Position; Elevation | Sun; Moon | Map (or Moon alone). Quad: Position | Elevation, Sun | Moon at (C − 8) / 2.
     * Compact: [compactWidths]. Rows: one full-width tile each.
     */
    fun rows(mode: GridMode, columns: Int, map: MapMode, c: Float): List<TileRowPlan> {
        val u = (c - 2 * ROW_GAP) / 3
        val half = (c - ROW_GAP) / 2
        val tileMap = map == MapMode.TILE
        return when (mode) {
            GridMode.ROWS -> listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN, TileKind.MOON).map { TileRowPlan(listOf(it), listOf(c)) }
            GridMode.COMPACT -> listOf(TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION, TileKind.SUN), compactWidths(c)))
            GridMode.QUAD -> listOf(
                TileRowPlan(listOf(TileKind.POSITION, TileKind.ELEVATION), listOf(half, c - ROW_GAP - half)),
                TileRowPlan(listOf(TileKind.SUN, TileKind.MOON), listOf(half, c - ROW_GAP - half)),
            )
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
        Device("Android 412x914", 412f, 914f, 914f - 24f - 48f),
        Device("Small Android", 360f, 640f, 640f - 24f - 48f),
        Device("Android tablet", 800f, 1280f, 1280f - 24f - 48f),
        Device("iPad mini portrait", 744f, 1133f, 1109f),
        Device("iPad 11 portrait", 834f, 1210f, 1166f),
        Device("iPad 13 portrait", 1032f, 1376f, 1332f),
        Device("iPad 11 landscape", 1210f, 834f, 790f),
        Device("iPad 13 landscape", 1376f, 1032f, 988f),
        Device("Android tablet landscape", 1280f, 800f, 800f - 24f - 48f),
        Device("Mac 380x720", 380f, 720f, 720f),
        Device("Mac 420x840", 420f, 840f, 840f),
        Device("Phone landscape", 915f, 412f, 412f - 24f),
    )

    /** The golden table's states (C3.3): sample (locked and marked), live (neither), no compass (marked), and the halves. */
    enum class State(val id: String, val locked: Boolean, val spot: Boolean, val noHeading: Boolean) {
        SAMPLE("sample", true, true, false),
        LIVE("live", false, false, false),
        NO_COMPASS("no compass", false, true, true),
        LOCKED("locked", true, false, false),
        MARKED("marked", false, true, false),
    }

    /** The devices the "four distinct layouts" check runs on (portrait and landscape). */
    private val distinctDevices = setOf("iPhone 16", "iPhone 16 Pro", "iPhone 17 Pro Max", "Pixel 7", "Android 412x914",
        "iPad mini portrait", "iPad 11 portrait", "iPad 13 portrait", "Android tablet", "Mac 420x840",
        "iPad 11 landscape", "iPad 13 landscape", "Android tablet landscape")

    /** The plan for [d]; font scale 1.5 and up is the scrolling list, as on the phone. */
    fun planFor(d: Device, layout: Layout, k: Float = 1f, state: State = State.SAMPLE): Plan {
        val landscape = d.w > d.h && d.s < LANDSCAPE_PHONE
        return plan(d.w, d.h, d.s, layout, k, k >= 1.5f, state.locked, state.spot, false, landscape, noHeading = state.noHeading)
    }

    /**
     * Runs the golden table (devices × layouts × states × text sizes) and returns the cases that break a rule
     * (C3.3's shared tests): every row's widths and gaps add up to the column; header top = safe top + 8; every
     * gap is its token × k (the Plan has no other); the bottom spare is 24 or less (or the stack is centred only
     * because nothing else can take the height: the dial is 8 dp from the edges and there is no card); the
     * content fills the safe height exactly; no tile is taller than its cap; the dial is at or over its floor;
     * the map card is 140 or more; Extra Large keeps the map in the header; adjacent layouts differ in grid mode
     * (and Medium → Large in map surface), dial(L) ≥ dial(M) + 16, in portrait and landscape; at k ≥ 1.3 the
     * dial is min(C − 48, 0.36 H) or less and in the list Position and Elevation are whole on the first screen.
     * Empty when all is well.
     */
    fun tableFailures(): List<String> {
        val failures = mutableListOf<String>()
        for (d in devices) for (layout in Layout.entries) for (state in State.entries) for (k in listOf(1f, 1.15f, 1.3f, 1.5f, 2f)) {
            val p = planFor(d, layout, k, state)
            val name = "${d.name} ${layout.id} k$k ${state.id}"
            // The owner's rule: the compass takes up at least 40% of the screen. In one portrait column at text
            // sizes up to 1.3 (the panel or the list it falls back to), no layout's dial is under
            // min(0.40 H, C − 16). Accessibility sizes and two panes are exempt.
            val owner = ownerFloor(columnWidth(d.w, d.h, false), d.h)
            if (d.w < d.h && k < 1.5f && !p.twoPane && p.dial + 0.5f < owner) {
                failures += "$name: dial ${p.dial} is ${"%.1f".format(java.util.Locale.US, 100 * p.dial / d.h)}% of H, under the owner's floor min(0.40 H, C − 16) = $owner"
            }
            for (row in p.rows) {
                val sum = row.widths.sum() + ROW_GAP * (row.widths.size - 1)
                if (abs(sum - p.column) > 0.01f) failures += "$name: row ${row.tiles} is $sum wide in a ${p.column} column"
                if (row.widths.any { it < 80f }) failures += "$name: a tile in ${row.tiles} is under 80 wide (${row.widths})"
            }
            if (p.tile > p.tileCap + 0.01f) failures += "$name: tile ${p.tile} over its cap ${p.tileCap}"
            if (p.list) {
                // Position and Elevation whole on the first screen, 24 above the fold.
                val above = TOP + p.header + HEADER_GAP * p.k + p.dial +
                    groupHeight(p.headingSize, min(p.k, MAX_K), false, p.statusLines, false) +
                    targetsHeight(p.k, p.locked, p.hasSpot).let { if (it > 0f) SPOT_GAP * p.k + it else 0f } + GRID_GAP * p.k
                val elevationBottom = above + 2 * p.tile + ROW_GAP * p.k
                if (p.dial > max(DIAL_MIN, p.floor) + 0.5f && elevationBottom + FOLD_CUE > d.s + 0.5f) failures += "$name: Elevation ends at $elevationBottom, past the fold at ${d.s}"
                continue
            }
            if (layout == Layout.EXTRA_LARGE && p.map != MapMode.BUTTON) failures += "$name: Extra Large's map is not in the header"
            if (p.dial + 0.5f < p.floor) failures += "$name: dial ${p.dial} under ${p.floor}"
            if (p.map == MapMode.CARD && p.mapHeight + 0.5f < MAP_MIN) failures += "$name: map card ${p.mapHeight}"
            if (p.mapStrip && (p.mapHeight + 0.5f < p.tile || p.layout != Layout.SMALL)) failures += "$name: map tile ${p.mapHeight}"
            if (p.k >= MAX_K - 0.001f && !p.twoPane) {
                // Large text: the dial gives way to the text down to the owner's floor, and no further.
                val big = max(owner, min(columnWidth(d.w, d.h, false) - BIG_TEXT_INSET, BIG_TEXT_SHARE * d.h))
                if (p.dial > big + 0.5f && !p.centred) failures += "$name: dial ${p.dial} over max(0.40 H floor, min(C − 48, 0.36 H)) = $big at large text"
            }
            if (!p.twoPane) {
                if (p.bottomSpare > BOTTOM_SPARE_MAX + 0.5f || p.topExtra > SLACK_MAX + 0.5f) {
                    // Only allowed when nothing else could take it.
                    // (or the layout gave up its card or grid to keep the dial at the floor, and nothing is left to grow).
                    val stuck = p.centred && p.map != MapMode.CARD && !p.mapStrip &&
                        (p.dial >= d.w - 2 * DIAL_EDGE - 0.5f || p.layout == Layout.MEDIUM || p.k >= MAX_K - 0.001f || p.rung != Rung.OWN)
                    if (!stuck) failures += "$name: ${p.bottomSpare} empty at the bottom, ${p.topExtra} over the dial"
                }
                if (abs(p.used - d.s) > 0.5f) failures += "$name: planned ${p.used} for a safe height of ${d.s}"
                if (p.dial > d.w - 2 * DIAL_EDGE + 0.5f) failures += "$name: dial ${p.dial} closer than 8 to the edge"
                if (p.dial > p.cap + 0.5f && p.layout == Layout.SMALL) failures += "$name: dial ${p.dial} over its cap ${p.cap}"
            } else {
                // The trailing pane: the lock and spot rows, the grid and the map card fit the content height.
                val avail = d.s - TOP - p.header - HEADER_GAP * p.k - p.bottom
                val content = (if (p.locked) p.lockHeight + p.rowGap else 0f) + (if (p.hasSpot) p.spotHeight + p.rowGap else 0f) +
                    gridHeight(p.grid, p.tile, p.gridColumns, p.k) + (if (p.map == MapMode.CARD) p.mapGap + p.mapHeight else 0f)
                if (p.trailingTop + content > avail + 0.5f) failures += "$name: trailing pane ${p.trailingTop + content} taller than $avail"
                if (p.map == MapMode.TILE && p.rows.none { TileKind.MAP in it.tiles }) failures += "$name: the Map tile has no cell"
                if (p.leadingTop < -0.01f) failures += "$name: the dial group runs over the pane"
            }
        }
        // Four distinct layouts (C3.2 #2, C3.3), portrait and landscape, in every state at text size 1.0.
        for (d in devices.filter { it.name in distinctDevices }) for (state in State.entries) {
            val plans = Layout.entries.map { planFor(d, it, 1f, state) }
            if (plans.any { it.list }) { failures += "${d.name} ${state.id}: a layout falls back to the list (${plans.joinToString { it.layout.id + " " + it.resultLine }})"; continue }
            // A layout that gave up its card or grid for the owner's floor may share its neighbour's grid; the dials
            // then still step up.
            for (i in 1 until plans.size) {
                val a = plans[i - 1]; val b = plans[i]
                if (a.grid == b.grid && a.rung == Rung.OWN && b.rung == Rung.OWN) failures += "${d.name} ${state.id}: ${b.layout.id} has ${a.layout.id}'s grid (${a.grid})"
            }
            val (_, medium, large, xl) = plans
            val own = plans.all { it.rung == Rung.OWN }
            if (own && medium.map == large.map) failures += "${d.name} ${state.id}: Medium and Large have the same map (${large.map})"
            if (!d.let { it.w > it.h } && large.dial < medium.dial + LARGE_STEP - 0.5f) failures += "${d.name} ${state.id}: Large's dial ${large.dial} is not 16 over Medium's ${medium.dial}"
            if (xl.dial < large.dial - 0.5f && xl.grid == large.grid) failures += "${d.name} ${state.id}: Extra Large is not bigger than Large"
            val keys = plans.map { Triple(it.grid, it.map, (it.dial / 16).roundToInt()) }.toSet()
            if (own && keys.size < 4) failures += "${d.name} ${state.id}: the four layouts give ${keys.size} distinct plans"
        }
        // In every portrait single column at text size 1.0 the dials step up: Small ≤ Medium < Large ≤ Extra Large
        // (where a layout fell back to the list, its neighbours are not compared with it).
        for (d in devices.filter { it.w < it.h }) for (state in State.entries) {
            val plans = Layout.entries.map { planFor(d, it, 1f, state) }
            val (small, medium, large, xl) = plans
            fun bad(what: String) { failures += "${d.name} ${state.id}: $what (${plans.joinToString { it.layout.id + " " + it.resultLine }})" }
            if (!small.list && !medium.list && small.dial > medium.dial + 0.5f) bad("Small's dial is over Medium's")
            if (!medium.list && !large.list && large.dial < medium.dial + 0.5f) bad("Large's dial is not over Medium's")
            if (!large.list && !xl.list && xl.dial < large.dial - 0.5f) bad("Extra Large's dial is under Large's")
        }
        // The worked numbers (Pixel 7 sample): the golden cells. The owner's floor there is C − 16 = 364
        // (0.40 H = 366): Small sits on it with a map tile, Medium on it with its 3 columns, Large 16 over it.
        val pixel = devices.first { it.name == "Pixel 7" }
        val ps = planFor(pixel, Layout.SMALL)
        if (ps.grid != GridMode.COMPACT || !ps.mapStrip || abs(ps.dial - 364f) > 0.5f) failures += "Small on Pixel 7: ${ps.resultLine}"
        val pm = planFor(pixel, Layout.MEDIUM)
        if (pm.grid != GridMode.FULL || pm.map != MapMode.TILE || abs(pm.dial - 364f) > 0.5f) failures += "Medium on Pixel 7: ${pm.resultLine}"
        val pl = planFor(pixel, Layout.LARGE)
        if (pl.grid != GridMode.QUAD || pl.map != MapMode.BUTTON || abs(pl.dial - 380f) > 0.5f || pl.tile != TILE) failures += "Large on Pixel 7: ${pl.resultLine}"
        // iPhone 16 sample (H 852): no layout under 0.40 H = 340.8; Medium gives up its grid rather than its dial.
        val i16 = devices.first { it.name == "iPhone 16" }
        val im = planFor(i16, Layout.MEDIUM)
        if (im.dial + 0.5f < 0.40f * i16.h || im.grid != GridMode.COMPACT) failures += "Medium on iPhone 16: ${im.resultLine}"
        val compact = compactWidths(370f)
        if (compact != listOf(146f, 104f, 104f) || compactWidths(380f) != listOf(156f, 104f, 104f) || compactWidths(700f) != listOf(306f, 189f, 189f)) {
            failures += "Compact widths: $compact, ${compactWidths(380f)}, ${compactWidths(700f)}"
        }
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

    /** "Locked 240° · turn 12° right" → ("Locked 240°", "turn 12° right"), with no-break spaces inside each (C3.4 #7). */
    fun lockParts(text: String): Pair<String, String?> {
        val i = text.indexOf(" · ")
        val nb = { s: String -> s.replace(' ', '\u00A0') }
        return if (i < 0) nb(text) to null else nb(text.substring(0, i)) to nb(text.substring(i + 3))
    }
}
