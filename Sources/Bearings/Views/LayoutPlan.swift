import CoreGraphics

/// The four layouts (docs/REFINE.md §3.4, revised by Cycle 3 §C3.3, the owner's decision): one rule per
/// layout, the same on every port and device. The map surface shrinks as the compass grows, one step per
/// layout, and every step changes the grid, so the four always look different.
///
/// | Layout | Grid | Tiles | Map | Dial cap | Readout |
/// |---|---|---|---|---|---|
/// | Small "Compass + big map" | compact row | 72 | card ≥ 140, takes all spare (else a map tile, a strip a tile high or more, else the header button) | 0.40 H (its floor) | 1.0 |
/// | Medium "Balanced · map tile" (default) | 3 columns, 2 rows, with the Map tile | 72, grows to 88 from spare | tile; a card (≥ 200) when ≥ 160 is spare | W − 32 (tablet: and 0.48 H); 16 under Large | 1.0 |
/// | Large "Bigger compass · map in header" | 2 × 2 at (C − 8) / 2 | fixed 72 | header button | W − 16 (tablet: and 0.54 H) | 1.0 |
/// | Extra Large "Biggest compass · one row" | compact row | 72 | header button | W − 16 (tablet: and 0.64 H, the column widens to the dial) | 1.25 |
///
/// The owner's rule: in one column (phones, iPad portrait, Mac windows taller than wide), at every text size
/// short of the accessibility sizes, every layout's dial is at least min(0.40 H, its width cap). Small sits
/// at that floor, Medium at or over it, Large over Medium, Extra Large the largest. Short of height, a
/// layout gives up its other parts first (`LayoutPlan.plan`), never the dial.
///
/// (On iPad the tiles are 96 and do not grow.) Saved under "layout" as the raw value; anything else reads
/// as Medium. (This shadows SwiftUI's `Layout` protocol inside the app, which Bearings doesn't use.)
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

    /// The one-line subtitle in both menus (the ⋯ menu and the Mac's View › Layout): what the layout
    /// changes (C3.2 #2).
    var subtitle: String {
        switch self {
        case .small: "Compass + big map"
        case .medium: "Balanced · map tile"
        case .large: "Bigger compass · map in header"
        case .extraLarge: "Biggest compass · one row"
        }
    }

    /// The symbol beside the name in the Layout menu.
    var symbol: String {
        switch self {
        case .small: "map"
        case .medium: "square.grid.3x2"
        case .large: "square.grid.2x2"
        case .extraLarge: "location.north.circle"
        }
    }

    /// The dial's side margin from the screen's edge (or the column's outer edge): the width cap is the
    /// column plus its margins, less 2e: W − 32 for Small and Medium, W − 16 for Large and Extra Large.
    var e: CGFloat {
        switch self {
        case .small, .medium: 16
        case .large, .extraLarge: 8
        }
    }

    /// The dial's floor, as a share of the full height H: the owner's rule, 0.40 H for every layout (capped
    /// by the layout's width cap). The planner gives up everything else before the dial goes under it.
    var floorShare: CGFloat { LayoutPlan.ownerShare }

    /// On a tablet (and in two panes) the dial is also capped at this share of H. In one column Small
    /// uses 0.40 H (`LayoutPlan.smallShare`) instead; two panes keep 0.36.
    var tabletShare: CGFloat {
        switch self {
        case .small: 0.36
        case .medium: 0.48
        case .large: 0.54
        case .extraLarge: 0.64
        }
    }

    /// Multiplies the heading number and its point letters: 1.25 at Extra Large (56 → 70; 96 → 120 on iPad).
    var readoutScale: CGFloat { self == .extraLarge ? 1.25 : 1 }

    /// Small and Extra Large use the compact row (Position, Elevation, Sun with the moon in its caption).
    var compactRow: Bool { self == .small || self == .extraLarge }

    /// Two panes: the trailing pane's share of the width (C3.4 #5: Extra Large's leading pane is 60%).
    var paneShare: CGFloat {
        switch self {
        case .small: 0.50
        case .medium: 0.42
        case .large: 0.36
        case .extraLarge: 0.40
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

/// The "Instrument panel" planner (docs/REFINE.md §3.3, replaced by Cycle 3 §C3.3: one rule set for Apple
/// and Android): one pure function with no UI code. MainView reads the dial, the grid (`cells`), the map,
/// the tiles and every gap from the plan and nowhere else.
///
/// Shared steps:
/// 1. The header is pinned at the safe top + 8 (a Mac window: 24 in from every edge).
/// 2. The fixed blocks are placed with frozen gap tokens × k that never grow: header → dial 12, dial →
///    readout 12, readout → status 6, status → lock 8, lock → spot 8, (spot →) grid 8, rows 8, grid → map
///    card 12, bottom 16 (24 on iPad and Mac).
/// 3. Dial = min(cap, S − fixed).
/// 4. The dial never goes under its floor, min(0.40 H, the width cap) (the owner's rule). When the height
///    runs short, the plan gives things up in this order instead: tile growth, then the spare gaps, then
///    Small's map card (it shrinks to a map tile, a strip a tile high or more, then the map moves to the
///    header button), then Medium's and Large's grids (the compact row, the map in the header; Large gives
///    up its 2 × 2 rather than sit within 16 of the floor, and Extra Large merges its rows rather than fall
///    under Large), then the lock and spot rows (one 44 row, `merged`), and only then the
///    whole screen becomes the scrolling list, whose dial also keeps 0.40 H where the width allows.
/// 5. Spare height goes, in order: to the dial (up to its cap), to the map card (Small and Medium only), to
///    taller tiles (Medium only, 72 → 88 on phones), then split between header → dial and the bottom, each
///    at most 24. Anything still left (a tall window where the dial is already as wide as it may be and
///    nothing else may grow): Medium's map becomes a card where one of 140 fits; otherwise the dial grows
///    to its width cap (staying 16 under the next layout's), and the rest is split evenly above and below,
///    so the panel is centred under the header rather than ending on a dead band (`centred`).
///
/// From top to bottom: header bar → dial → readout → status line → lock row → spot row → tile grid → map
/// card (only where it fits whole).
struct LayoutPlan: Equatable {
    /// The tile grid: 3 columns in two rows (Position 2u | Elevation, then Sun | Moon | Map), 2 × 2
    /// (Position | Elevation, Sun | Moon), the compact row (Position | Elevation | Sun, widths from C), or
    /// full-width rows in the scrolling list.
    enum Grid: Equatable { case full, twoByTwo, compact, list }
    /// Where the map is: a tile in the grid, a full-width card, or a button in the header (map sheet).
    enum Map: Equatable { case tile, card, button }
    /// The tiles of the grid.
    enum Tile: Equatable { case position, elevation, sun, moon, map }
    /// One tile and its width.
    struct Cell: Equatable {
        var tile: Tile
        var width: CGFloat
    }

    var layout: Layout = .default
    var twoPane = false
    /// The whole screen scrolls as one list (accessibility text sizes, or nothing fits even at the floor).
    var list = false
    /// An iPad (or a Mac window as large): the regular-width type ramp, header 56, heading 96, tiles 96.
    var tablet = false
    /// A Mac window: 24 in from every edge.
    var mac = false
    var locked = false
    var hasSpot = false
    /// The lock row and the spot row share one 44 × k row (the owner's rule: before the screen scrolls).
    var merged = false
    /// An accessibility Text Size (the scrolling list; exempt from the owner's 0.40 H floor).
    var accessibilityText = false
    /// The text multiplier (Text Size, 1…1.3).
    var k: CGFloat = 1
    var margin: CGFloat = 16
    /// The header's top under the safe area: 8 (24 from a Mac window's edge). Pinned in every layout and state.
    var topInset: CGFloat = 8
    /// Under the last block: 16 × k (24 × k on iPad and Mac).
    var bottomInset: CGFloat = 16
    /// The grid's width: the column C (single column) or the trailing pane's content (two panes).
    var columnWidth: CGFloat = 0
    /// Two panes: the trailing pane's width (its content plus the right margin). 0 in a single column.
    var trailingWidth: CGFloat = 0
    /// The grid's columns: 3, or 2 in a trailing pane narrower than 340.
    var columns = 3
    var dial: CGFloat = 0
    var floor: CGFloat = 0
    /// The dial's cap for this layout (width, and the share of H where one applies).
    var dialCap: CGFloat = 0
    /// The dial as a share of the full height H.
    var share: CGFloat = 0
    var readoutScale: CGFloat = 1
    /// The heading number's size: 56 (96 on a tablet) × the readout scale.
    var headingSize: CGFloat = 56
    var headerHeight: CGFloat = 48
    var statusLines: CGFloat = 1
    /// No compass: the dash readout, and the status line's two-line note.
    var noCompass = false
    var grid: Grid = .full
    var map: Map = .tile
    /// The map card's height (0 unless `map == .card`; under 140 only for Small's `mapStrip`).
    var mapHeight: CGFloat = 0
    /// 72 × k (96 × k on a tablet); Medium grows it up to 88 × k on a phone; two panes use 80 × k.
    var tileHeight: CGFloat = 72
    // The frozen gaps (token × k).
    var gapHeaderDial: CGFloat = 12
    var gapDialReadout: CGFloat = 12
    var gapReadoutStatus: CGFloat = 6
    var gapStatusRows: CGFloat = 8
    var gapRows: CGFloat = 8
    var gapGridMap: CGFloat = 12
    /// Spare added under the header, above the dial (at most 24, unless `centred`).
    var topExtra: CGFloat = 0
    /// Spare left under the grid or map (with the bottom inset). At most 24, unless `centred`.
    var bottomSpare: CGFloat = 0
    /// The panel is centred under the header: more was spare than 24 + 24 with nothing left to grow.
    var centred = false
    /// Two panes: the trailing stack's top inset (Large and Extra Large centre it).
    var trailingInset: CGFloat = 0
    /// Two panes: the trailing pane holds more than fits and scrolls (a phone on its side).
    var trailingScrolls = false
    /// Everything the plan places, top to bottom (single column; the trailing pane in two panes).
    var used: CGFloat = 0
    /// The grid's top, from the top of the safe area (single column and the list).
    var gridTop: CGFloat = 0
    /// The list: the bottom of the Position row and of the Elevation row, from the top of the safe area.
    var listFold: CGFloat = 0
    var listFold2: CGFloat = 0

    /// The map button sits in the header only when the map is neither a tile nor a card.
    var mapInHeader: Bool { map == .button }

    /// Small under pressure (the owner's rule): its card shrank to a map tile, a strip as wide as the column
    /// and a tile high or more but under 140, under the compact row. Drawn as the card is, `mapHeight` high.
    var mapStrip: Bool { layout == .small && !list && !twoPane && map == .card && mapHeight < Self.mapMin - 0.5 }

    /// The layout gave up part of itself to keep its dial at the owner's 0.40 H floor: Small's map card,
    /// Medium's 3 columns or Large's 2 × 2 (to the compact row), or the separate lock and spot rows.
    var yielded: Bool {
        if list || twoPane { return false }
        switch layout {
        case .small: return map != .card || mapStrip || merged
        case .medium: return grid != .full || merged
        case .large: return grid != .twoByTwo || merged
        case .extraLarge: return merged
        }
    }

    /// The owner's floor for this plan's layout: min(0.40 H, the column plus its margins less 2e).
    func ownerFloor(h: CGFloat) -> CGFloat {
        min(Self.ownerShare * h, columnWidth + 2 * margin - 2 * layout.e)
    }
    /// The grid's unit width u = (C − 2 × 8) / 3.
    var unit: CGFloat { (columnWidth - 2 * Self.rowGap) / 3 }

    /// The compact row's widths, from C rather than from grid units (C2.2 #1): Elevation = Sun =
    /// w = max(104, round(0.27 C)) and Position = C − 2 × 8 − 2w, so the row is exactly C wide.
    var compactWidths: (position: CGFloat, other: CGFloat) { Self.compactWidths(columnWidth) }

    static func compactWidths(_ c: CGFloat) -> (position: CGFloat, other: CGFloat) {
        let w = max(compactMin, (compactShare * c).rounded())
        return (c - 2 * rowGap - 2 * w, w)
    }

    /// The grid, row by row, exactly as MainView draws it: each row's widths plus its 8 gutters add up to C.
    var cells: [[Cell]] {
        let c = columnWidth, g = Self.rowGap, half = (c - g) / 2
        func cell(_ tile: Tile, _ width: CGFloat) -> Cell { Cell(tile: tile, width: width) }
        switch grid {
        case .list:
            return [[cell(.position, c)], [cell(.elevation, c)], [cell(.sun, c)], [cell(.moon, c)]]
        case .compact:
            let w = compactWidths
            return [[cell(.position, w.position), cell(.elevation, w.other), cell(.sun, w.other)]]
        case .twoByTwo:
            return [[cell(.position, half), cell(.elevation, half)], [cell(.sun, half), cell(.moon, half)]]
        case .full:
            if columns == 3 {
                let u = unit
                let second = map == .tile ? [cell(.sun, u), cell(.moon, u), cell(.map, u)] : [cell(.sun, half), cell(.moon, half)]
                return [[cell(.position, 2 * u + g), cell(.elevation, u)], second]
            }
            var rows = [[cell(.position, half), cell(.elevation, half)], [cell(.sun, half), cell(.moon, half)]]
            if map == .tile { rows.append([cell(.map, c)]) }
            return rows
        }
    }

    /// Each row's tile widths, top to bottom.
    var rowWidths: [[CGFloat]] { cells.map { $0.map(\.width) } }

    /// The grid's height as drawn (the list's rows may grow).
    var gridHeight: CGFloat {
        let rows = CGFloat(cells.count)
        return rows * tileHeight + max(0, rows - 1) * gapRows
    }

    // MARK: Constants (points; dp on Android). Spacing tokens are 4 / 8 / 12 / 16 / 24 only.

    /// The header's top under the safe area (C3.2 #1).
    static let top: CGFloat = 8
    static let headerToDial: CGFloat = 12
    static let dialToReadout: CGFloat = 12
    static let readoutToStatus: CGFloat = 6
    /// Status line → the first row (lock, spot or grid).
    static let statusToRows: CGFloat = 8
    /// Lock row → spot row → grid, between grid rows, and the gutters between tiles.
    static let rowGap: CGFloat = 8
    static let gridToMap: CGFloat = 12
    static let bottomPhone: CGFloat = 16
    static let bottomLarge: CGFloat = 24
    static let marginPhone: CGFloat = 16
    /// iPad: C = min(W − 48, 720), so the margin is the same in every layout.
    static let marginTablet: CGFloat = 24
    /// A Mac window: 24 in from all four edges (C3.4 #17).
    static let macInset: CGFloat = 24
    static let maxColumn: CGFloat = 640
    static let maxColumnTablet: CGFloat = 720
    static let header: CGFloat = 48
    static let headerTablet: CGFloat = 56
    static let heading: CGFloat = 56
    static let headingTablet: CGFloat = 96
    /// The readout's block, its line box trimmed: from the digits' cap height (0.72 of the size, with the
    /// light weight's rounding) to 4 under the baseline.
    static let readoutCap: CGFloat = 0.72
    static let readoutBelow: CGFloat = 4
    /// The status line's 13 pt line.
    static let statusLine: CGFloat = 16
    /// The lock row and the spot row (C3.4 #7): one component on both ports, 52 high, two columns.
    static let lockRow: CGFloat = 52
    static let spotRow: CGFloat = 52
    /// The lock and spot rows merged into one (the owner's rule, before the list): 44, side by side.
    static let mergedRow: CGFloat = 44
    static let tile: CGFloat = 72
    static let tileGrown: CGFloat = 88
    /// iPad's regular-width tiles: 96, which never grow (C3.4 #10).
    static let tileTablet: CGFloat = 96
    /// Two panes on a phone or a small Mac window: fixed 80 rows (C3.4 #5).
    static let tilePane: CGFloat = 80
    /// The compact row: Elevation and Sun are max(104, 0.27 C) wide.
    static let compactMin: CGFloat = 104
    static let compactShare: CGFloat = 0.27
    /// The longest Position line, a decimal-degrees longitude ("106.94117° W"), at the compact row's smallest
    /// size (0.85 of 15 pt; of 20 semibold on a tablet) at Text Size 1.0, with a little in hand (the self-test
    /// measures 120 on a tablet). Scaled by k.
    static let positionLine: CGFloat = 96
    static let positionLineTablet: CGFloat = 128
    /// A tile's horizontal inset each side (Ramp.insetH: 12; 14 on a tablet).
    static let tileInset: CGFloat = 12
    static let tileInsetTablet: CGFloat = 14

    /// The narrowest Position tile that holds the longest coordinate line on one line at text size `k`.
    /// In two panes a compact row whose Position is narrower than this gives way to the 2 × 2.
    static func positionNeed(k: CGFloat, tablet: Bool) -> CGFloat {
        let line: CGFloat = tablet ? positionLineTablet : positionLine
        let inset: CGFloat = tablet ? tileInsetTablet : tileInset
        return line * k + 2 * inset
    }
    /// Medium: spare at or above this (dial at its cap) turns the Map tile into a full-width card…
    static let mapPromote: CGFloat = 160
    /// …of at least this height, taken from the dial.
    static let mapPromoted: CGFloat = 200
    static let mapMin: CGFloat = 140
    /// Two panes on a tablet: the map card is at least this tall, or the map stays a tile.
    static let mapPaneTablet: CGFloat = 240
    /// Medium's dial stays this far under Large's (C3.2 #2), unless Medium is at its floor.
    static let layoutStep: CGFloat = 16
    /// The most ever left empty at the bottom (and added above the dial), unless the panel is centred.
    static let maxSpare: CGFloat = 24
    /// The owner's hard rule: the compass takes up at least 40% of the screen. In one column, at every text
    /// size short of the accessibility sizes, every dial is at least min(0.40 H, its width cap).
    static let ownerShare: CGFloat = 0.40
    /// Small's dial: 0.40 H, the owner's floor.
    static let smallShare: CGFloat = ownerShare
    /// Two panes at Text Size 1.3, and the accessibility list: dial = min(W − 48, 0.36 H) (C3.4 #6). (In one
    /// column, Text Size 1.3 keeps the owner's 0.40 H.)
    static let largeTextK: CGFloat = 1.3
    static let largeTextInset: CGFloat = 48
    static let largeTextShare: CGFloat = 0.36
    /// The scrolling list: its map card is 200, its tiles 64 rows (caption leading, value trailing), and
    /// the Targets card (lock and spot together) has a 44 line for each.
    static let listMap: CGFloat = 200
    static let listRow: CGFloat = 64
    static let targetsLine: CGFloat = 44
    static let targetsPadding: CGFloat = 4
    static let dialMin: CGFloat = 120
    /// A window whose shorter side is at least this is a tablet (iPad, or a large Mac window).
    static let tabletSide: CGFloat = 700
    static let twoPaneWidth: CGFloat = 700
    static let landscapePhone: CGFloat = 480
    /// The narrowest trailing pane (a phone on its side): C = 344, as an iPhone SE's column, so the compact
    /// row's Position (120) holds a longitude on one line.
    static let paneMin: CGFloat = 360
    static let paneMax: CGFloat = 560
    static let paneColumns3: CGFloat = 340
    /// The Mac's update banner (44) and the 8 under it.
    static let banner: CGFloat = 44
    static let bannerGap: CGFloat = 8
    /// The text multiplier's cap on Apple devices.
    static let maxK: CGFloat = 1.3
    /// The Mac window's smallest size: every layout with the sample (locked and marked) fits without
    /// scrolling, with 24 at every edge (header + dial + grid + insets).
    static let macMinWidth: CGFloat = 420
    static let macMinHeight: CGFloat = 780

    // MARK: Heights, shared with MainView so what it draws is what was planned

    static func headerHeight(k: CGFloat, tablet: Bool) -> CGFloat { (tablet ? headerTablet : header) * k }
    /// The readout's trimmed block: cap height to 4 under the baseline.
    static func readoutHeight(headingSize: CGFloat) -> CGFloat { headingSize * readoutCap + readoutBelow }
    static func statusHeight(k: CGFloat, lines: CGFloat) -> CGFloat { statusLine * k * lines }
    static func lockHeight(k: CGFloat) -> CGFloat { lockRow * k }
    static func mergedHeight(k: CGFloat) -> CGFloat { mergedRow * k }
    static func spotHeight(k: CGFloat) -> CGFloat { spotRow * k }
    /// The list's Targets card: a 44 line per target and 4 above and below.
    static func targetsHeight(k: CGFloat, lines: CGFloat) -> CGFloat { (targetsLine * lines + 2 * targetsPadding) * k }
    /// The readout group: the readout, 6, the status line.
    static func groupHeight(headingSize: CGFloat, k: CGFloat, statusLines: CGFloat) -> CGFloat {
        readoutHeight(headingSize: headingSize) + readoutToStatus * k + statusHeight(k: k, lines: statusLines)
    }

    // MARK: The planner

    /// `w` the window's (safe) width, `h` its full height including the safe-area insets, `s` the safe
    /// height, `k` the Text Size multiplier (capped at 1.3), `accessibilityText` an accessibility Text Size.
    /// `locked` the lock row shows; `hasSpot` the spot row; `noCompass` the dash and the two-line note;
    /// `mac` a Mac window. `onlyMerged` (the planner's own probe of Extra Large for Large's limit) tries only
    /// the stages with the rows merged (true) or separate (false), and wants no more than the floor.
    static func plan(w: CGFloat, h: CGFloat, s: CGFloat, layout: Layout = .default, k: CGFloat = 1,
                     accessibilityText: Bool = false, hasSpot: Bool = false, locked: Bool = false,
                     noCompass: Bool = false, hasUpdateBanner: Bool = false, mac: Bool = false,
                     isLandscapePhone: Bool = false, onlyMerged: Bool? = nil) -> LayoutPlan {
        var p = LayoutPlan()
        p.layout = layout
        p.k = min(max(k, 1), maxK)
        let k = p.k
        p.mac = mac
        p.noCompass = noCompass
        p.locked = locked
        p.hasSpot = hasSpot
        p.accessibilityText = accessibilityText
        p.tablet = min(w, h) >= tabletSide
        let roomy = mac || p.tablet
        p.margin = roomy ? marginTablet : marginPhone
        p.topInset = mac ? macInset : top
        p.bottomInset = (roomy ? bottomLarge : bottomPhone) * k
        p.headerHeight = headerHeight(k: k, tablet: p.tablet)
        p.readoutScale = layout.readoutScale
        p.headingSize = (p.tablet ? headingTablet : heading) * layout.readoutScale
        // The status line may wrap only at k > 1.1, or for the no-compass note.
        p.statusLines = noCompass || k > 1.1 ? 2 : 1
        p.gapHeaderDial = headerToDial * k
        p.gapDialReadout = dialToReadout * k
        p.gapReadoutStatus = readoutToStatus * k
        p.gapStatusRows = statusToRows * k
        p.gapRows = rowGap * k
        p.gapGridMap = gridToMap * k
        p.tileHeight = (p.tablet ? tileTablet : tile) * k

        let banner: CGFloat = hasUpdateBanner ? Self.banner + bannerGap : 0
        let group = groupHeight(headingSize: p.headingSize, k: k, statusLines: p.statusLines)
        // The rows above the grid: the lock row and the spot row, each with the 8 under it; merged, one 44 row.
        func above(merged: Bool) -> CGFloat {
            if merged { return locked || hasSpot ? mergedHeight(k: k) + p.gapRows : 0 }
            return (locked ? lockHeight(k: k) + p.gapRows : 0) + (hasSpot ? spotHeight(k: k) + p.gapRows : 0)
        }
        // The same arguments for a neighbouring layout.
        func neighbour(_ l: Layout) -> LayoutPlan {
            plan(w: w, h: h, s: s, layout: l, k: k, accessibilityText: accessibilityText, hasSpot: hasSpot, locked: locked,
                 noCompass: noCompass, hasUpdateBanner: hasUpdateBanner, mac: mac, isLandscapePhone: isLandscapePhone)
        }

        func listPlan() -> LayoutPlan {
            var l = p
            l.list = true
            l.twoPane = false
            l.trailingWidth = 0
            l.merged = false
            l.columns = 3
            l.columnWidth = min(w - 2 * l.margin, l.tablet ? maxColumnTablet : maxColumn)
            let full = l.columnWidth + 2 * l.margin
            l.grid = .list
            l.map = .card
            l.mapHeight = listMap
            l.tileHeight = listRow * k
            l.topExtra = 0
            l.bottomSpare = 0
            l.centred = false
            l.used = 0
            // The dial: min(W − 48, 0.36 H), smaller still where that brings the Position and Elevation rows
            // above the fold with 24 to spare (C3.4 #6), but never under 120. Short of the accessibility
            // sizes (the list as the last resort), never under the owner's min(0.40 H, the width cap) either.
            let targetLines: CGFloat = (locked ? 1 : 0) + (hasSpot ? 1 : 0)
            let targets = targetLines > 0 ? targetsHeight(k: k, lines: targetLines) + l.gapRows : 0
            let rest = l.topInset + l.headerHeight + banner + l.gapHeaderDial + l.gapDialReadout + group + l.gapStatusRows
                + targets + 2 * l.tileHeight + l.gapRows
            l.floor = accessibilityText ? dialMin : max(dialMin, min(ownerShare * h, full - 2 * layout.e))
            l.dial = max(l.floor, min(full - largeTextInset, largeTextShare * h, s - maxSpare - rest))
            l.dialCap = max(l.floor, min(full - largeTextInset, largeTextShare * h))
            l.share = l.dial / h
            l.gridTop = rest - 2 * l.tileHeight - l.gapRows + l.dial
            l.listFold = l.gridTop + l.tileHeight
            l.listFold2 = l.listFold + l.gapRows + l.tileHeight
            return l
        }

        // Accessibility sizes: the whole screen is one scrolling list (§3.6).
        if accessibilityText { return listPlan() }

        // Two panes (§3.5, C3.4 #5): wide windows, and phones on their side. One header across the top;
        // the dial and readout centred in the leading pane; the rows, the grid and the map card in the
        // trailing pane.
        if isLandscapePhone || (w > h && (w >= twoPaneWidth || s < landscapePhone)) {
            p.twoPane = true
            let trailing = min(max(layout.paneShare * w, paneMin), paneMax)
            p.trailingWidth = trailing
            p.columnWidth = trailing - p.margin
            p.columns = trailing >= paneColumns3 ? 3 : 2
            let below = s - p.topInset - p.headerHeight - banner - p.gapHeaderDial - p.bottomInset
            let rest = p.gapDialReadout + group
            var dial = min(w - trailing - 2 * p.margin, below - rest)
            // Each layout's share of H, so the four dials differ (Small 0.36, Medium 0.48, Large 0.54,
            // Extra Large 0.64).
            if p.tablet || mac || layout == .small { dial = min(dial, layout.tabletShare * h) }
            if k >= largeTextK { dial = min(dial, largeTextShare * h) }
            if dial < dialMin { return listPlan() }
            p.dial = dial
            p.floor = dial
            p.dialCap = dial
            p.share = dial / h
            // Fixed rows: 80 (96 on a tablet), never stretched.
            let row = (p.tablet ? tileTablet : tilePane) * k
            p.tileHeight = row
            p.grid = layout.compactRow ? .compact : (layout == .large ? .twoByTwo : .full)
            // A narrow trailing pane (Extra Large's 40% of a 900 window): the compact row's Position would be
            // too narrow for a longitude at this text size, so the pane takes the 2 × 2 instead, where it fits.
            let positionWidth: CGFloat = compactWidths(p.columnWidth).position
            let quadHeight: CGFloat = above(merged: false) + 2 * row + p.gapRows
            if p.grid == .compact && positionWidth < positionNeed(k: k, tablet: p.tablet) - 0.5 && quadHeight <= below + 0.5 {
                p.grid = .twoByTwo
            }
            let gridRows: CGFloat = p.grid == .compact ? 1 : 2
            var used = above(merged: false) + gridRows * row + (gridRows - 1) * p.gapRows
            let forMap = below - used - p.gapGridMap
            switch layout {
            case .large, .extraLarge:
                p.map = .button
            case .small, .medium:
                let minCard = p.tablet ? mapPaneTablet : (layout == .small ? mapMin : mapPromote)
                if forMap >= minCard {
                    // The rest of the pane is the map card.
                    p.map = .card
                    p.mapHeight = forMap
                    used = below
                } else if layout == .medium {
                    // 3 columns: the Map tile sits in row 2; 2 columns: its own row, spanning both.
                    p.map = .tile
                    if p.columns == 2 { used += p.gapRows + row }
                } else {
                    p.map = .button
                }
            }
            p.used = used
            if used > below + 0.5 { p.trailingScrolls = true }
            // Large and Extra Large centre their short stack; Small and Medium start at the top and fill.
            if layout == .large || layout == .extraLarge || p.map != .card {
                p.trailingInset = max(0, (below - used) / 2)
            }
            p.bottomSpare = max(0, below - used - p.trailingInset)
            return p
        }

        // One column, C = min(W − 2 × margin, 640; 720 on iPad), centred. Extra Large on a tablet widens it
        // to its dial.
        var c = min(w - 2 * p.margin, p.tablet ? maxColumnTablet : maxColumn)
        if p.tablet && layout == .extraLarge { c = min(w - 2 * p.margin, max(c, layout.tabletShare * h)) }
        p.columnWidth = c
        let full = c + 2 * p.margin
        // One column keeps the owner's 0.40 H at Text Size 1.3 too, so the caps don't narrow there.
        func widthCap(_ l: Layout) -> CGFloat { full - 2 * l.e }
        func cap(_ l: Layout) -> CGFloat {
            var limit = widthCap(l)
            if l == .small { limit = min(limit, smallShare * h) } else if p.tablet { limit = min(limit, l.tabletShare * h) }
            return limit
        }
        func gridHeight(_ g: Grid) -> CGFloat { g == .compact ? p.tileHeight : 2 * p.tileHeight + p.gapRows }
        func fixed(_ g: Grid, card: Bool, merged: Bool) -> CGFloat {
            p.topInset + p.headerHeight + banner + p.gapHeaderDial + p.gapDialReadout + group + p.gapStatusRows
                + above(merged: merged) + gridHeight(g) + (card ? p.gapGridMap : 0) + p.bottomInset
        }
        func gridTop(_ dial: CGFloat, merged: Bool) -> CGFloat {
            p.topInset + p.headerHeight + banner + p.gapHeaderDial + p.topExtra + dial + p.gapDialReadout + group
                + p.gapStatusRows + above(merged: merged)
        }
        p.dialCap = cap(layout)
        // The owner's rule: the dial is never under min(0.40 H, its cap).
        p.floor = min(layout.floorShare * h, p.dialCap)
        // The last thing given up before the list: the lock and spot rows become one 44 row.
        let merges: [Bool] = locked || hasSpot ? [false, true] : [false]

        if layout == .small {
            // Small: the compact row, the dial at 0.40 H (its floor), and a map card taking all the spare (140
            // or more). Short of that the card shrinks to a map tile (a strip as wide as the column, a tile
            // high or more: `mapStrip`), then the map moves to the header button, then the rows merge, then
            // the list. (As on Android.)
            p.grid = .compact
            p.dial = p.dialCap
            p.share = p.dial / h
            for merged in merges {
                p.merged = merged
                let avail = s - fixed(.compact, card: true, merged: merged)
                if avail - p.dial >= p.tileHeight - 0.5 {
                    p.map = .card
                    p.mapHeight = avail - p.dial
                    p.used = s
                    p.gridTop = gridTop(p.dial, merged: merged)
                    return p
                }
                let spare = s - fixed(.compact, card: false, merged: merged) - p.dial
                if spare >= -0.5 {
                    p.map = .button
                    p.mapHeight = 0
                    p.topExtra = min(maxSpare, max(0, spare) / 2)
                    p.bottomSpare = min(maxSpare, max(0, spare) - p.topExtra)
                    let over = max(0, spare - p.topExtra - p.bottomSpare)
                    if over > 0.5 { p.centred = true }
                    p.topExtra += over / 2
                    p.bottomSpare += over / 2
                    p.used = s
                    p.gridTop = gridTop(p.dial, merged: merged)
                    return p
                }
            }
            return listPlan()
        }

        // The stages each layout may take, in the owner's order: its own grid and map, then (Medium and
        // Large) the compact row with the map in the header, then each again with the rows merged.
        let grids: [(Grid, Map)]
        switch layout {
        case .medium: grids = [(.full, .tile), (.compact, .button)]
        case .large: grids = [(.twoByTwo, .button), (.compact, .button)]
        default: grids = [(.compact, .button)]
        }
        // Medium stays 16 under Large (unless at its floor); Large is never over Extra Large's best dial on
        // this screen (Extra Large probed with the rows separate and merged), so Extra Large stays the largest.
        let large = layout == .medium ? neighbour(.large) : nil
        var extraLargeBest: CGFloat?
        if layout == .large {
            var best = p.floor
            for merged in merges {
                let x = plan(w: w, h: h, s: s, layout: .extraLarge, k: k, accessibilityText: accessibilityText, hasSpot: hasSpot,
                             locked: locked, noCompass: noCompass, hasUpdateBanner: hasUpdateBanner, mac: mac,
                             isLandscapePhone: isLandscapePhone, onlyMerged: merged)
                if !x.list && !x.twoPane { best = max(best, x.dial) }
            }
            extraLargeBest = best
        }
        // What each layout wants before it stops giving things up (as on Android): Small and Medium the floor;
        // Large 16 over it (a step over Medium); Extra Large at least Large's dial (it merges the rows for that
        // where it must). Never more than Large's limit.
        var want = p.floor
        if onlyMerged == nil {
            switch layout {
            case .large: want = min(p.floor + layoutStep, widthCap(.large))
            case .extraLarge:
                let l = neighbour(.large)
                if !l.list && !l.twoPane { want = max(p.floor, l.dial) }
            default: break
            }
        }
        if let extraLargeBest { want = min(want, extraLargeBest) }
        // The first stage that gives the layout what it wants; failing that, the stage with the biggest dial
        // still at the floor; failing that, the list.
        var chosen: (grid: Grid, map: Map, merged: Bool, dial: CGFloat)?
        var fallback: (grid: Grid, map: Map, merged: Bool, dial: CGFloat)?
        stages: for merged in merges where onlyMerged == nil || onlyMerged == merged {
            for (grid, surface) in grids {
                var d = min(p.dialCap, s - fixed(grid, card: false, merged: merged))
                if let large, !large.list && !large.twoPane { d = min(d, max(p.floor, large.dial - layoutStep)) }
                if let extraLargeBest { d = min(d, extraLargeBest) }
                if d < p.floor - 0.5 { continue }
                if d >= want - 0.5 {
                    chosen = (grid, surface, merged, d)
                    break stages
                }
                if d > (fallback?.dial ?? -.infinity) + 0.5 { fallback = (grid, surface, merged, d) }
            }
        }
        if chosen == nil { chosen = fallback }
        guard let chosen else { return listPlan() }
        let g = chosen.grid
        var map = chosen.map
        var dial = chosen.dial
        p.merged = chosen.merged
        var spare = max(0, s - fixed(g, card: false, merged: p.merged) - dial)
        var grow: CGFloat = 0
        if layout == .medium && map == .tile {
            if spare >= mapPromote * k {
                // A map card (200 or more, taken from the dial down to its floor).
                map = .card
                p.mapHeight = spare - p.gapGridMap
                if p.mapHeight < mapPromoted * k {
                    let take = min(mapPromoted * k - p.mapHeight, max(0, dial - p.floor))
                    dial -= take
                    p.mapHeight += take
                }
                spare = 0
            } else if !p.tablet {
                // Taller tiles: 72 → 88 (iPad's 96 tiles don't grow).
                grow = max(0, min((tileGrown - tile) * k, spare / 2))
                spare -= 2 * grow
            }
        }
        // More than the tiles and the two 24s can take, and a card of 140 fits: Medium's map becomes a card
        // after all (its tiles back to 72), as on Android.
        if layout == .medium && map == .tile && spare > 2 * maxSpare + 0.5 && spare + 2 * grow - p.gapGridMap >= mapMin {
            map = .card
            p.mapHeight = spare + 2 * grow - p.gapGridMap
            grow = 0
            spare = 0
        }
        // Up to 24 under the header and up to 24 at the bottom.
        p.topExtra = min(maxSpare, spare / 2)
        p.bottomSpare = min(maxSpare, spare - p.topExtra)
        var over = max(0, spare - p.topExtra - p.bottomSpare)
        if over > 0.5 {
            // Still spare: the dial grows to its width cap (past a tablet's share of H), staying 16 under
            // the next layout's; the rest centres the panel.
            // (Medium stays 16 under Large; Large never passes Extra Large's best dial.)
            var limit = widthCap(layout)
            if let large, !large.list && !large.twoPane { limit = min(limit, large.dial - layoutStep) }
            if let extraLargeBest { limit = min(limit, extraLargeBest) }
            let add = max(0, min(over, limit - dial))
            dial += add
            over -= add
            if over > 0.5 { p.centred = true }
            p.topExtra += over / 2
            p.bottomSpare += over / 2
        }
        p.grid = g
        p.map = map
        p.dial = dial
        p.share = dial / h
        let gridRows: CGFloat = g == .compact ? 1 : 2
        // (fixed() counts the tiles at their base height; the growth is added here.)
        p.used = fixed(g, card: map == .card, merged: p.merged) + dial + p.mapHeight + grow * gridRows + p.topExtra + p.bottomSpare
        p.gridTop = gridTop(dial, merged: p.merged)
        p.tileHeight += grow
        return p
    }

    // MARK: The golden table (Cycle 3 §C3.3 and §C3.4's tests)

    /// A device in the planner's table: width, full height, safe height, and whether it is a Mac window.
    struct Device { let name: String; let w: CGFloat; let h: CGFloat; let s: CGFloat; var mac = false }

    /// The devices the self-tests and unit tests run the planner on. Safe heights are the usual insets.
    static let devices: [Device] = [
        Device(name: "iPhone SE", w: 375, h: 667, s: 647),
        Device(name: "iPhone 16", w: 393, h: 852, s: 759),
        Device(name: "iPhone 16 Pro", w: 402, h: 874, s: 778),
        Device(name: "iPhone 17 Pro Max", w: 440, h: 956, s: 862),
        Device(name: "Android 360x640", w: 360, h: 640, s: 640 - 24 - 48),
        Device(name: "Pixel 7", w: 412, h: 915, s: 915 - 52 - 24),
        Device(name: "iPad mini portrait", w: 744, h: 1133, s: 1089),
        Device(name: "iPad 11 portrait", w: 834, h: 1210, s: 1166),
        Device(name: "iPad 13 portrait", w: 1032, h: 1376, s: 1332),
        Device(name: "iPad 11 landscape", w: 1210, h: 834, s: 790),
        Device(name: "iPad 13 landscape", w: 1376, h: 1032, s: 988),
        Device(name: "Mac 420x780", w: macMinWidth, h: macMinHeight, s: macMinHeight, mac: true),
        Device(name: "Mac 420x840", w: 420, h: 840, s: 840, mac: true),
        Device(name: "Mac 900x700", w: 900, h: 700, s: 700, mac: true),
        Device(name: "Mac 1200x800", w: 1200, h: 800, s: 800, mac: true),
        Device(name: "Phone landscape", w: 852, h: 393, s: 372),
    ]

    /// The states of §4.7 and C3.3: nothing (live), locked, marked, both (the sample).
    static let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    /// Runs the whole table (devices × layouts × states × compass or not × text sizes × banner) and returns
    /// the cases that break a rule (C3.3's shared tests, and the owner's rule: in one column, portrait, short
    /// of the accessibility sizes, a dial under min(0.40 H, its width cap) fails, as does Large not over
    /// Medium or Extra Large under Large): a gap that isn't its token × k, a header not at the
    /// safe top + 8, more than 24 left empty at the bottom (unless the panel is centred), a block partly
    /// visible, the dial under its floor or over its cap, a tile taller than its cap, a map card under 140,
    /// a row whose widths and gutters don't add up to C, neighbouring layouts with the same grid (or, Medium
    /// and Large, the same map surface, or Large's dial not 16 over Medium's), four landscape plans that
    /// aren't four, and at Text Size 1.3 in the list the Position row under the fold. Then the worked
    /// numbers. Empty when all is well.
    static func tableFailures() -> [String] {
        var failures: [String] = []
        for d in devices {
            for state in states {
                for (k, acc) in [(CGFloat(1), false), (1.3, false), (1.3, true)] {
                    for banner in [false, true] where !banner || d.mac {
                        for noCompass in [false, true] {
                            // No compass: no heading, so nothing can be locked.
                            if noCompass && state.locked { continue }
                            var plans: [LayoutPlan] = []
                            for layout in Layout.allCases {
                                let p = plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, accessibilityText: acc,
                                             hasSpot: state.spot, locked: state.locked, noCompass: noCompass,
                                             hasUpdateBanner: banner, mac: d.mac)
                                plans.append(p)
                                let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)\(acc ? " acc" : "")\(banner ? " banner" : "")\(noCompass ? " no compass" : "")"
                                failures += check(p, device: d, name: name)
                            }
                            // Neighbours at Text Size 1.0, and in one column at 1.3 too (the owner's rule holds
                            // there); two panes at 1.3 share the large-text dial and are left out.
                            guard !acc, !banner, k == 1 || !plans.contains(where: \.twoPane) else { continue }
                            failures += distinct(plans, name: "\(d.name) \(state.name) k\(k)\(noCompass ? " no compass" : "")")
                        }
                    }
                }
            }
        }
        // The worked numbers: iPhone 16 Pro, 402 × 874, S = 778, C = 370, floor 0.40 H = 350. With the sample
        // (locked + marked) every layout gives up its grid or map card to keep the owner's 0.40 H: Small 350,
        // Medium 370, Large 386, Extra Large 386, all on the compact row with the map in the header.
        let medium = plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        let large = plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        let xl = plan(w: 402, h: 874, s: 778, layout: .extraLarge, hasSpot: true, locked: true)
        let small = plan(w: 402, h: 874, s: 778, layout: .small, hasSpot: true, locked: true)
        if abs(small.dial - 350) > 1 || abs(medium.dial - 370) > 1 || abs(large.dial - 386) > 1 || abs(xl.dial - 386) > 1 {
            failures.append("16 Pro sample dials: \(Int(small.dial)) / \(Int(medium.dial)) / \(Int(large.dial)) / \(Int(xl.dial)), expected 350 / 370 / 386 / 386")
        }
        if medium.grid != .compact || medium.map != .button || large.grid != .compact || large.map != .button || medium.merged || large.merged {
            failures.append("16 Pro sample: Medium and Large should give up their grids (the compact row), not merge the rows")
        }
        if xl.grid != .compact || xl.map != .button || abs(xl.readoutScale - 1.25) > 0.001 {
            failures.append("16 Pro Extra Large sample: expected the compact row, the header map button and a 1.25 readout")
        }
        if small.map != .button || small.list {
            failures.append("16 Pro Small sample: expected the map in the header (no 140 card fits at 0.40 H)")
        }
        // Live (nothing locked or marked) the four keep their own grids: Small 350 with a 174 card, Medium
        // 370 with the 3 columns and Map tile, Large 386 on 2 × 2, Extra Large 386 on the compact row.
        let liveSmall = plan(w: 402, h: 874, s: 778, layout: .small)
        let liveMedium = plan(w: 402, h: 874, s: 778)
        let liveLarge = plan(w: 402, h: 874, s: 778, layout: .large)
        if liveSmall.map != .card || liveSmall.mapHeight < mapMin - 0.5 || abs(liveSmall.dial - 0.40 * 874) > 1
            || liveMedium.grid != .full || liveMedium.map != .tile || liveLarge.grid != .twoByTwo
            || liveLarge.dial < liveMedium.dial + layoutStep - 0.5 {
            failures.append("16 Pro live: Small \(liveSmall.description); Medium \(liveMedium.description); Large \(liveLarge.description)")
        }
        // The compact row at C = 370, 380 and 700: 146 | 104 | 104, 156 | 104 | 104, 306 | 189 | 189.
        let w370 = compactWidths(370), w380 = compactWidths(380), w700 = compactWidths(700)
        if w370.position != 146 || w370.other != 104 || w380.position != 156 || w380.other != 104
            || w700.position != 306 || w700.other != 189 {
            failures.append("Compact row widths: \(w370) at 370, \(w380) at 380, \(w700) at 700")
        }
        // iPad portrait, Medium, nothing locked: the map is a card of 200 or more (C3.4 #10).
        let ipad = plan(w: 834, h: 1210, s: 1166)
        if ipad.map != .card || ipad.mapHeight < mapPromoted - 0.5 {
            failures.append("iPad 11 portrait Medium: map \(ipad.map) \(Int(ipad.mapHeight)), expected a card of 200 or more")
        }
        // The smallest Mac window holds every layout with the sample without scrolling (at 0.40 H or more).
        for layout in Layout.allCases where plan(w: macMinWidth, h: macMinHeight, s: macMinHeight, layout: layout,
                                                 hasSpot: true, locked: true, mac: true).list {
            failures.append("Mac \(Int(macMinWidth)) × \(Int(macMinHeight)): \(layout.rawValue) scrolls")
        }
        if plan(w: 393, h: 852, s: 759).layout != .medium || Layout.of(nil) != .medium || Layout.of("bogus") != .medium {
            failures.append("Medium is not the default")
        }
        return failures
    }

    /// One plan's rules.
    private static func check(_ p: LayoutPlan, device d: Device, name: String) -> [String] {
        var failures: [String] = []
        let k = p.k
        // The header is pinned at the safe top + 8 (24 from a Mac window's edge), in every layout and state.
        if abs(p.topInset - (d.mac ? macInset : top)) > 0.01 { failures.append("\(name): header at \(p.topInset)") }
        if d.mac && (p.margin < macInset - 0.5 || p.bottomInset < macInset - 0.5) {
            failures.append("\(name): Mac edges \(Int(p.margin)) / \(Int(p.topInset)) / \(Int(p.bottomInset)), expected 24")
        }
        // The owner's hard rule: in one column, portrait (phones, iPad portrait, Mac windows taller than wide),
        // short of the accessibility sizes, the dial is at least min(0.40 H, its width cap), in the list too.
        if !p.twoPane && !p.accessibilityText && d.h >= d.w && p.dial < p.ownerFloor(h: d.h) - 0.5 {
            failures.append("\(name): dial \(Int(p.dial)) is \(Int((100 * p.dial / d.h).rounded()))% of H, under the owner's floor \(Int(p.ownerFloor(h: d.h)))")
        }
        // Every gap is its token × k.
        let gaps: [(CGFloat, CGFloat, String)] = [
            (p.gapHeaderDial, headerToDial, "header → dial"), (p.gapDialReadout, dialToReadout, "dial → readout"),
            (p.gapReadoutStatus, readoutToStatus, "readout → status"), (p.gapStatusRows, statusToRows, "status → rows"),
            (p.gapRows, rowGap, "rows"), (p.gapGridMap, gridToMap, "grid → map"),
        ]
        for (gap, token, what) in gaps where abs(gap - token * k) > 0.01 {
            failures.append("\(name): \(what) is \(gap), not \(token) × \(k)")
        }
        // Every row's widths and gutters add up to C (C2.2 #1).
        for row in p.rowWidths {
            let sum = row.reduce(0, +) + CGFloat(row.count - 1) * rowGap
            if abs(sum - p.columnWidth) > 0.5 { failures.append("\(name): a row is \(Int(sum)) wide in a column of \(Int(p.columnWidth))") }
            if p.grid == .compact && row.contains(where: { $0 < compactMin - 0.5 }) {
                failures.append("\(name): a compact tile under \(Int(compactMin))")
            }
        }
        if p.list {
            if p.dial < dialMin - 0.5 { failures.append("\(name): list dial \(Int(p.dial))") }
            // At Text Size 1.3 the Position row is whole above the fold, and Elevation too wherever the dial
            // could give way (C3.4 #6); not on a phone on its side, which is all fold, and not where the
            // dial is held at the owner's 0.40 H (the owner's rule comes first).
            let held = !p.accessibilityText && p.dial <= p.floor + 0.5
            if d.s >= landscapePhone && !held && p.listFold > d.s + 0.5 { failures.append("\(name): the Position row ends \(Int(p.listFold - d.s)) under the fold") }
            if d.s >= landscapePhone && !held && p.dial > dialMin + 0.5 && p.listFold2 > d.s + 0.5 {
                failures.append("\(name): the Elevation row ends \(Int(p.listFold2 - d.s)) under the fold")
            }
            return failures
        }
        if (p.layout == .large || p.layout == .extraLarge) && p.map != .button {
            failures.append("\(name): \(p.layout.rawValue) shows the map as \(p.map)")
        }
        if p.map == .card && p.mapHeight < mapMin - 0.5 && !(p.mapStrip && p.mapHeight >= p.tileHeight - 0.5) {
            failures.append("\(name): map card \(Int(p.mapHeight))")
        }
        if p.grid == .compact && p.map == .tile { failures.append("\(name): the compact row has no Map tile") }
        if p.twoPane {
            if p.dial < dialMin - 0.5 { failures.append("\(name): two panes, dial \(Int(p.dial))") }
            let rowCap = (p.tablet ? tileTablet : tilePane) * k
            if p.tileHeight > rowCap + 0.5 { failures.append("\(name): two panes, tiles \(Int(p.tileHeight)) over \(Int(rowCap))") }
            if !p.trailingScrolls && p.map == .card && p.bottomSpare > maxSpare + 0.5 {
                failures.append("\(name): two panes, \(Int(p.bottomSpare)) empty under the map card")
            }
            return failures
        }
        if p.bottomSpare > maxSpare + 0.5 && !p.centred { failures.append("\(name): \(Int(p.bottomSpare)) empty at the bottom") }
        if p.centred && abs(p.topExtra - p.bottomSpare) > 0.5 { failures.append("\(name): centred, but \(Int(p.topExtra)) over and \(Int(p.bottomSpare)) under") }
        if p.used > d.s + 0.5 { failures.append("\(name): \(Int(p.used - d.s)) cut off") }
        if p.used < d.s - 0.5 { failures.append("\(name): \(Int(d.s - p.used)) unaccounted for") }
        if p.dial + 0.5 < p.floor { failures.append("\(name): dial \(Int(p.dial)) under its floor \(Int(p.floor))") }
        let widthCap = p.columnWidth + 2 * p.margin - 2 * p.layout.e
        if p.dial > widthCap + 0.5 { failures.append("\(name): dial \(Int(p.dial)) over its cap \(Int(widthCap))") }
        let grownCap = (p.tablet ? tileTablet : tileGrown) * k
        if p.tileHeight > grownCap + 0.5 { failures.append("\(name): tiles \(Int(p.tileHeight)) over \(Int(grownCap))") }
        // Only Medium grows its tiles.
        if p.layout != .medium && abs(p.tileHeight - (p.tablet ? tileTablet : tile) * k) > 0.5 {
            failures.append("\(name): \(p.layout.rawValue) tiles \(Int(p.tileHeight))")
        }
        return failures
    }

    /// Neighbouring layouts differ (C3.2 #2): in grid mode, unless one of them gave up its own grid or map
    /// to keep the owner's 0.40 H (`yielded`); Medium and Large also in map surface (same exception), with
    /// Large's dial 16 or more over Medium's unless Medium is at its floor, and over it in any case (unless
    /// Extra Large itself is held at the floor, where the three share it). Extra Large's dial is the largest.
    /// In two panes (landscape) the four plans are four different plans.
    private static func distinct(_ plans: [LayoutPlan], name: String) -> [String] {
        var failures: [String] = []
        let panel = plans.filter { !$0.list }
        if panel.count == plans.count && plans.allSatisfy(\.twoPane) {
            for (i, a) in plans.enumerated() {
                for b in plans.dropFirst(i + 1) where a.grid == b.grid && a.map == b.map && abs(a.dial - b.dial) < layoutStep - 0.5 {
                    failures.append("\(name) landscape: \(a.layout.rawValue) and \(b.layout.rawValue) are the same plan")
                }
            }
            return failures
        }
        // (Extra Large held at the floor: on its compact row, or as the list it fell back to.)
        let xlHeld = plans.last.map { !$0.twoPane && $0.dial <= $0.floor + 0.5 } ?? false
        for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
            // Under the owner's floor a layout gives up its grid or map (C3.3's pressure order, then the
            // owner's rule), and neighbours may then match; that is the one allowed match.
            let yielded = a.yielded || b.yielded
            if a.grid == b.grid && !yielded {
                failures.append("\(name): \(a.layout.rawValue) and \(b.layout.rawValue) have the same grid")
            }
            if b.dial < a.dial - 0.5 {
                failures.append("\(name): \(b.layout.rawValue)'s dial \(Int(b.dial)) is under \(a.layout.rawValue)'s \(Int(a.dial))")
            }
            if a.layout == .medium {
                if a.map == b.map && !yielded { failures.append("\(name): Medium and Large show the map the same way") }
                if b.dial < a.dial + layoutStep - 0.5 && a.dial > a.floor + 0.5 {
                    failures.append("\(name): Large's dial \(Int(b.dial)) is not 16 over Medium's \(Int(a.dial))")
                }
                if b.dial < a.dial + 0.5 && !xlHeld {
                    failures.append("\(name): Large's dial \(Int(b.dial)) is not over Medium's \(Int(a.dial))")
                }
            }
        }
        return failures
    }

    /// One line per layout for a device and state: "medium: dial 358 (43% of H), 3-column grid, map tile,
    /// tiles 80, bottom 0". For the self-tests' reports.
    static func summary(w: CGFloat, h: CGFloat, s: CGFloat, hasSpot: Bool, locked: Bool, noCompass: Bool = false,
                        mac: Bool = false) -> [String] {
        Layout.allCases.map { layout in
            let p = plan(w: w, h: h, s: s, layout: layout, hasSpot: hasSpot, locked: locked, noCompass: noCompass, mac: mac)
            return "\(layout.rawValue): \(p.description)"
        }
    }

    /// "dial 358 (43% of H), 3-column grid, map tile, tiles 80, bottom 0".
    var description: String {
        let gridText: String
        switch grid {
        case .full: gridText = "3-column grid"
        case .twoByTwo: gridText = "2 × 2 grid"
        case .compact: gridText = "compact row"
        case .list: gridText = "list"
        }
        let mapText: String
        switch map {
        case .tile: mapText = "map tile"
        case .card: mapText = mapStrip ? "map tile \(Int(mapHeight.rounded()))" : "map card \(Int(mapHeight.rounded()))"
        case .button: mapText = "map in header"
        }
        let dialText = "dial \(Int(dial.rounded())) (\(Int((100 * share).rounded()))% of H)"
        if list { return "\(dialText), scrolling list" }
        let foot = twoPane ? "pane spare \(Int(bottomSpare.rounded()))" : "bottom \(Int(bottomSpare.rounded()))\(centred ? " (centred)" : "")"
        return "\(dialText), \(gridText), \(mapText)\(merged ? ", rows merged" : ""), tiles \(Int(tileHeight.rounded())), \(foot)"
    }
}
