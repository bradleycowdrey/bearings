import CoreGraphics

/// The four layouts (docs/LAYOUTS.md §2 and §6): the dial's share `f` of the full height, its side margin
/// `e`, the readout's scale, and the trailing column's share `c` in two panes. Saved under "layout" as the
/// raw value; anything else reads as Medium. (This shadows SwiftUI's `Layout` protocol inside the app,
/// which Bearings doesn't use.)
enum Layout: String, CaseIterable, Identifiable {
    case small, medium, large, extraLarge

    /// Medium, on every platform and device.
    static let `default`: Layout = .medium

    var id: String { rawValue }

    /// The name in the ⋯ menu: Small, Medium, Large, Extra Large.
    var name: String {
        switch self {
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large"
        case .extraLarge: "Extra Large"
        }
    }

    /// The dial's share of the full height H.
    var f: CGFloat {
        switch self {
        case .small: 0.40
        case .medium: 0.44
        case .large: 0.48
        case .extraLarge: 0.52
        }
    }

    /// The dial's side margin.
    var e: CGFloat { self == .extraLarge ? 8 : 16 }

    /// Multiplies the heading number and its point letters; never above 1.15.
    var readoutScale: CGFloat {
        switch self {
        case .small, .medium: 1
        case .large: 1.08
        case .extraLarge: 1.15
        }
    }

    /// Two panes: the trailing column's share of the width (a narrower column leaves the dial more room).
    var column: CGFloat {
        switch self {
        case .small: 0.50
        case .medium: 0.45
        case .large: 0.40
        case .extraLarge: 0.35
        }
    }

    private var index: Int { Self.allCases.firstIndex(of: self) ?? 1 }

    /// The next larger layout, or nil at Extra Large.
    var larger: Layout? { index + 1 < Self.allCases.count ? Self.allCases[index + 1] : nil }
    /// The next smaller layout, or nil at Small.
    var smaller: Layout? { index > 0 ? Self.allCases[index - 1] : nil }

    /// A saved or launch-argument id; unknown or missing reads as Medium.
    static func of(_ id: String?) -> Layout { id.flatMap(Layout.init(rawValue:)) ?? .default }
}

/// The planner's answer (docs/LAYOUTS.md §4): one pure function with no UI code, the same constants and
/// order as android/.../ui/LayoutPlan.kt. The dial is sized first, as a share of the full height H; the rest
/// gives up space in a fixed order before the dial shrinks, and in a portrait single column it never goes
/// below 40% of H. Every length is in points.
struct LayoutPlan: Equatable {
    /// What sits above the dial: the title row and the sky card (⋯ in the title row), the sky card alone
    /// (⋯ in its corner), or the one-line sky bar (⋯ at its end). In two panes the title row is always at
    /// the top of the trailing column, so the head is `card` or `bar`.
    enum Header: Equatable { case titleRowAndCard, card, bar }

    var layout: Layout
    var twoPane: Bool
    var dial: CGFloat
    var readoutScale: CGFloat
    var header: Header
    /// Small's inline map fits on the first screen, under the strip.
    var mapOnFirstScreen: Bool
    /// The summary strip is visible without scrolling.
    var stripOnFirstScreen: Bool
    /// The Details scroll area's planned height (single column), or the trailing column's (two panes).
    var detailsViewport: CGFloat
    /// Nothing fits even with the dial at its floor: the head and Details scroll as one.
    var scrollsWhole: Bool
    var showsFooter: Bool
    /// Two panes: the trailing column's width. 0 in a single column.
    var trailingWidth: CGFloat
    /// Between blocks: 12, or 8 when the safe height is under 700.
    var gap: CGFloat
    /// The heading number's size: 56 (46 when short, 64 in the wide iPad column) × the readout scale.
    var headingSize: CGFloat
    /// The dial as a share of the full height H.
    var share: CGFloat
    /// min(0.40 × H, C − 2e) in a portrait single column; the pane's own limit in two panes.
    var floor: CGFloat
    // For the view (Apple only).
    /// The column's width C = min(W, 760) (single column).
    var columnWidth: CGFloat
    /// The wider iPad column: 1.15, or 1.
    var wide: CGFloat
    /// The type scale for heights and text: Text Size (up to 1.3) × `wide`.
    var k: CGFloat
    /// Whether the subline may take a second line (a larger Text Size).
    var sublineWraps: Bool
    /// Accessibility text sizes: the strip becomes a list.
    var accessibilityText: Bool

    /// The title row "Bearings" with ⋯: above the sky card, or atop the trailing column in two panes.
    var showsTitleRow: Bool { twoPane || header == .titleRowAndCard }
    /// The ⋯ menu sits in the sky card's or the sky bar's corner (no title row).
    var menuInSky: Bool { !showsTitleRow }
    /// The map card follows the strip directly (Medium, two panes, or everything scrolling as one; its top
    /// may peek). Otherwise Large's and Extra Large's map (and Small's, when it doesn't fit inline) waits
    /// below the fold, with calm space under the strip.
    var mapPeeks: Bool { twoPane || scrollsWhole || (layout == .medium && !accessibilityText) }

    // MARK: Constants (points)

    static let top: CGFloat = 4
    static let bottom: CGFloat = 8
    static let gapNormal: CGFloat = 12
    static let gapCompact: CGFloat = 8
    static let compactHeight: CGFloat = 700
    static let titleRow: CGFloat = 48
    static let titleSpace: CGFloat = 4
    static let skyCard: CGFloat = 72
    static let skyCardCompact: CGFloat = 68
    static let skyBar: CGFloat = 44
    static let heading: CGFloat = 56
    static let headingCompact: CGFloat = 46
    static let headingWide: CGFloat = 64
    static let readoutLine: CGFloat = 1.2
    static let subline: CGFloat = 18
    static let spotLine: CGFloat = 28
    static let strip: CGFloat = 64
    static let mapMin: CGFloat = 96
    static let map: CGFloat = 240
    static let viewportMin: CGFloat = 96
    static let maxColumn: CGFloat = 760
    static let dialMin: CGFloat = 140
    static let shareFloor: CGFloat = 0.40
    /// The Mac's update banner (44) and the 4 under it.
    static let banner: CGFloat = 44
    static let twoPaneWidth: CGFloat = 700
    static let landscapePhone: CGFloat = 480
    static let paneMargin: CGFloat = 16
    /// The text multiplier's cap on Apple devices.
    static let maxK: CGFloat = 1.3

    // MARK: The planner

    /// `w` the window's (safe) width, `h` its full height including the safe-area insets, `s` the safe
    /// height, `k` the Text Size multiplier (capped at 1.3), `accessibilityText` an accessibility Text Size.
    static func plan(w: CGFloat, h: CGFloat, s: CGFloat, layout: Layout = .default, k: CGFloat = 1,
                     accessibilityText: Bool = false, hasSpot: Bool = false, hasUpdateBanner: Bool = false,
                     showsFooter: Bool = false, isLandscapePhone: Bool = false) -> LayoutPlan {
        let textK = min(max(k, 1), maxK)
        // 1. Accessibility text: Large's rules (or Extra Large's) for the header, readout and map.
        let rules: Layout = accessibilityText && (layout == .small || layout == .medium) ? .large : layout
        let compact = s < compactHeight
        let gap = compact ? gapCompact : gapNormal
        let wide: CGFloat = w >= twoPaneWidth && s >= 900 ? 1.15 : 1
        let kk = textK * wide
        let wraps = textK > 1.1
        let baseHeading = compact ? headingCompact : (wide > 1 ? headingWide : heading)

        // 2. Two panes on wide windows and phones in landscape.
        if isLandscapePhone || (w > h && (w >= twoPaneWidth || s < landscapePhone)) {
            let trailing = min(max(w * layout.column, 300), 440)
            // The leading pane: its margin on the left and a margin between the panes.
            let pane = w - trailing - 2 * paneMargin
            var bar = rules == .extraLarge
            var scale = rules.readoutScale
            func byHeight() -> CGFloat {
                let header: CGFloat = bar ? skyBarHeight(k: kk) : skyCardHeight(k: kk, compact: false)
                let under: CGFloat = belowDial(headingSize: baseHeading * scale, k: kk, wraps: wraps, gap: gap, hasSpot: hasSpot)
                return s - top - bottom - header - gap - under
            }
            let widthCap = pane - 48
            let floor = min(shareFloor * h, widthCap)
            // Give up the card, then the readout scale, before the dial goes under 40% of H.
            if min(widthCap, byHeight()) < floor { bar = true }
            if min(widthCap, byHeight()) < floor { scale = 1 }
            let fits = byHeight()
            let dial = max(dialMin, max(min(widthCap, fits), floor))
            let title: CGFloat = titleHeight(wide: wide) + titleSpace
            let bannerSpace: CGFloat = hasUpdateBanner ? banner + titleSpace : 0
            return LayoutPlan(
                layout: layout, twoPane: true, dial: dial, readoutScale: scale, header: bar ? .bar : .card,
                mapOnFirstScreen: false, stripOnFirstScreen: true,
                detailsViewport: s - top - bottom - title - bannerSpace,
                scrollsWhole: fits + 0.5 < dial, showsFooter: showsFooter, trailingWidth: trailing,
                gap: gap, headingSize: baseHeading * scale, share: dial / h, floor: floor,
                columnWidth: trailing, wide: wide, k: kk, sublineWraps: wraps, accessibilityText: accessibilityText)
        }

        let c = min(w, maxColumn)
        let widthCap = c - 2 * layout.e
        let target = min(layout.f * h, widthCap)
        let floor = min(shareFloor * h, widthCap)

        // 3. Start from the layout's table.
        var titleRow = rules == .small || rules == .medium
        var mapInline = rules == .small
        var bar = rules == .extraLarge
        var scale = rules.readoutScale
        var footer = showsFooter
        var stripFirst = true
        var dial = target

        func headingSize() -> CGFloat { baseHeading * scale }
        func stripH() -> CGFloat { accessibilityText ? 3 * stripHeight(k: kk) : stripHeight(k: kk) }
        func viewport() -> CGFloat {
            if !stripFirst { return viewportMin }
            let inline: CGFloat = mapInline ? gap + mapMin : 0
            return max(viewportMin, stripH() + inline)
        }
        func fixed() -> CGFloat {
            let title: CGFloat = titleRow ? titleHeight(wide: wide) + titleSpace : 0
            let bannerSpace: CGFloat = hasUpdateBanner ? banner + titleSpace : 0
            let sky: CGFloat = bar ? skyBarHeight(k: kk) : skyCardHeight(k: kk, compact: !titleRow)
            let under: CGFloat = belowDial(headingSize: headingSize(), k: kk, wraps: wraps, gap: gap, hasSpot: hasSpot)
            return top + title + bannerSpace + sky + gap + under + bottom
        }
        func total() -> CGFloat { fixed() + dial + viewport() }

        // 4. Give up space, one step at a time, while it overflows the safe height.
        var step = 1
        while total() > s && step <= 7 {
            switch step {
            case 1: titleRow = false
            case 2: mapInline = false
            case 3: bar = true
            case 4: scale = 1
            case 5: footer = false   // The footer is in Details (and About) anyway.
            case 6: stripFirst = false
            default: dial = max(floor, s - fixed() - viewport())
            }
            step += 1
        }
        // 5. Still too tall with the dial at its floor: everything scrolls as one.
        let scrollsWhole = total() > s + 0.5
        dial = max(dial, dialMin)
        let left = scrollsWhole ? viewport() : max(viewport(), s - fixed() - dial)
        return LayoutPlan(
            layout: layout, twoPane: false, dial: dial, readoutScale: scale,
            header: bar ? .bar : (titleRow ? .titleRowAndCard : .card),
            mapOnFirstScreen: mapInline && !scrollsWhole, stripOnFirstScreen: stripFirst && !scrollsWhole,
            detailsViewport: left, scrollsWhole: scrollsWhole, showsFooter: footer, trailingWidth: 0,
            gap: gap, headingSize: headingSize(), share: dial / h, floor: floor,
            columnWidth: c, wide: wide, k: kk, sublineWraps: wraps, accessibilityText: accessibilityText)
    }

    // MARK: Heights, shared with MainView so what it draws is what was planned

    /// The title row: 48 (× the wide column).
    static func titleHeight(wide: CGFloat) -> CGFloat { titleRow * wide }
    /// The sky card: 28 + 44 × k, or 24 + 44 × k with the ⋯ menu in its corner (never under 68, for its 44 target).
    static func skyCardHeight(k: CGFloat, compact: Bool) -> CGFloat { compact ? max(skyCardCompact, 24 + 44 * k) : max(skyCard, 28 + 44 * k) }
    /// The sky bar: one 15 line, at least the 44 ⋯ target.
    static func skyBarHeight(k: CGFloat) -> CGFloat { max(skyBar, 24 + 20 * k) }
    /// The summary strip: two lines (17 over 13) and 12 above and below.
    static func stripHeight(k: CGFloat) -> CGFloat { max(strip, 24 + 40 * k) }
    /// The readout: the heading's line, 1.2 × its size.
    static func readoutHeight(headingSize: CGFloat) -> CGFloat { headingSize * readoutLine }
    /// The subline: 18 × k, two lines where it may wrap.
    static func sublineHeight(k: CGFloat, wraps: Bool) -> CGFloat {
        let lines: CGFloat = wraps ? 2 : 1
        return subline * k * lines
    }
    /// The spot line: 28, or its 15 line at a larger Text Size.
    static func spotHeight(k: CGFloat) -> CGFloat { max(spotLine, 8 + 20 * k) }

    /// Under the dial: 4, the readout, 4, the subline, a gap, and the spot line with its gap.
    static func belowDial(headingSize: CGFloat, k: CGFloat, wraps: Bool, gap: CGFloat, hasSpot: Bool) -> CGFloat {
        let readout: CGFloat = readoutHeight(headingSize: headingSize)
        let sub: CGFloat = sublineHeight(k: k, wraps: wraps)
        let spot: CGFloat = hasSpot ? spotHeight(k: k) + gap : 0
        return 4 + readout + 4 + sub + gap + spot
    }

    // MARK: The table (docs/LAYOUTS.md §2.1 and §11)

    /// A device in the planner's table: width, full height, safe height.
    struct Device { let name: String; let w: CGFloat; let h: CGFloat; let s: CGFloat }

    /// The devices the self-tests and unit tests run the planner on. Safe heights are the usual insets.
    static let devices: [Device] = [
        Device(name: "iPhone SE", w: 375, h: 667, s: 647),
        Device(name: "iPhone 16", w: 393, h: 852, s: 759),
        Device(name: "iPhone 17 Pro Max", w: 440, h: 956, s: 862),
        Device(name: "Pixel 7", w: 412, h: 915, s: 915 - 52 - 24),
        Device(name: "iPad 11 portrait", w: 834, h: 1210, s: 1166),
        Device(name: "iPad 13 portrait", w: 1032, h: 1376, s: 1332),
        Device(name: "iPad 11 landscape", w: 1210, h: 834, s: 790),
        Device(name: "iPad 13 landscape", w: 1376, h: 1032, s: 988),
        Device(name: "Mac 380x720", w: 380, h: 720, s: 720),
        Device(name: "Mac 420x840", w: 420, h: 840, s: 840),
        Device(name: "Phone landscape", w: 852, h: 393, s: 372),
    ]

    /// Runs the whole table (devices × layouts × text sizes × marked spot × banner) and returns the cases
    /// that break a rule: under 40% of H in a portrait single column, wider than the column, a Details
    /// viewport under 96 without `scrollsWhole`, or under the floor in two panes. Empty when all is well.
    static func tableFailures() -> [String] {
        var failures: [String] = []
        for d in devices {
            for layout in Layout.allCases {
                for (k, acc) in [(CGFloat(1), false), (1.3, false), (1.3, true)] {
                    for spot in [false, true] {
                        for banner in [false, true] {
                            let p = plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, accessibilityText: acc,
                                         hasSpot: spot, hasUpdateBanner: banner)
                            let name = "\(d.name) \(layout.rawValue) k\(k)\(acc ? " acc" : "")\(spot ? " spot" : "")\(banner ? " banner" : "")"
                            let cap = min(d.w, maxColumn) - 2 * layout.e
                            if !p.twoPane {
                                if p.dial + 0.5 < shareFloor * d.h && p.dial + 0.5 < cap { failures.append("\(name): dial \(Int(p.dial)) under 40% of \(Int(d.h))") }
                                if p.dial > cap + 0.5 { failures.append("\(name): dial \(Int(p.dial)) wider than the column") }
                                if !p.scrollsWhole && p.detailsViewport < viewportMin - 0.5 { failures.append("\(name): viewport \(Int(p.detailsViewport))") }
                            } else if p.dial + 0.5 < p.floor {
                                failures.append("\(name): two panes, dial \(Int(p.dial)) under \(Int(p.floor))")
                            }
                        }
                    }
                }
            }
        }
        if plan(w: 393, h: 852, s: 759).layout != .medium || Layout.of(nil) != .medium || Layout.of("bogus") != .medium {
            failures.append("Medium is not the default")
        }
        return failures
    }
}
