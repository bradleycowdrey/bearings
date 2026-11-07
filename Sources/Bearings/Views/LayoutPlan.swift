import CoreGraphics

/// The four layouts (docs/REFINE.md §3.4, the owner's decision): Small "Compass and map", Medium
/// "Balanced" (the default), Large "Bigger compass" and Extra Large "Biggest compass". Saved under
/// "layout" as the raw value; anything else reads as Medium. (This shadows SwiftUI's `Layout` protocol
/// inside the app, which Bearings doesn't use.)
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

    /// The one-line subtitle under the name in the Layout menu.
    var subtitle: String {
        switch self {
        case .small: "Compass and map"
        case .medium: "Balanced"
        case .large: "Bigger compass"
        case .extraLarge: "Biggest compass"
        }
    }

    /// The symbol beside the name in the Layout menu.
    var symbol: String {
        switch self {
        case .small: "map"
        case .medium: "square.grid.2x2"
        case .large: "safari"
        case .extraLarge: "location.north.circle"
        }
    }

    /// The dial's side margin, from the column's outer edge (the screen's edge on a phone): the dial's
    /// cap is the column plus its margins, less 2e.
    var e: CGFloat {
        switch self {
        case .small, .medium: 16
        case .large: 12
        case .extraLarge: 8
        }
    }

    /// The dial's floor, as a share of the full height H. Below it the planner gives things up (§3.3).
    var floorShare: CGFloat {
        switch self {
        case .small: 0.30
        case .medium: 0.38
        case .large, .extraLarge: 0.42
        }
    }

    /// Multiplies the heading number and its point letters.
    var readoutScale: CGFloat {
        switch self {
        case .small, .medium: 1
        case .large: 1.08
        case .extraLarge: 1.15
        }
    }

    /// Small and Extra Large start with the compact row (Position, Elevation, Sun).
    var compactRow: Bool { self == .small || self == .extraLarge }

    /// Two panes: the trailing pane's share of the width (a narrower pane leaves the dial more room).
    var paneShare: CGFloat {
        switch self {
        case .small: 0.48
        case .medium: 0.42
        case .large, .extraLarge: 0.36
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

/// The "Instrument panel" planner (docs/REFINE.md §3.3): one pure function with no UI code, the same
/// constants and order as android/.../ui/LayoutPlan.kt. It works bottom-up: the fixed blocks are placed
/// first, the dial takes what is left up to its cap, and any spare height then becomes a map card, taller
/// tiles and wider gaps, so no more than 24 is ever left empty at the bottom and nothing is cut. Every
/// length is in points.
///
/// From top to bottom: header bar → dial → readout → status line (and lock chip) → spot row → tile grid →
/// map card (only where it fits whole).
struct LayoutPlan: Equatable {
    /// The tile grid: two rows (Position 2u | Elevation, then Sun | Moon | Map), the compact row
    /// (Position 2u | Elevation | Sun), or full-width rows in the scrolling list.
    enum Grid: Equatable { case full, compact, list }
    /// Where the map is: a tile in the grid, a full-width card, or a button in the header (map sheet).
    enum Map: Equatable { case tile, card, button }

    var layout: Layout = .default
    var twoPane = false
    /// The whole screen scrolls as one list (accessibility text sizes, or nothing fits even at the floor).
    var list = false
    /// An iPad (or a Mac window as large): header 52, heading 64, margins 20.
    var tablet = false
    /// The text multiplier (Text Size, 1…1.3).
    var k: CGFloat = 1
    var margin: CGFloat = 16
    /// The grid's width: the column C (single column) or the trailing pane's content (two panes).
    var columnWidth: CGFloat = 0
    /// Two panes: the trailing pane's width (its content plus the right margin). 0 in a single column.
    var trailingWidth: CGFloat = 0
    /// The grid's columns: 3, or 2 in a trailing pane narrower than 360.
    var columns = 3
    var dial: CGFloat = 0
    var floor: CGFloat = 0
    /// The dial as a share of the full height H.
    var share: CGFloat = 0
    var readoutScale: CGFloat = 1
    /// The heading number's size: 56 (64 on a tablet) × the readout scale.
    var headingSize: CGFloat = 56
    var headerHeight: CGFloat = 48
    var statusLines: CGFloat = 1
    var grid: Grid = .full
    var map: Map = .tile
    /// The map card's height (0 unless `map == .card`).
    var mapHeight: CGFloat = 0
    /// 72 × k, grown up to 88 × k when height is spare.
    var tileHeight: CGFloat = 72
    var gapHeaderDial: CGFloat = 12
    var gapDialReadout: CGFloat = 12
    var gapGroupGrid: CGFloat = 16
    /// Spare placed above the header (with the 4 under the safe area).
    var topExtra: CGFloat = 0
    /// Spare left under the grid or map (with the 8 above the safe area). Never more than 24.
    var bottomSpare: CGFloat = 0
    /// Two panes: the trailing pane's top inset, so it lines up with the dial's top.
    var trailingInset: CGFloat = 0
    /// Two panes: the trailing pane holds more than fits and scrolls (a phone on its side).
    var trailingScrolls = false
    var showsFooter = false
    /// Everything the plan places, top to bottom (single column; the trailing pane in two panes).
    var used: CGFloat = 0

    /// The map button sits in the header only when the map is neither a tile nor a card.
    var mapInHeader: Bool { map == .button }
    /// The grid's unit width u = (C − 2 × 8) / 3 (or (C − 8) / 2 in two columns).
    var unit: CGFloat { columns == 3 ? (columnWidth - 2 * Self.rowGap) / 3 : (columnWidth - Self.rowGap) / 2 }
    /// The compact row's widths. Position (2u) | Elevation | Sun would be four units in a three-unit column,
    /// so the row splits its width less two gutters 44 / 28 / 28: Position keeps room for a full longitude,
    /// and Elevation and Sun for "9,587 ft" and "↑ 6:36 AM".
    var compactWidths: (position: CGFloat, other: CGFloat) {
        let inner = columnWidth - 2 * Self.rowGap
        return (inner * 0.44, inner * 0.28)
    }

    // MARK: Constants (points; dp on Android). Spacing tokens are 4 / 8 / 12 / 16 / 24 only.

    static let top: CGFloat = 4
    static let headerToDial: CGFloat = 12
    static let dialToReadout: CGFloat = 12
    static let readoutToStatus: CGFloat = 6
    static let statusToChip: CGFloat = 8
    static let groupToGrid: CGFloat = 16
    /// Spot row → grid, and between rows and tiles.
    static let rowGap: CGFloat = 8
    static let gridToMap: CGFloat = 12
    static let bottom: CGFloat = 8
    static let marginPhone: CGFloat = 16
    static let marginTablet: CGFloat = 20
    static let maxColumn: CGFloat = 640
    static let header: CGFloat = 48
    static let headerTablet: CGFloat = 52
    static let heading: CGFloat = 56
    static let headingTablet: CGFloat = 64
    static let readoutLine: CGFloat = 1.1
    /// The status line's 13 pt line.
    static let statusLine: CGFloat = 16
    static let chip: CGFloat = 28
    static let spotRow: CGFloat = 44
    static let tile: CGFloat = 72
    static let tileGrown: CGFloat = 88
    /// Spare at or above this (dial at its cap) turns a Map tile into a full-width card.
    static let mapPromote: CGFloat = 160
    static let mapMin: CGFloat = 140
    /// Each of the three gaps (header → dial, dial → readout, readout group → grid) may grow this much.
    static let gapGrow: CGFloat = 12
    /// The most ever left empty at the bottom (and placed above the header).
    static let maxSpare: CGFloat = 24
    /// Small's dial: 0.36 H.
    static let smallShare: CGFloat = 0.36
    /// Tablets cap the dial at 0.48 H.
    static let tabletShare: CGFloat = 0.48
    /// The scrolling list's dial: min(C − 32, 0.40 H); its map card is 200.
    static let listShare: CGFloat = 0.40
    static let listMap: CGFloat = 200
    static let dialMin: CGFloat = 120
    /// A window whose shorter side is at least this is a tablet (iPad, or a large Mac window).
    static let tabletSide: CGFloat = 700
    static let twoPaneWidth: CGFloat = 700
    static let landscapePhone: CGFloat = 480
    static let paneMin: CGFloat = 320
    static let paneMax: CGFloat = 480
    static let paneColumns3: CGFloat = 360
    /// The Mac's update banner (44) and the 8 under it.
    static let banner: CGFloat = 44
    static let bannerGap: CGFloat = 8
    /// The Mac and iPad footer: one 13 line, 12 above it.
    static let footer: CGFloat = 16
    static let footerGap: CGFloat = 12
    /// The text multiplier's cap on Apple devices.
    static let maxK: CGFloat = 1.3

    // MARK: Heights, shared with MainView so what it draws is what was planned

    static func headerHeight(k: CGFloat, tablet: Bool) -> CGFloat { (tablet ? headerTablet : header) * k }
    /// The readout: 1.1 × the heading's size.
    static func readoutHeight(headingSize: CGFloat) -> CGFloat { headingSize * readoutLine }
    static func statusHeight(k: CGFloat, lines: CGFloat) -> CGFloat { statusLine * k * lines }
    static func chipHeight(k: CGFloat) -> CGFloat { chip * k }
    static func spotHeight(k: CGFloat) -> CGFloat { spotRow * k }
    static func tileHeight(k: CGFloat) -> CGFloat { tile * k }

    // MARK: The planner

    /// `w` the window's (safe) width, `h` its full height including the safe-area insets, `s` the safe
    /// height, `k` the Text Size multiplier (capped at 1.3), `accessibilityText` an accessibility Text Size.
    /// `locked` a lock chip shows; `noCompass` the status line takes two lines for the no-compass note.
    static func plan(w: CGFloat, h: CGFloat, s: CGFloat, layout: Layout = .default, k: CGFloat = 1,
                     accessibilityText: Bool = false, hasSpot: Bool = false, locked: Bool = false,
                     noCompass: Bool = false, hasUpdateBanner: Bool = false, showsFooter: Bool = false,
                     isLandscapePhone: Bool = false) -> LayoutPlan {
        var p = LayoutPlan()
        p.layout = layout
        p.k = min(max(k, 1), maxK)
        let k = p.k
        p.tablet = min(w, h) >= tabletSide
        p.margin = p.tablet ? marginTablet : marginPhone
        p.headerHeight = headerHeight(k: k, tablet: p.tablet)
        p.readoutScale = layout.readoutScale
        p.headingSize = (p.tablet ? headingTablet : heading) * layout.readoutScale
        // The status line may wrap only at k > 1.1, or for the no-compass note.
        p.statusLines = noCompass || k > 1.1 ? 2 : 1
        p.tileHeight = tileHeight(k: k)
        p.showsFooter = showsFooter

        let banner: CGFloat = hasUpdateBanner ? Self.banner + bannerGap : 0
        // The readout group under the dial: readout, status line, lock chip.
        let group = readoutHeight(headingSize: p.headingSize) + readoutToStatus + statusHeight(k: k, lines: p.statusLines)
            + (locked ? statusToChip + chipHeight(k: k) : 0)
        let spot: CGFloat = hasSpot ? spotHeight(k: k) + rowGap : 0
        let tile = p.tileHeight

        func listPlan() -> LayoutPlan {
            var l = p
            l.list = true
            l.twoPane = false
            l.trailingWidth = 0
            l.columns = 3
            l.columnWidth = min(w - 2 * l.margin, maxColumn)
            l.dial = max(dialMin, min(l.columnWidth - 32, listShare * h))
            l.floor = l.dial
            l.share = l.dial / h
            l.grid = .list
            l.map = .card
            l.mapHeight = listMap
            l.tileHeight = tile
            l.gapHeaderDial = headerToDial
            l.gapDialReadout = dialToReadout
            l.gapGroupGrid = groupToGrid
            l.topExtra = 0
            l.bottomSpare = 0
            l.showsFooter = true
            l.used = 0
            return l
        }

        // Accessibility sizes: the whole screen is one scrolling list (§3.6).
        if accessibilityText { return listPlan() }

        // Two panes (§3.5): wide windows, and phones on their side.
        if isLandscapePhone || (w > h && (w >= twoPaneWidth || s < landscapePhone)) {
            p.twoPane = true
            let trailing = min(max(layout.paneShare * w, paneMin), paneMax)
            p.trailingWidth = trailing
            p.columnWidth = trailing - p.margin
            p.columns = trailing >= paneColumns3 ? 3 : 2
            let pane = w - trailing
            let below = s - top - p.headerHeight - banner - headerToDial - bottom
            let rest = dialToReadout + group
            let byHeight = below - rest
            if byHeight < dialMin { return listPlan() }
            p.dial = min(pane - 2 * p.margin, byHeight)
            p.floor = min(pane - 2 * p.margin, byHeight)
            p.share = p.dial / h
            // The trailing pane starts level with the dial's top (the leading group is centred).
            p.trailingInset = max(0, (below - p.dial - rest) / 2)
            let avail = below - p.trailingInset
            let footer: CGFloat = showsFooter ? footerGap + Self.footer : 0
            // Without the Map tile: 3 columns, two rows (Position | Elevation, Sun | Moon); 2 columns,
            // three (Position, Elevation | Sun, Moon).
            let rowsNoMap: CGFloat = p.columns == 3 ? 2 : 3
            let gridNoMap = rowsNoMap * tile + (rowsNoMap - 1) * rowGap
            let forMap = avail - spot - gridNoMap - footer
            if forMap >= mapPromote {
                p.map = .card
                p.mapHeight = forMap - gridToMap
                p.used = avail
                p.bottomSpare = 0
            } else {
                p.map = .tile
                // 3 columns: the Map tile sits in row 2; 2 columns: its own row, spanning both.
                let rows: CGFloat = p.columns == 3 ? 2 : 4
                let content = spot + rows * tile + (rows - 1) * rowGap + footer
                if content > avail + 0.5 {
                    p.trailingScrolls = true
                    p.used = content
                } else {
                    let grow = min((tileGrown - Self.tile) * k, (avail - content) / rows)
                    p.tileHeight = tile + grow
                    p.used = content + grow * rows
                    p.bottomSpare = max(0, avail - p.used)
                }
            }
            p.grid = .full
            return p
        }

        // One column, C = min(W − 2 × margin, 640), centred.
        let c = min(w - 2 * p.margin, maxColumn)
        p.columnWidth = c
        var cap = c + 2 * p.margin - 2 * layout.e
        if p.tablet { cap = min(cap, tabletShare * h) }
        let floor = min(layout.floorShare * h, cap)
        p.floor = floor

        func gridHeight(_ g: Grid) -> CGFloat { g == .full ? 2 * tile + rowGap : tile }
        func fixed(_ g: Grid, card: Bool) -> CGFloat {
            top + p.headerHeight + banner + headerToDial + dialToReadout + group + groupToGrid + spot
                + gridHeight(g) + (card ? gridToMap : 0) + bottom
        }

        if layout == .small {
            // Small: the compact row, and a map card filling the rest (140 or more). The dial is 0.36 H;
            // the map shrinks toward 140 first, then the dial goes down to its floor.
            p.grid = .compact
            p.map = .card
            let avail = s - fixed(.compact, card: true)
            var dial = min(cap, smallShare * h)
            if avail - dial < mapMin { dial = max(floor, avail - mapMin) }
            if avail - dial < mapMin - 0.5 { return listPlan() }
            p.dial = dial
            p.mapHeight = avail - dial
            p.share = dial / h
            p.used = s
            return p
        }

        // Medium, Large, Extra Large: the dial fills to its cap.
        var g: Grid = layout.compactRow ? .compact : .full
        var map: Map = layout == .extraLarge ? .button : .tile
        var dial = min(cap, s - fixed(g, card: false))
        if dial < floor - 0.5 && layout == .large {
            // Large gives up the second row (Map moves to the header button) before the dial shrinks.
            g = .compact
            map = .button
            dial = min(cap, s - fixed(g, card: false))
        }
        if dial < floor - 0.5 { return listPlan() }
        p.grid = g
        p.dial = dial
        p.share = dial / h
        var spare = max(0, s - fixed(g, card: false) - dial)
        // 4a. A map card where 160 or more is spare.
        if spare >= mapPromote {
            map = .card
            p.mapHeight = spare - gridToMap
            spare = 0
        }
        p.map = map
        // 4b. Taller tiles, 72 → 88.
        let rows: CGFloat = g == .full ? 2 : 1
        let grow = min((tileGrown - Self.tile) * k, spare / rows)
        p.tileHeight = tile + grow
        spare -= grow * rows
        // 4c. Up to +12 on each of three gaps.
        var each = min(gapGrow, spare / 3)
        spare -= 3 * each
        // 4d. The rest above the header and below the grid, never more than 24 at the bottom (or above
        // the header); anything still left widens the three gaps further.
        p.topExtra = min(maxSpare, spare / 2)
        p.bottomSpare = min(maxSpare, spare - p.topExtra)
        each += max(0, spare - p.topExtra - p.bottomSpare) / 3
        p.gapHeaderDial = headerToDial + each
        p.gapDialReadout = dialToReadout + each
        p.gapGroupGrid = groupToGrid + each
        p.used = fixed(g, card: map == .card) + dial + p.mapHeight + grow * rows + 3 * each + p.topExtra + p.bottomSpare
        return p
    }

    // MARK: The golden table (docs/REFINE.md §4.7)

    /// A device in the planner's table: width, full height, safe height.
    struct Device { let name: String; let w: CGFloat; let h: CGFloat; let s: CGFloat }

    /// The devices the self-tests and unit tests run the planner on. Safe heights are the usual insets.
    static let devices: [Device] = [
        Device(name: "iPhone SE", w: 375, h: 667, s: 647),
        Device(name: "iPhone 16", w: 393, h: 852, s: 759),
        Device(name: "iPhone 16 Pro", w: 402, h: 874, s: 778),
        Device(name: "iPhone 17 Pro Max", w: 440, h: 956, s: 862),
        Device(name: "Pixel 7", w: 412, h: 915, s: 915 - 52 - 24),
        Device(name: "iPad mini portrait", w: 744, h: 1133, s: 1089),
        Device(name: "iPad 11 portrait", w: 834, h: 1210, s: 1166),
        Device(name: "iPad 13 portrait", w: 1032, h: 1376, s: 1332),
        Device(name: "iPad 11 landscape", w: 1210, h: 834, s: 790),
        Device(name: "iPad 13 landscape", w: 1376, h: 1032, s: 988),
        Device(name: "Mac 380x720", w: 380, h: 720, s: 720),
        Device(name: "Mac 420x840", w: 420, h: 840, s: 840),
        Device(name: "Phone landscape", w: 852, h: 393, s: 372),
    ]

    /// The four states of §4.7: nothing, locked, marked, both.
    static let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    /// Runs the whole table (devices × layouts × states × text sizes × banner) and returns the cases that
    /// break a rule: more than 24 left empty at the bottom, a block partly visible (the blocks add up to
    /// more than the safe height without scrolling), the dial under its floor or wider than its cap, a map
    /// card under 140. Then the worked numbers of §3.4. Empty when all is well.
    static func tableFailures() -> [String] {
        var failures: [String] = []
        for d in devices {
            for layout in Layout.allCases {
                for state in states {
                    for (k, acc) in [(CGFloat(1), false), (1.3, false), (1.3, true)] {
                        for banner in [false, true] {
                            let p = plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, accessibilityText: acc,
                                         hasSpot: state.spot, locked: state.locked, hasUpdateBanner: banner)
                            let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)\(acc ? " acc" : "")\(banner ? " banner" : "")"
                            if p.list {
                                if !acc && p.dial < dialMin { failures.append("\(name): list dial \(Int(p.dial))") }
                                continue
                            }
                            if p.map == .card && p.mapHeight < mapMin - 0.5 { failures.append("\(name): map card \(Int(p.mapHeight))") }
                            if p.twoPane {
                                if p.dial < dialMin - 0.5 { failures.append("\(name): two panes, dial \(Int(p.dial))") }
                                continue
                            }
                            if p.bottomSpare > maxSpare + 0.5 { failures.append("\(name): \(Int(p.bottomSpare)) empty at the bottom") }
                            if p.used > d.s + 0.5 { failures.append("\(name): \(Int(p.used - d.s)) cut off") }
                            if p.used < d.s - 0.5 { failures.append("\(name): \(Int(d.s - p.used)) unaccounted for") }
                            if p.dial + 0.5 < p.floor { failures.append("\(name): dial \(Int(p.dial)) under its floor \(Int(p.floor))") }
                            let cap = min(d.w - 2 * p.margin, maxColumn) + 2 * p.margin - 2 * layout.e
                            if p.dial > cap + 0.5 { failures.append("\(name): dial \(Int(p.dial)) over its cap \(Int(cap))") }
                        }
                    }
                }
            }
        }
        // The worked numbers (§3.4): iPhone 16 Pro, 402 × 874, S = 778.
        let none = plan(w: 402, h: 874, s: 778)
        if abs(none.dial - 370) > 1 || none.grid != .full || none.map != .tile || abs(none.tileHeight - tileGrown) > 0.5 {
            failures.append("16 Pro Medium: dial \(Int(none.dial)), expected 370 with the full grid and 88 tiles")
        }
        let both = plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        if both.dial < 345 || both.dial > 360 || both.grid != .full { failures.append("16 Pro Medium locked + marked: dial \(Int(both.dial)), expected about 352") }
        let large = plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        if large.grid != .compact || large.map != .button || abs(large.dial - 378) > 1 {
            failures.append("16 Pro Large locked + marked: expected the compact row, the header map button and a 378 dial")
        }
        let small = plan(w: 402, h: 874, s: 778, layout: .small)
        if small.map != .card || small.mapHeight < 180 || abs(small.dial - 0.36 * 874) > 1 {
            failures.append("16 Pro Small: dial \(Int(small.dial)), map \(Int(small.mapHeight))")
        }
        if plan(w: 393, h: 852, s: 759).layout != .medium || Layout.of(nil) != .medium || Layout.of("bogus") != .medium {
            failures.append("Medium is not the default")
        }
        return failures
    }

    /// One line per layout for a device and state: "medium: dial 370, full grid, map tile, tiles 88,
    /// bottom 2". For the self-tests' reports.
    static func summary(w: CGFloat, h: CGFloat, s: CGFloat, hasSpot: Bool, locked: Bool) -> [String] {
        Layout.allCases.map { layout in
            let p = plan(w: w, h: h, s: s, layout: layout, hasSpot: hasSpot, locked: locked)
            let grid: String
            switch p.grid {
            case .full: grid = "full grid"
            case .compact: grid = "compact row"
            case .list: grid = "list"
            }
            let map: String
            switch p.map {
            case .tile: map = "map tile"
            case .card: map = "map card \(Int(p.mapHeight.rounded()))"
            case .button: map = "map button"
            }
            return "\(layout.rawValue): dial \(Int(p.dial.rounded())), \(grid), \(map), tiles \(Int(p.tileHeight.rounded())), bottom \(Int(p.bottomSpare.rounded()))"
        }
    }
}
