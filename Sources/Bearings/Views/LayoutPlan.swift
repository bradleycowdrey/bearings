import CoreGraphics

/// The four layouts (docs/REFINE.md §3.4 and Cycle 2 §C2.2 #2, the owner's decision): one rule per layout,
/// the same on every port and device, so the four give four visibly different results.
///
/// | Layout | Grid | Tiles | Map | Dial | Readout |
/// |---|---|---|---|---|---|
/// | Small "Compass and map" | compact row | 72 | card of 140 or more | 0.36 H | 1.0 |
/// | Medium "Balanced" (default) | full 2-row grid | 72–88 (96 on iPad) | tile, or card when 160 or more is spare | Large's less 24 | 1.0 |
/// | Large "Bigger compass" | full grid | fixed 72 | tile (a card only where 160 or more is still spare, as on a large iPad) | gets the saved height, up to W − 16 | 1.0 |
/// | Extra Large "Biggest compass" | compact row | 72 | header button, on every device | W − 16 (larger than Large wherever height limits it) | 1.25 |
///
/// Saved under "layout" as the raw value; anything else reads as Medium. (This shadows SwiftUI's `Layout`
/// protocol inside the app, which Bearings doesn't use.)
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

    /// The one-line description (the Mac's View › Layout menu; the ⋯ menu states the result instead,
    /// `LayoutPlan.menuSubtitle`).
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
    /// cap is the column plus its margins, less 2e (W − 16 for Large and Extra Large, as on Android).
    /// Medium has none of its own: its dial is Large's less 24 (W − 40 where the width limits it).
    var e: CGFloat {
        switch self {
        case .small, .medium: 16
        case .large, .extraLarge: 8
        }
    }

    /// The dial's floor, as a share of the full height H. Below it the screen becomes the scrolling list.
    /// Medium, the default, shares Small's 0.30 so a small phone (iPhone SE) with a locked bearing and a
    /// marked spot still gets the panel rather than the list.
    var floorShare: CGFloat {
        switch self {
        case .small: 0.30
        case .medium: 0.30
        case .large: 0.38
        case .extraLarge: 0.40
        }
    }

    /// On a tablet the dial is also capped at this share of H (Extra Large widens its column to match).
    var tabletShare: CGFloat {
        switch self {
        case .small, .medium: 0.48
        case .large: 0.54
        case .extraLarge: 0.64
        }
    }

    /// Multiplies the heading number and its point letters: 1.25 at Extra Large (56 → 70, 64 → 80).
    var readoutScale: CGFloat { self == .extraLarge ? 1.25 : 1 }

    /// Small and Extra Large use the compact row (Position, Elevation, Sun with the moon in its caption).
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

/// The "Instrument panel" planner (docs/REFINE.md §3.3, revised by Cycle 2): one pure function with no UI
/// code, the same constants and order as android/.../ui/LayoutPlan.kt. It works bottom-up: the fixed blocks
/// are placed first, the dial takes what its layout's rule gives it, and any spare height then becomes a
/// map card, taller tiles and wider gaps, so no more than 24 is ever left empty at the bottom and nothing is
/// cut. Every length is in points.
///
/// From top to bottom: header bar → dial → readout → status line → lock row → spot row → tile grid → map
/// card (only where it fits whole).
struct LayoutPlan: Equatable {
    /// The tile grid: two rows (Position 2u | Elevation, then Sun | Moon | Map), the compact row
    /// (Position | Elevation | Sun, widths from C), or full-width rows in the scrolling list.
    enum Grid: Equatable { case full, compact, list }
    /// Where the map is: a tile in the grid, a full-width card, or a button in the header (map sheet).
    enum Map: Equatable { case tile, card, button }

    var layout: Layout = .default
    var twoPane = false
    /// The whole screen scrolls as one list (accessibility text sizes, or nothing fits even at the floor).
    var list = false
    /// An iPad (or a Mac window as large): header 52, heading 64, margins 20, tiles up to 96.
    var tablet = false
    /// A Mac window: 16 in from every edge (24 at widths of 600 or more).
    var mac = false
    /// The text multiplier (Text Size, 1…1.3).
    var k: CGFloat = 1
    var margin: CGFloat = 16
    /// Above the header (4 under a phone's safe area; 16 or 24 from a Mac window's edge).
    var topInset: CGFloat = 4
    /// Under the last block (8 over a phone's safe area; 16 or 24 from a Mac window's edge).
    var bottomInset: CGFloat = 8
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
    /// No compass: "NO HEADING" under the readout, and the status line's two-line note.
    var noCompass = false
    var grid: Grid = .full
    var map: Map = .tile
    /// The map card's height (0 unless `map == .card`).
    var mapHeight: CGFloat = 0
    /// 72 × k; Medium grows it up to 88 × k (96 × k on a tablet); two panes use 80 × k.
    var tileHeight: CGFloat = 72
    var gapHeaderDial: CGFloat = 12
    /// Always 12, from the dial's bottom edge to the digits' cap height (C2.3 #7).
    var gapDialReadout: CGFloat = 12
    var gapGroupGrid: CGFloat = 16
    /// Spare placed above the header (with the top inset).
    var topExtra: CGFloat = 0
    /// Spare left under the grid or map (with the bottom inset). Never more than 24.
    var bottomSpare: CGFloat = 0
    /// Two panes: the trailing pane's top inset, so it lines up with the dial's top.
    var trailingInset: CGFloat = 0
    /// Two panes: the trailing pane holds more than fits and scrolls (a phone on its side).
    var trailingScrolls = false
    /// Everything the plan places, top to bottom (single column; the trailing pane in two panes).
    var used: CGFloat = 0

    /// The map button sits in the header only when the map is neither a tile nor a card.
    var mapInHeader: Bool { map == .button }
    /// The grid's unit width u = (C − 2 × 8) / 3 (or (C − 8) / 2 in two columns).
    var unit: CGFloat { columns == 3 ? (columnWidth - 2 * Self.rowGap) / 3 : (columnWidth - Self.rowGap) / 2 }

    /// The compact row's widths, from C rather than from grid units (C2.2 #1): Elevation = Sun =
    /// w = max(104, round(0.27 C)) and Position = C − 2 × 8 − 2w, so the row is exactly C wide.
    var compactWidths: (position: CGFloat, other: CGFloat) { Self.compactWidths(columnWidth) }

    static func compactWidths(_ c: CGFloat) -> (position: CGFloat, other: CGFloat) {
        let w = max(compactMin, (compactShare * c).rounded())
        return (c - 2 * rowGap - 2 * w, w)
    }

    /// Each row's tile widths, top to bottom, as the screen draws them (single column or trailing pane).
    /// Each row's widths plus its gutters add up to C exactly (the C2 test).
    var rowWidths: [[CGFloat]] {
        let c = columnWidth, u = unit, g = Self.rowGap
        switch grid {
        case .list:
            return [[c], [c], [c], [c]]
        case .compact:
            let w = compactWidths
            return [[w.position, w.other, w.other]]
        case .full:
            if columns == 3 {
                let second: [CGFloat] = map == .tile ? [u, u, u] : [(c - g) / 2, (c - g) / 2]
                return [[2 * u + g, u], second]
            }
            var rows: [[CGFloat]] = [[c], [u, u], [c]]
            if map == .tile { rows.append([c]) }
            return rows
        }
    }

    /// "Dial 386 · map in header": what the layout gives on this screen, for the ⋯ menu's subtitle.
    var menuSubtitle: String {
        let dialText = "Dial \(Int(dial.rounded()))"
        if list { return "\(dialText) · scrolls" }
        let mapText: String
        switch map {
        case .tile: mapText = "map tile"
        case .card: mapText = "map card"
        case .button: mapText = "map in header"
        }
        return "\(dialText) · \(mapText)"
    }

    // MARK: Constants (points; dp on Android). Spacing tokens are 4 / 8 / 12 / 16 / 24 only.

    static let top: CGFloat = 4
    static let headerToDial: CGFloat = 12
    static let dialToReadout: CGFloat = 12
    static let readoutToStatus: CGFloat = 6
    /// The "NO HEADING" caption: 4 under the readout, an 11 pt line of 14.
    static let readoutToCaption: CGFloat = 4
    static let captionLine: CGFloat = 14
    static let groupToGrid: CGFloat = 16
    /// Lock row → spot row → grid, and between rows and tiles.
    static let rowGap: CGFloat = 8
    static let gridToMap: CGFloat = 12
    static let bottom: CGFloat = 8
    static let marginPhone: CGFloat = 16
    static let marginTablet: CGFloat = 20
    /// A Mac window: 16 in from every edge, 24 at widths of 600 or more (C2.3 #17).
    static let macInset: CGFloat = 16
    static let macInsetWide: CGFloat = 24
    static let macWide: CGFloat = 600
    static let maxColumn: CGFloat = 640
    static let header: CGFloat = 48
    static let headerTablet: CGFloat = 52
    static let heading: CGFloat = 56
    static let headingTablet: CGFloat = 64
    /// The readout's block, its line box trimmed (C2.3 #7): from the digits' cap height (0.72 of the size,
    /// with the light weight's rounding) to 4 under the baseline.
    static let readoutCap: CGFloat = 0.72
    static let readoutBelow: CGFloat = 4
    /// The status line's 13 pt line.
    static let statusLine: CGFloat = 16
    /// The lock row and the spot row: full-width tiles, 44 high.
    static let lockRow: CGFloat = 44
    static let spotRow: CGFloat = 44
    static let tile: CGFloat = 72
    static let tileGrown: CGFloat = 88
    static let tileGrownTablet: CGFloat = 96
    /// Two panes: fixed 80 rows (C2.3 #8).
    static let tilePane: CGFloat = 80
    /// The compact row: Elevation and Sun are max(104, 0.27 C) wide.
    static let compactMin: CGFloat = 104
    static let compactShare: CGFloat = 0.27
    /// Spare at or above this (dial at its rule) turns a Map tile into a full-width card.
    static let mapPromote: CGFloat = 160
    /// Medium's promoted card is at least this tall, taken from the dial (C2.3 #5).
    static let mapPromoted: CGFloat = 200
    /// No compass: Medium's tiles stay 72 and the dial gives way for a map card this tall (C2.3 #13).
    static let mapNoCompass: CGFloat = 160
    static let mapMin: CGFloat = 140
    /// Medium's dial is Large's less this, so the two always differ (C2.2 #2).
    static let mediumStep: CGFloat = 24
    /// Header → dial and readout group → rows may each grow this much; dial → readout stays 12.
    static let gapGrow: CGFloat = 12
    /// The most ever left empty at the bottom (and placed above the header).
    static let maxSpare: CGFloat = 24
    /// Small's dial: 0.36 H.
    static let smallShare: CGFloat = 0.36
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
    /// The text multiplier's cap on Apple devices.
    static let maxK: CGFloat = 1.3
    /// The Mac window's smallest size: every layout with the sample (locked and marked) fits without
    /// scrolling (header + dial + grid + insets).
    static let macMinWidth: CGFloat = 380
    static let macMinHeight: CGFloat = 740

    // MARK: Heights, shared with MainView so what it draws is what was planned

    static func headerHeight(k: CGFloat, tablet: Bool) -> CGFloat { (tablet ? headerTablet : header) * k }
    /// The readout's trimmed block: cap height to 4 under the baseline.
    static func readoutHeight(headingSize: CGFloat) -> CGFloat { headingSize * readoutCap + readoutBelow }
    static func statusHeight(k: CGFloat, lines: CGFloat) -> CGFloat { statusLine * k * lines }
    static func lockHeight(k: CGFloat) -> CGFloat { lockRow * k }
    static func spotHeight(k: CGFloat) -> CGFloat { spotRow * k }
    static func tileHeight(k: CGFloat) -> CGFloat { tile * k }
    /// The readout group: the readout, "NO HEADING" (no compass), the status line.
    static func groupHeight(headingSize: CGFloat, k: CGFloat, statusLines: CGFloat, noCompass: Bool) -> CGFloat {
        readoutHeight(headingSize: headingSize) + (noCompass ? readoutToCaption + captionLine * k : 0)
            + readoutToStatus + statusHeight(k: k, lines: statusLines)
    }

    // MARK: The planner

    /// `w` the window's (safe) width, `h` its full height including the safe-area insets, `s` the safe
    /// height, `k` the Text Size multiplier (capped at 1.3), `accessibilityText` an accessibility Text Size.
    /// `locked` the lock row shows; `noCompass` "NO HEADING" and the two-line note; `mac` a Mac window.
    static func plan(w: CGFloat, h: CGFloat, s: CGFloat, layout: Layout = .default, k: CGFloat = 1,
                     accessibilityText: Bool = false, hasSpot: Bool = false, locked: Bool = false,
                     noCompass: Bool = false, hasUpdateBanner: Bool = false, mac: Bool = false,
                     isLandscapePhone: Bool = false) -> LayoutPlan {
        var p = LayoutPlan()
        p.layout = layout
        p.k = min(max(k, 1), maxK)
        let k = p.k
        p.mac = mac
        p.noCompass = noCompass
        p.tablet = min(w, h) >= tabletSide
        if mac {
            let inset = w >= macWide ? macInsetWide : macInset
            p.margin = inset
            p.topInset = inset
            p.bottomInset = inset
        } else {
            p.margin = p.tablet ? marginTablet : marginPhone
            p.topInset = top
            p.bottomInset = bottom
        }
        p.headerHeight = headerHeight(k: k, tablet: p.tablet)
        p.readoutScale = layout.readoutScale
        p.headingSize = (p.tablet ? headingTablet : heading) * layout.readoutScale
        // The status line may wrap only at k > 1.1, or for the no-compass note.
        p.statusLines = noCompass || k > 1.1 ? 2 : 1
        p.tileHeight = tileHeight(k: k)

        let banner: CGFloat = hasUpdateBanner ? Self.banner + bannerGap : 0
        let group = groupHeight(headingSize: p.headingSize, k: k, statusLines: p.statusLines, noCompass: noCompass)
        // The rows above the grid: the lock row and the spot row, each with the 8 under it.
        let rows: CGFloat = (locked ? lockHeight(k: k) + rowGap : 0) + (hasSpot ? spotHeight(k: k) + rowGap : 0)
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
            l.used = 0
            return l
        }

        // Accessibility sizes: the whole screen is one scrolling list (§3.6).
        if accessibilityText { return listPlan() }

        // Two panes (§3.5, C2.3 #8): wide windows, and phones on their side.
        if isLandscapePhone || (w > h && (w >= twoPaneWidth || s < landscapePhone)) {
            p.twoPane = true
            let trailing = min(max(layout.paneShare * w, paneMin), paneMax)
            p.trailingWidth = trailing
            p.columnWidth = trailing - p.margin
            p.columns = trailing >= paneColumns3 ? 3 : 2
            let pane = w - trailing
            let below = s - p.topInset - p.headerHeight - banner - headerToDial - p.bottomInset
            let rest = dialToReadout + group
            let byHeight = below - rest
            if byHeight < dialMin { return listPlan() }
            p.dial = min(pane - 2 * p.margin, byHeight)
            p.floor = p.dial
            p.share = p.dial / h
            // The trailing pane starts level with the dial's top (the leading group is centred).
            p.trailingInset = max(0, (below - p.dial - rest) / 2)
            let avail = below - p.trailingInset
            // Fixed 80 rows.
            let row = tilePane * k
            p.tileHeight = row
            // Without the Map tile: 3 columns, two rows (Position | Elevation, Sun | Moon); 2 columns,
            // three (Position, Elevation | Sun, Moon).
            let rowsNoMap: CGFloat = p.columns == 3 ? 2 : 3
            let gridNoMap = rowsNoMap * row + (rowsNoMap - 1) * rowGap
            let forMap = avail - rows - gridNoMap
            if layout == .extraLarge {
                // Extra Large: the map is the header button on every device.
                p.map = .button
                p.used = rows + gridNoMap
            } else if forMap >= mapPromote {
                // The rest of the pane goes to the map card.
                p.map = .card
                p.mapHeight = forMap - gridToMap
                p.used = avail
            } else {
                p.map = .tile
                // 3 columns: the Map tile sits in row 2; 2 columns: its own row, spanning both.
                let gridRows: CGFloat = p.columns == 3 ? 2 : 4
                p.used = rows + gridRows * row + (gridRows - 1) * rowGap
            }
            if p.used > avail + 0.5 { p.trailingScrolls = true }
            p.bottomSpare = max(0, avail - p.used)
            p.grid = .full
            return p
        }

        // One column, C = min(W − 2 × margin, 640), centred. Extra Large on a tablet widens it to its dial.
        var c = min(w - 2 * p.margin, maxColumn)
        if p.tablet && layout == .extraLarge { c = min(w - 2 * p.margin, max(maxColumn, layout.tabletShare * h)) }
        p.columnWidth = c
        func cap(_ l: Layout) -> CGFloat {
            let byWidth = c + 2 * p.margin - 2 * l.e
            return p.tablet ? min(byWidth, l.tabletShare * h) : byWidth
        }
        let floor = min(layout.floorShare * h, cap(layout))
        p.floor = floor

        func gridHeight(_ g: Grid) -> CGFloat { g == .full ? 2 * tile + rowGap : tile }
        func fixed(_ g: Grid, card: Bool) -> CGFloat {
            p.topInset + p.headerHeight + banner + headerToDial + dialToReadout + group + groupToGrid + rows
                + gridHeight(g) + (card ? gridToMap : 0) + p.bottomInset
        }

        if layout == .small {
            // Small: the compact row, and a map card filling the rest (140 or more). The dial is 0.36 H;
            // the map shrinks toward 140 first, then the dial goes down to its floor.
            p.grid = .compact
            p.map = .card
            let avail = s - fixed(.compact, card: true)
            var dial = min(cap(.small), smallShare * h)
            if avail - dial < mapMin { dial = max(floor, avail - mapMin) }
            if avail - dial < mapMin - 0.5 { return listPlan() }
            p.dial = dial
            p.mapHeight = avail - dial
            p.share = dial / h
            p.used = s
            return p
        }

        let g: Grid = layout.compactRow ? .compact : .full
        var map: Map = layout == .extraLarge ? .button : .tile
        var dial: CGFloat
        if layout == .medium {
            // Medium: Large's dial (full grid at 72) less 24, so the two always differ by 24 or more.
            dial = min(cap(.large), s - fixed(.full, card: false)) - mediumStep
        } else {
            dial = min(cap(layout), s - fixed(g, card: false))
        }
        if dial < floor - 0.5 { return listPlan() }
        var spare = max(0, s - fixed(g, card: false) - dial)
        var grow: CGFloat = 0
        if layout != .extraLarge && spare >= mapPromote {
            // A map card where 160 or more is spare; Medium's is 200 or more, taken from the dial.
            map = .card
            p.mapHeight = spare - gridToMap
            if layout == .medium && p.mapHeight < mapPromoted {
                let take = min(mapPromoted - p.mapHeight, max(0, dial - floor))
                dial -= take
                p.mapHeight += take
            }
            spare = 0
        } else if layout == .medium && noCompass && dial - (mapNoCompass + gridToMap - spare) >= floor {
            // No compass: the tiles stay 72 and the dial gives way for a 160 map card.
            dial -= mapNoCompass + gridToMap - spare
            map = .card
            p.mapHeight = mapNoCompass
            spare = 0
        } else if layout == .medium && !noCompass {
            // Taller tiles: 72 → 88 (96 on a tablet). With no compass they stay 72 (C2.3 #13) and the spare
            // widens the gaps instead.
            let rowsCount: CGFloat = 2
            grow = max(0, min(((p.tablet ? tileGrownTablet : tileGrown) - Self.tile) * k, spare / rowsCount))
            spare -= grow * rowsCount
        }
        p.grid = g
        p.map = map
        p.dial = dial
        p.share = dial / h
        p.tileHeight = tile + grow
        // Up to +12 on header → dial and on readout group → rows; dial → readout stays 12.
        var each = min(gapGrow, spare / 2)
        spare -= 2 * each
        // The rest above the header and below the grid, never more than 24 at the bottom (or above the
        // header); anything still left widens the same two gaps, centring the dial and its readout.
        p.topExtra = min(maxSpare, spare / 2)
        p.bottomSpare = min(maxSpare, spare - p.topExtra)
        each += max(0, spare - p.topExtra - p.bottomSpare) / 2
        p.gapHeaderDial = headerToDial + each
        p.gapDialReadout = dialToReadout
        p.gapGroupGrid = groupToGrid + each
        let gridRows: CGFloat = g == .full ? 2 : 1
        p.used = fixed(g, card: map == .card) + dial + p.mapHeight + grow * gridRows + 2 * each + p.topExtra + p.bottomSpare
        return p
    }

    // MARK: The golden table (docs/REFINE.md §4.7 and C2's tests)

    /// A device in the planner's table: width, full height, safe height, and whether it is a Mac window.
    struct Device { let name: String; let w: CGFloat; let h: CGFloat; let s: CGFloat; var mac = false }

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
        Device(name: "Mac 380x740", w: macMinWidth, h: macMinHeight, s: macMinHeight, mac: true),
        Device(name: "Mac 420x840", w: 420, h: 840, s: 840, mac: true),
        Device(name: "Mac 1200x800", w: 1200, h: 800, s: 800, mac: true),
        Device(name: "Phone landscape", w: 852, h: 393, s: 372),
    ]

    /// The four states of §4.7: nothing, locked, marked, both.
    static let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    /// Runs the whole table (devices × layouts × states × text sizes × banner × compass) and returns the
    /// cases that break a rule: more than 24 left empty at the bottom, a block partly visible (the blocks add
    /// up to more than the safe height without scrolling), the dial under its floor or wider than its cap, a
    /// map card under 140, a row whose widths and gutters don't add up to C, Extra Large showing a map card,
    /// a Mac window closer than 16 to an edge, and two neighbouring layouts that differ by less than 24 of
    /// dial with the same grid. Then the worked numbers. Empty when all is well.
    static func tableFailures() -> [String] {
        var failures: [String] = []
        for d in devices {
            for state in states {
                for (k, acc) in [(CGFloat(1), false), (1.3, false), (1.3, true)] {
                    for banner in [false, true] {
                        for noCompass in [false, true] {
                            var plans: [LayoutPlan] = []
                            for layout in Layout.allCases {
                                let p = plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, accessibilityText: acc,
                                             hasSpot: state.spot, locked: state.locked, noCompass: noCompass,
                                             hasUpdateBanner: banner, mac: d.mac)
                                plans.append(p)
                                let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)\(acc ? " acc" : "")\(banner ? " banner" : "")\(noCompass ? " no compass" : "")"
                                failures += check(p, device: d, name: name, accessibilityText: acc)
                            }
                            // Neighbouring layouts differ by 24 of dial or by grid mode (C2.2 #2).
                            for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
                                if a.grid == b.grid && b.dial - a.dial < mediumStep - 0.5 {
                                    failures.append("\(d.name) \(state.name) k\(k): \(a.layout.rawValue) and \(b.layout.rawValue) differ by \(Int(b.dial - a.dial)) of dial with the same grid")
                                }
                            }
                        }
                    }
                }
            }
        }
        // The worked numbers: iPhone 16 Pro, 402 × 874, S = 778, C = 370.
        let none = plan(w: 402, h: 874, s: 778)
        if abs(none.dial - 362) > 1 || none.grid != .full || none.map != .tile || abs(none.tileHeight - tileGrown) > 0.5 {
            failures.append("16 Pro Medium: dial \(Int(none.dial)), expected 362 with the full grid and 88 tiles")
        }
        let large = plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        if large.grid != .full || large.map != .tile || abs(large.tileHeight - tile) > 0.5 {
            failures.append("16 Pro Large locked + marked: expected the full grid at 72 with the Map tile")
        }
        let xl = plan(w: 402, h: 874, s: 778, layout: .extraLarge, hasSpot: true, locked: true)
        if xl.grid != .compact || xl.map != .button || abs(xl.dial - 386) > 1 || abs(xl.readoutScale - 1.25) > 0.001 {
            failures.append("16 Pro Extra Large: expected the compact row, the header map button, a 386 dial and a 1.25 readout")
        }
        let small = plan(w: 402, h: 874, s: 778, layout: .small)
        if small.map != .card || small.mapHeight < 180 || abs(small.dial - 0.36 * 874) > 1 {
            failures.append("16 Pro Small: dial \(Int(small.dial)), map \(Int(small.mapHeight))")
        }
        // The compact row at C = 370 and 380: 146 | 104 | 104 and 156 | 104 | 104.
        let w370 = compactWidths(370), w380 = compactWidths(380)
        if w370.position != 146 || w370.other != 104 || w380.position != 156 || w380.other != 104 {
            failures.append("Compact row widths: \(w370) at 370, \(w380) at 380")
        }
        // iPad portrait, Medium: the map is a card of 200 or more.
        let ipad = plan(w: 834, h: 1210, s: 1166)
        if ipad.map != .card || ipad.mapHeight < mapPromoted - 0.5 {
            failures.append("iPad 11 portrait Medium: map \(ipad.map) \(Int(ipad.mapHeight)), expected a card of 200 or more")
        }
        if plan(w: 393, h: 852, s: 759).layout != .medium || Layout.of(nil) != .medium || Layout.of("bogus") != .medium {
            failures.append("Medium is not the default")
        }
        return failures
    }

    /// One plan's rules.
    private static func check(_ p: LayoutPlan, device d: Device, name: String, accessibilityText acc: Bool) -> [String] {
        var failures: [String] = []
        if d.mac && (p.margin < macInset - 0.5 || p.topInset < macInset - 0.5 || p.bottomInset < macInset - 0.5) {
            failures.append("\(name): Mac edges \(Int(p.margin)) / \(Int(p.topInset)) / \(Int(p.bottomInset)), expected 16 or more")
        }
        // Every row's widths and gutters add up to C (C2.2 #1).
        for row in p.rowWidths {
            let sum = row.reduce(0, +) + CGFloat(row.count - 1) * rowGap
            if abs(sum - p.columnWidth) > 0.5 { failures.append("\(name): a row is \(Int(sum)) wide in a column of \(Int(p.columnWidth))") }
            if row.contains(where: { $0 < compactMin - 0.5 }) && p.grid == .compact {
                failures.append("\(name): a compact tile under \(Int(compactMin))")
            }
        }
        if p.list {
            if !acc && p.dial < dialMin { failures.append("\(name): list dial \(Int(p.dial))") }
            return failures
        }
        if p.layout == .extraLarge && p.map != .button { failures.append("\(name): Extra Large shows the map as \(p.map)") }
        if p.map == .card && p.mapHeight < mapMin - 0.5 { failures.append("\(name): map card \(Int(p.mapHeight))") }
        if p.twoPane {
            if p.dial < dialMin - 0.5 { failures.append("\(name): two panes, dial \(Int(p.dial))") }
            return failures
        }
        if p.bottomSpare > maxSpare + 0.5 { failures.append("\(name): \(Int(p.bottomSpare)) empty at the bottom") }
        if p.used > d.s + 0.5 { failures.append("\(name): \(Int(p.used - d.s)) cut off") }
        if p.used < d.s - 0.5 { failures.append("\(name): \(Int(d.s - p.used)) unaccounted for") }
        if p.dial + 0.5 < p.floor { failures.append("\(name): dial \(Int(p.dial)) under its floor \(Int(p.floor))") }
        // Medium's dial is Large's less 24, so its cap is Large's less 24.
        let capLayout: Layout = p.layout == .medium ? .large : p.layout
        var cap = p.columnWidth + 2 * p.margin - 2 * capLayout.e
        if p.tablet { cap = min(cap, capLayout.tabletShare * d.h) }
        if p.layout == .medium { cap -= mediumStep }
        if p.dial > cap + 0.5 { failures.append("\(name): dial \(Int(p.dial)) over its cap \(Int(cap))") }
        if p.gapDialReadout != dialToReadout { failures.append("\(name): dial → readout \(Int(p.gapDialReadout))") }
        let grownCap = (p.tablet ? tileGrownTablet : tileGrown) * p.k
        if p.tileHeight > grownCap + 0.5 { failures.append("\(name): tiles \(Int(p.tileHeight)) over \(Int(grownCap))") }
        // No compass: the tiles stay 72 (C2.3 #13).
        if p.noCompass && abs(p.tileHeight - tile * p.k) > 0.5 { failures.append("\(name): no compass, tiles \(Int(p.tileHeight))") }
        return failures
    }

    /// One line per layout for a device and state: "medium: dial 362, full grid, map tile, tiles 88,
    /// bottom 21". For the self-tests' reports.
    static func summary(w: CGFloat, h: CGFloat, s: CGFloat, hasSpot: Bool, locked: Bool, mac: Bool = false) -> [String] {
        Layout.allCases.map { layout in
            let p = plan(w: w, h: h, s: s, layout: layout, hasSpot: hasSpot, locked: locked, mac: mac)
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
