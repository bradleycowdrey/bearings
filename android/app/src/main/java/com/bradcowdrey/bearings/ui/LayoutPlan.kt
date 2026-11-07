package com.bradcowdrey.bearings.ui

import kotlin.math.max
import kotlin.math.min

/**
 * The four layouts (docs/LAYOUTS.md §2 and §6): the dial's share of the screen height [f], its side margin
 * [e] in dp, and the readout's scale. Saved under "layout" as [id]; anything else reads as Medium.
 */
enum class Layout(val id: String, val title: String, val f: Float, val e: Float, val readoutScale: Float, val column: Float) {
    SMALL("small", "Small", 0.40f, 16f, 1.00f, 0.50f),
    MEDIUM("medium", "Medium", 0.44f, 16f, 1.00f, 0.45f),
    LARGE("large", "Large", 0.48f, 16f, 1.08f, 0.40f),
    EXTRA_LARGE("extraLarge", "Extra Large", 0.52f, 8f, 1.15f, 0.35f);

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
 * What the screen shows above the dial: the title row and the sky card (the ⋯ menu in the title row), the
 * sky card alone (the ⋯ menu in its corner), or the one-line sky bar (the ⋯ menu at its end). In two panes
 * the title row is always in the trailing column, so the head is CARD or BAR.
 */
enum class Header { TITLE_ROW_AND_CARD, CARD, BAR }

/** The planner's answer. Every length is in dp. */
data class Plan(
    val layout: Layout,
    val twoPane: Boolean,
    val dial: Float,
    val readoutScale: Float,
    val header: Header,
    /** Small's inline map fits on the first screen, under the strip. */
    val mapOnFirstScreen: Boolean,
    /** The summary strip is visible without scrolling. */
    val stripOnFirstScreen: Boolean,
    /** The Details scroll area's planned height (single column), or the trailing column's (two panes). */
    val detailsViewport: Float,
    /** Nothing fits even with the dial at its floor: the head and Details scroll as one. */
    val scrollsWhole: Boolean,
    val showsFooter: Boolean,
    /** Two panes: the trailing column's width. 0 in a single column. */
    val trailingWidth: Float,
    /** The gap between blocks: 12, or 8 when the safe height is under 700. */
    val gap: Float,
    /** The heading number's size before the text multiplier: 56 (46 when short) × the readout scale. */
    val headingSize: Float,
    /** The dial as a share of the full height H. */
    val share: Float,
    /** The rule's floor for this window: min(0.40 × H, C − 2e) in a portrait single column. */
    val floor: Float,
)

/**
 * The layout planner (docs/LAYOUTS.md §4): one pure function with no UI code, the same constants and
 * order as LayoutPlan.swift. The dial is sized first, as a share of the full height H; the rest gives up
 * space in a fixed order before the dial shrinks, and in a portrait single column it never goes below 40%
 * of H. Android's heights: text lines × 1.1 for the heading, and 48 dp touch targets (so the sky bar is 48).
 */
object LayoutPlan {
    const val TOP = 4f
    const val BOTTOM = 8f
    const val GAP = 12f
    const val GAP_COMPACT = 8f
    const val COMPACT_HEIGHT = 700f
    const val TITLE_ROW = 48f
    const val TITLE_SPACE = 4f
    const val SKY_CARD = 72f
    const val SKY_CARD_COMPACT = 68f
    /** 44 on Apple; Android's ⋯ target is 48 dp. */
    const val SKY_BAR = 48f
    const val HEADING = 56f
    const val HEADING_COMPACT = 46f
    const val READOUT_LINE = 1.1f
    const val SUBLINE = 18f
    const val SPOT_LINE = 28f
    const val STRIP = 64f
    const val MAP_MIN = 96f
    const val MAP = 240f
    const val VIEWPORT_MIN = 96f
    const val MAX_COLUMN = 760f
    const val DIAL_MIN = 140f
    const val SHARE_FLOOR = 0.40f
    /** The update banner's height (Apple only; Android has none, but the planner keeps the input). */
    const val BANNER = 52f
    const val TWO_PANE_WIDTH = 600f
    const val LANDSCAPE_PHONE = 480f
    const val PANE_MARGIN = 16f
    /** The text multiplier's cap on Android. */
    const val MAX_K = 1.4f

    /**
     * [w] the window's (safe) width, [h] its full height including the system bars, [s] the safe height,
     * [k] the text multiplier (font scale, capped at 1.4), [accessibilityText] font scale 1.5 and up.
     */
    fun plan(
        w: Float,
        h: Float,
        s: Float,
        layout: Layout = Layout.DEFAULT,
        k: Float = 1f,
        accessibilityText: Boolean = false,
        hasSpot: Boolean = false,
        hasUpdateBanner: Boolean = false,
        showsFooter: Boolean = false,
        isLandscapePhone: Boolean = false,
    ): Plan {
        val kk = k.coerceIn(1f, MAX_K)
        // 1. Accessibility text: Large's rules (or Extra Large's) for the header, readout and map.
        val rules = if (accessibilityText && layout.ordinal < Layout.LARGE.ordinal) Layout.LARGE else layout
        val compact = s < COMPACT_HEIGHT
        val gap = if (compact) GAP_COMPACT else GAP
        // 2. Two panes on wide windows and phones in landscape.
        if (isLandscapePhone || (w > h && (w >= TWO_PANE_WIDTH || s < LANDSCAPE_PHONE))) {
            return twoPanes(w, h, s, layout, rules, kk, compact, gap, hasSpot, hasUpdateBanner, showsFooter)
        }

        val c = min(w, MAX_COLUMN)
        val widthCap = c - 2 * layout.e
        val target = min(layout.f * h, widthCap)
        val floor = min(SHARE_FLOOR * h, widthCap)

        // 3. Start from the layout's table.
        var titleRow = rules == Layout.SMALL || rules == Layout.MEDIUM
        var mapInline = rules == Layout.SMALL
        var bar = rules == Layout.EXTRA_LARGE
        var scale = rules.readoutScale
        var footer = showsFooter
        var stripFirst = true
        var dial = target

        fun headingSize() = (if (compact) HEADING_COMPACT else HEADING) * scale
        fun strip() = if (accessibilityText) 3 * stripHeight(kk) else stripHeight(kk)
        fun viewport(): Float {
            if (!stripFirst) return VIEWPORT_MIN
            val inline = if (mapInline) gap + MAP_MIN else 0f
            return max(VIEWPORT_MIN, strip() + inline)
        }
        fun fixed(): Float =
            TOP + (if (titleRow) titleHeight(kk) + TITLE_SPACE else 0f) +
                (if (bar) skyBarHeight(kk) else skyCardHeight(kk, withMenu = !titleRow)) + gap +
                (if (hasUpdateBanner) BANNER * kk + gap else 0f) +
                belowDial(headingSize(), kk, gap, hasSpot) + BOTTOM
        fun total() = fixed() + dial + viewport()

        // 4. Give up space, one step at a time, while it overflows the safe height.
        var step = 1
        while (total() > s && step <= 7) {
            when (step) {
                1 -> titleRow = false
                2 -> mapInline = false
                3 -> bar = true
                4 -> scale = 1f
                5 -> footer = false
                6 -> stripFirst = false
                7 -> dial = max(floor, s - fixed() - viewport())
            }
            step++
        }
        // 5. Still too tall with the dial at its floor: everything scrolls as one.
        val scrollsWhole = total() > s + 0.5f
        dial = max(dial, DIAL_MIN)
        val viewportLeft = if (scrollsWhole) viewport() else max(viewport(), s - fixed() - dial)
        return Plan(
            layout = layout, twoPane = false, dial = dial, readoutScale = scale,
            header = when { bar -> Header.BAR; titleRow -> Header.TITLE_ROW_AND_CARD; else -> Header.CARD },
            mapOnFirstScreen = mapInline && !scrollsWhole, stripOnFirstScreen = stripFirst && !scrollsWhole,
            detailsViewport = viewportLeft, scrollsWhole = scrollsWhole, showsFooter = footer, trailingWidth = 0f,
            gap = gap, headingSize = headingSize(), share = dial / h, floor = floor,
        )
    }

    private fun twoPanes(
        w: Float, h: Float, s: Float, layout: Layout, rules: Layout, k: Float, compact: Boolean, gap: Float,
        hasSpot: Boolean, hasUpdateBanner: Boolean, showsFooter: Boolean,
    ): Plan {
        val trailing = (w * layout.column).coerceIn(300f, 440f)
        // The leading pane: its margin on the left and a margin between the panes.
        val pane = w - trailing - 2 * PANE_MARGIN
        var bar = rules == Layout.EXTRA_LARGE
        var scale = rules.readoutScale
        fun headingSize() = (if (compact) HEADING_COMPACT else HEADING) * scale
        // The head, centred in the pane: the header, a gap, the dial and what's under it.
        fun byHeight() = s - TOP - BOTTOM - (if (bar) skyBarHeight(k) else skyCardHeight(k, withMenu = false)) - gap -
            (if (hasUpdateBanner) BANNER * k + gap else 0f) - belowDial(headingSize(), k, gap, hasSpot)
        val widthCap = pane - 48f
        val floor = min(SHARE_FLOOR * h, widthCap)
        // Give up the card, then the readout scale, before the dial goes under 40% of H.
        if (min(widthCap, byHeight()) < floor) bar = true
        if (min(widthCap, byHeight()) < floor) scale = 1f
        val fits = byHeight()
        val dial = max(DIAL_MIN, max(min(widthCap, fits), floor))
        return Plan(
            layout = layout, twoPane = true, dial = dial, readoutScale = scale,
            header = if (bar) Header.BAR else Header.CARD,
            mapOnFirstScreen = false, stripOnFirstScreen = true,
            detailsViewport = s - TOP - BOTTOM - titleHeight(k) - TITLE_SPACE,
            scrollsWhole = fits + 0.5f < dial, showsFooter = showsFooter, trailingWidth = trailing,
            gap = gap, headingSize = headingSize(), share = dial / h, floor = floor,
        )
    }

    /** The title row: 48, or the 34 title's line at a larger font size. */
    fun titleHeight(k: Float) = max(TITLE_ROW, 40f * k)
    /**
     * The sky card: 14 padding and two lines (72), or, with the ⋯ menu in its corner (no title row), 10
     * padding around the two lines or the 48 dp ⋯ target (68).
     */
    fun skyCardHeight(k: Float, withMenu: Boolean) = if (withMenu) max(SKY_CARD_COMPACT, 20f + 44f * k) else max(SKY_CARD, 28f + 44f * k)
    /** The sky bar: one 15 line, at least the 48 dp ⋯ target. */
    fun skyBarHeight(k: Float) = max(SKY_BAR, 24f + 20f * k)
    /** The strip: two lines (17 over 13) and 12 above and below. */
    fun stripHeight(k: Float) = max(STRIP, 24f + 40f * k)
    /** The readout's height: the heading's line (× 1.1 on Android). */
    fun readoutHeight(headingSize: Float, k: Float) = headingSize * READOUT_LINE * k
    /** The subline: 18 high (two lines at a larger font size, where it wraps). */
    fun sublineHeight(k: Float) = SUBLINE * k * (if (k > 1.1f) 2 else 1)
    fun spotHeight(k: Float) = max(SPOT_LINE, 20f * k)

    /** Under the dial: 4, the readout, the subline, a gap, and the spot line with its gap. */
    private fun belowDial(headingSize: Float, k: Float, gap: Float, hasSpot: Boolean) =
        4f + readoutHeight(headingSize, k) + sublineHeight(k) + gap + (if (hasSpot) spotHeight(k) + gap else 0f)

    /** A device in the planner's table (docs/LAYOUTS.md §2.1 and §11): width, full height, safe height. */
    data class Device(val name: String, val w: Float, val h: Float, val s: Float)

    /** The devices the self-test and the unit tests run the planner on. Safe heights are typical insets. */
    val devices = listOf(
        Device("iPhone SE", 375f, 667f, 647f),
        Device("iPhone 16", 393f, 852f, 759f),
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

    /**
     * Runs the whole table (devices × layouts × text sizes × marked spot × banner) and returns the cases that
     * break a rule: under 40% of H in a portrait single column, wider than the column, a viewport under 96,
     * or overflowing the safe height, without scrollsWhole. Empty when all is well.
     */
    fun tableFailures(): List<String> {
        val failures = mutableListOf<String>()
        for (d in devices) for (layout in Layout.entries) for ((k, acc) in listOf(1f to false, 1.3f to false, 1.4f to true))
            for (spot in listOf(false, true)) for (banner in listOf(false, true)) {
                val p = plan(d.w, d.h, d.s, layout, k, acc, spot, banner)
                val name = "${d.name} ${layout.id} k$k${if (acc) " acc" else ""}${if (spot) " spot" else ""}${if (banner) " banner" else ""}"
                if (!p.twoPane) {
                    if (p.dial + 0.5f < SHARE_FLOOR * d.h && p.dial + 0.5f < min(d.w, MAX_COLUMN) - 2 * layout.e) failures += "$name: dial ${p.dial} under 40% of ${d.h}"
                    if (p.dial > min(d.w, MAX_COLUMN) - 2 * layout.e + 0.5f) failures += "$name: dial ${p.dial} wider than the column"
                    if (!p.scrollsWhole && p.detailsViewport < VIEWPORT_MIN - 0.5f) failures += "$name: viewport ${p.detailsViewport}"
                } else if (p.dial + 0.5f < p.floor) failures += "$name: two panes, dial ${p.dial} under ${p.floor}"
            }
        if (plan(412f, 915f, 839f).layout != Layout.MEDIUM || Layout.of(null) != Layout.MEDIUM || Layout.of("bogus") != Layout.MEDIUM) failures += "Medium is not the default"
        return failures
    }

    /** The last plan the main screen drew, for the self-test's report. */
    @Volatile var last: Plan? = null
    @Volatile var lastHeight: Float = 0f
}
