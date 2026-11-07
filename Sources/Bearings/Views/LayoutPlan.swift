import CoreGraphics
import Foundation

/// The four layouts of Concept A, "Instrument Panel (Targets + Grid)", Option 1 (docs/REFINE.md "Concept A
/// (chosen)", docs/LAYOUTS.md): the same dial, readout and status line on every size, then the location card
/// (the sky card with ⋯), then one Targets card (lock and marked spot, only when set), then what the layout
/// packs underneath. One rule set on every port and device.
///
/// | Layout | Grid | Map | Dial cap (one column) | Readout |
/// |---|---|---|---|---|
/// | Small "Compass + big map" | `band` (over the map card) | card, all spare height | ceil8(0.40 H) | 1.0 |
/// | Medium "Balanced · map tile" (default) | `quad` 2 × 2 with the Map tile | tile | ceil8(0.40 H) | 1.0 |
/// | Large "Bigger compass · map in header" | `six` 3 × 2 | header button | ceil8(0.42 H), grows to W − 16 | 1.0 |
/// | Extra Large "Biggest compass · one row" | `strip` | header button | W − 16 | 1.25 |
///
/// The owner's rule: in one column (phones, iPad portrait, Mac windows taller than wide), at every text size,
/// every layout's dial is at least min(0.40 H, its width cap), in the scrolling list too. Short of height,
/// a layout gives things up first (`LayoutPlan.Step`), never the dial.
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

    /// The one-line subtitle in both menus (the ⋯ menu and the Mac's View › Layout).
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
        case .medium: "square.grid.2x2"
        case .large: "square.grid.3x2"
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

    /// One column: the dial's cap as a share of H (rounded up to 8), or nil for the width cap alone.
    var capShare: CGFloat? {
        switch self {
        case .small, .medium: 0.40
        case .large: 0.42
        case .extraLarge: nil
        }
    }

    /// Two panes: the dial's share of H (Small 0.56, Medium 0.62, Large 0.66, Extra Large 0.72).
    var paneShare: CGFloat {
        switch self {
        case .small: 0.56
        case .medium: 0.62
        case .large: 0.66
        case .extraLarge: 0.72
        }
    }

    /// Two panes: the right pane's share of the width (Extra Large's left pane takes 60%).
    var rightShare: CGFloat { self == .extraLarge ? 0.40 : 0.4333 }

    /// Multiplies the heading number and its point letters: 1.25 at Extra Large (56 → 70; 96 → 120 on iPad).
    var readoutScale: CGFloat { self == .extraLarge ? 1.25 : 1 }

    /// The Targets card's text: 15 at Small, 17 otherwise (19 on iPad).
    var targetsText: CGFloat { self == .small ? 15 : 17 }

    private var index: Int { Self.allCases.firstIndex(of: self) ?? 1 }

    /// The next larger layout, or nil at Extra Large.
    var larger: Layout? { index + 1 < Self.allCases.count ? Self.allCases[index + 1] : nil }
    /// The next smaller layout, or nil at Small.
    var smaller: Layout? { index > 0 ? Self.allCases[index - 1] : nil }

    /// A saved or launch-argument id; unknown or missing reads as Medium.
    static func of(_ id: String?) -> Layout { id.flatMap(Layout.init(rawValue:)) ?? .default }
}

/// The Concept A planner (docs/REFINE.md A.5, the same steps as Android's LayoutPlan.kt): one pure function
/// with no UI code. MainView reads every frame from the plan and nowhere else.
///
/// 1. Anchors: the dial's top is the safe top + 18 (a Mac window: its 28 title band + 18); the stack ends
///    at the safe bottom where there is a home indicator, else 16 above the edge (a Mac window: 24).
/// 2. Fixed blocks: dial → readout 12, readout → status 6 × k, status → location card 12, location card →
///    Targets card 8 (only when a lock or spot exists), → grid 8, → Small's map card 8 (at 140).
/// 3. Dial = min(cap, what is left). Under ceil(0.40 H) the plan gives way one step at a time (`Step`):
///    the spare gaps, the Targets rows to compact height, Large's grid density, Small's map card, the map
///    tile to the header button, and only then the scrolling list.
/// 4. Spare height: first the given-up steps come back (in reverse order, where they fit), then the
///    layout's growth (Small's map card; Medium's rows to 88, live row 2 to 176; Large's rows to 104; Extra
///    Large's strip to 120), then the dial up to its width cap (Large, Extra Large), then at most 24 at the
///    bottom; anything still left centres the stack (`centred`).
///
/// Top to bottom: dial → readout → status line → location card → Targets card → grid → map card.
struct LayoutPlan: Equatable {
    /// What sits under the Targets card.
    /// - `band`: Small's three columns along the map card's bottom (no separate tiles).
    /// - `quad`: 2 × 2 (Medium: Position | Elevation, Sun | Map; with a map card: Sun | Moon).
    /// - `six`: Large's 3 × 2 (Latitude | Longitude | Elevation, Sunrise | Moon | Pressure or Speed).
    /// - `strip`: Extra Large's one summary tile, Position | Elevation | Sun.
    /// - `quadCompact`: 2 × 2 of 64 tiles (Position | Elevation, Sun | Pressure or Speed).
    /// - `twoRow`: large text: Position full width, then Elevation | Sun (Small: Elevation | Map).
    /// - `row`: one 72 compact row, Position | Elevation | Sun (Small: Elevation | Map), the map in the header.
    /// - `mapRows`: Small giving up its card: the compact row, then a full-width Map tile.
    /// - `list`: the scrolling list's rows.
    enum Grid: String, Equatable { case band, quad, six, strip, quadCompact, twoRow, row, mapRows, list }
    /// Where the map is: a tile in the grid, a card, or the location card's map button (the map sheet).
    enum Map: String, Equatable { case tile, card, button }
    /// The tiles of the grid.
    enum Tile: Equatable { case position, elevation, sun, moon, map, latitude, longitude, sunrise, sixth, strip }
    /// Large's sixth tile: Speed while moving, otherwise Pressure.
    enum Sixth: Equatable { case pressure, speed }
    /// What a layout gives up when height runs short, in the owner's order (A.6).
    enum Step: Int, CaseIterable, Hashable {
        /// The spare gaps: safe top → dial 18 → 12, status → location card 12 → 8.
        case tight
        /// The Targets rows to compact height: 44 → 36 (Extra Large and iPad 52 → 44).
        case compactRows
        /// Large's `six` becomes `quadCompact`.
        case dense
        /// Small's map card becomes a Map tile (`mapRows`); iPad Medium's map card a Map tile in the quad.
        case mapTile
        /// The Map tile gives way to the header map button; the rest is one compact `row`.
        case button
    }
    /// One tile and its width.
    struct Cell: Equatable {
        var tile: Tile
        var width: CGFloat
    }

    var layout: Layout = .default
    var twoPane = false
    /// The whole screen scrolls as one list (accessibility text sizes, or nothing fits even at the floor).
    var list = false
    /// An iPad (or a window as large): the regular-width type ramp.
    var tablet = false
    var mac = false
    var locked = false
    var hasSpot = false
    var noCompass = false
    var hasBanner = false
    var accessibilityText = false
    /// The text multiplier (Text Size, 1…1.3).
    var k: CGFloat = 1
    var margin: CGFloat = 16
    /// The column C (one column), or the right pane's width (two panes).
    var columnWidth: CGFloat = 0
    /// Two panes: the left pane's width (dial, readout, status).
    var leftWidth: CGFloat = 0
    /// Two panes: the right pane's width (the same as `columnWidth`). 0 in one column.
    var trailingWidth: CGFloat = 0
    var dial: CGFloat = 0
    /// The owner's floor: min(ceil(0.40 H), the width cap).
    var floor: CGFloat = 0
    /// The dial's starting cap for this layout.
    var dialCap: CGFloat = 0
    /// The column plus its margins, less 2e.
    var widthCap: CGFloat = 0
    /// The dial as a share of the full height H.
    var share: CGFloat = 0
    var readoutScale: CGFloat = 1
    /// The heading number's size: 56 (96 on a tablet) × the readout scale.
    var headingSize: CGFloat = 56
    /// The readout's slot: the trimmed readout, or with no compass max(that, 40 × k) for "No heading".
    var readoutSlot: CGFloat = 0
    var statusLines: CGFloat = 1
    var statusHeight: CGFloat = 16
    /// The location card: 48 × k (56 × k on a tablet).
    var cardHeight: CGFloat = 48
    var grid: Grid = .quad
    var map: Map = .tile
    var sixth: Sixth = .pressure
    /// Large's Latitude and Longitude tiles (decimal degrees); other formats share one Position tile.
    var splitPosition = true
    /// The map card's height (0 without one).
    var mapHeight: CGFloat = 0
    /// The grid's rows, top to bottom.
    var rowHeights: [CGFloat] = []
    /// The Targets card's rows: 0, 1 or 2 (the lock row first).
    var targetsRows = 0
    var targetsRowHeight: CGFloat = 44
    /// The steps given up to keep the dial at its floor.
    var steps: Set<Step> = []
    /// A Mac window's title band (28) above the dial's gap; 0 elsewhere.
    var topBand: CGFloat = 0
    // The frozen gaps.
    var gapTopDial: CGFloat = 18
    var gapDialReadout: CGFloat = 12
    var gapReadoutStatus: CGFloat = 6
    var gapStatusCard: CGFloat = 12
    var gap: CGFloat = 8
    /// Under the stack: 0 over a home indicator, 16 without one, 24 in a Mac window.
    var bottomInset: CGFloat = 0
    /// Spare added above the dial (only when the stack is centred).
    var topExtra: CGFloat = 0
    /// Spare left under the stack: 24 or less unless `centred`.
    var bottomSpare: CGFloat = 0
    var centred = false
    /// Two panes: the right pane holds more than fits and scrolls (a phone on its side).
    var trailingScrolls = false
    /// Where the stack ends, from the top of the safe area.
    var end: CGFloat = 0
    /// Everything placed, from the top of the safe area (one column: it equals `end`).
    var used: CGFloat = 0

    // MARK: Positions (from the top of the safe area; two panes: the dial and the right pane share a top)

    var dialTop: CGFloat { topBand + gapTopDial + topExtra }
    var readoutTop: CGFloat { dialTop + dial + gapDialReadout }
    var statusTop: CGFloat { readoutTop + readoutSlot + gapReadoutStatus }
    var statusBottom: CGFloat { statusTop + statusHeight }
    /// The location card's top: under the status line, or (two panes) level with the dial.
    var locationTop: CGFloat { twoPane ? dialTop : statusBottom + gapStatusCard }
    var bannerTop: CGFloat { locationTop + cardHeight + gap }
    var hasTargets: Bool { targetsRows > 0 }
    var targetsHeight: CGFloat { CGFloat(targetsRows) * targetsRowHeight }
    /// The Targets card's top (where it would be when there is none).
    var targetsTop: CGFloat {
        let bannerPart: CGFloat = hasBanner ? Self.banner + gap : 0
        return locationTop + cardHeight + bannerPart + gap
    }
    var gridTop: CGFloat { hasTargets ? targetsTop + targetsHeight + gap : targetsTop }
    var gridHeight: CGFloat {
        guard !rowHeights.isEmpty else { return 0 }
        return rowHeights.reduce(0, +) + CGFloat(rowHeights.count - 1) * gap
    }
    var mapTop: CGFloat { gridHeight > 0 ? gridTop + gridHeight + gap : gridTop }
    /// The bottom of the last block.
    var contentBottom: CGFloat {
        if map == .card { return mapTop + mapHeight }
        if gridHeight > 0 { return gridTop + gridHeight }
        if hasTargets { return targetsTop + targetsHeight }
        return locationTop + cardHeight
    }
    /// The first row's height (for the self-tests' reports).
    var tileHeight: CGFloat { rowHeights.first ?? 0 }
    /// The list: the bottom of the Position row.
    var listFold: CGFloat { gridTop + (rowHeights.first ?? 0) }

    /// The location card carries the map button (Large and Extra Large, and wherever the map gave way).
    var mapInHeader: Bool { map == .button }
    /// Two panes in Large and Extra Large: a map card is on screen, so the header button is hidden (its slot kept).
    var mapButtonSlot: Bool { mapInHeader || (twoPane && (layout == .large || layout == .extraLarge)) }

    /// The owner's floor for this plan's layout: min(0.40 H, the column plus its margins less 2e).
    func ownerFloor(h: CGFloat) -> CGFloat {
        min(Self.ownerShare * h, columnWidth + 2 * margin - 2 * layout.e)
    }

    /// Large text (k ≥ 1.3): no three-column compact arrangement.
    var largeText: Bool { k >= Self.largeTextK - 0.001 }

    /// The compact row's widths, from C: Elevation = Sun = w = max(104, round(0.27 C)) and Position =
    /// C − 2 × 8 − 2w, so the row is exactly C wide.
    var compactWidths: (position: CGFloat, other: CGFloat) { Self.compactWidths(columnWidth) }

    static func compactWidths(_ c: CGFloat) -> (position: CGFloat, other: CGFloat) {
        let w = max(compactMin, (compactShare * c).rounded())
        return (c - 2 * rowGap - 2 * w, w)
    }

    /// Small's band: three columns 1.15 | 1 | 1 inside 12 padding each side and two 8 gaps.
    var bandWidths: [CGFloat] { Self.bandWidths(columnWidth) }
    static func bandWidths(_ c: CGFloat) -> [CGFloat] {
        let inner = c - 2 * bandPadding - 2 * rowGap
        let unit = inner / 3.15
        return [inner - 2 * unit, unit, unit]
    }

    /// Extra Large's strip: three columns 1.2 | 1 | 1 split by two 1 pt dividers.
    var stripWidths: [CGFloat] { Self.stripWidths(columnWidth) }
    static func stripWidths(_ c: CGFloat) -> [CGFloat] {
        let inner = c - 2 * divider
        let unit = inner / 3.2
        return [inner - 2 * unit, unit, unit]
    }

    /// The grid, row by row, exactly as MainView draws it: each row's widths plus its 8 gutters add up to C.
    var cells: [[Cell]] {
        let c = columnWidth, g = Self.rowGap, half = (c - g) / 2, third = (c - 2 * g) / 3
        func cell(_ tile: Tile, _ width: CGFloat) -> Cell { Cell(tile: tile, width: width) }
        // Small keeps a Map tile where the others keep Sun.
        let last: Tile = layout == .small && map == .tile ? .map : .sun
        let w = compactWidths
        switch grid {
        case .band:
            return []
        case .list:
            return [[cell(.position, c)], [cell(.elevation, c)], [cell(.sun, c)], [cell(.moon, c)]]
        case .quad:
            return [[cell(.position, half), cell(.elevation, half)],
                    [cell(.sun, half), cell(map == .tile ? .map : .moon, half)]]
        case .six:
            let first = splitPosition
                ? [cell(.latitude, third), cell(.longitude, third), cell(.elevation, third)]
                : [cell(.position, 2 * third + g), cell(.elevation, third)]
            return [first, [cell(.sunrise, third), cell(.moon, third), cell(.sixth, third)]]
        case .quadCompact:
            return [[cell(.position, half), cell(.elevation, half)], [cell(.sun, half), cell(.sixth, half)]]
        case .strip:
            return [[cell(.strip, c)]]
        case .twoRow:
            return [[cell(.position, c)], [cell(.elevation, half), cell(last, half)]]
        case .row:
            return [[cell(.position, w.position), cell(.elevation, w.other), cell(last, w.other)]]
        case .mapRows:
            if largeText {
                return [[cell(.position, c)], [cell(.elevation, half), cell(.sun, half)], [cell(.map, c)]]
            }
            return [[cell(.position, w.position), cell(.elevation, w.other), cell(.sun, w.other)], [cell(.map, c)]]
        }
    }

    /// Each row's tile widths, top to bottom.
    var rowWidths: [[CGFloat]] { cells.map { $0.map(\.width) } }

    // MARK: Constants (points; dp on Android). Spacing tokens are 4 / 8 / 12 / 16 / 24 only.

    /// Safe top → dial top, and under pressure.
    static let topGap: CGFloat = 18
    static let topGapTight: CGFloat = 12
    /// A Mac window's title band above that.
    static let macTitleBand: CGFloat = 28
    static let dialToReadout: CGFloat = 12
    /// × k.
    static let readoutToStatus: CGFloat = 6
    static let statusToCard: CGFloat = 12
    static let statusToCardTight: CGFloat = 8
    /// Location card → Targets card → grid → map card, between grid rows, and the gutters between tiles.
    static let rowGap: CGFloat = 8
    static let bottomPhone: CGFloat = 16
    static let marginPhone: CGFloat = 16
    /// iPad and Mac: 24 at the sides; the iPad column is min(W − 48, 720).
    static let marginLarge: CGFloat = 24
    static let macInset: CGFloat = 24
    static let maxColumn: CGFloat = 640
    static let maxColumnTablet: CGFloat = 720
    /// The location card: 48 (56 on a tablet) × k.
    static let card: CGFloat = 48
    static let cardTablet: CGFloat = 56
    static let heading: CGFloat = 56
    static let headingTablet: CGFloat = 96
    /// The readout's block, its line box trimmed: from the digits' cap height (0.72 of the size) to 4 under
    /// the baseline.
    static let readoutCap: CGFloat = 0.72
    static let readoutBelow: CGFloat = 4
    /// "No heading": 34 semibold on a 40 line.
    static let noHeadingSize: CGFloat = 34
    static let noHeadingLine: CGFloat = 40
    /// The status line's 13 pt line, unchanged by Concept A (the same 16 line on a tablet).
    static let statusLine: CGFloat = 16
    static let statusLineTablet: CGFloat = 16
    /// The Targets card's rows: 44 (Extra Large and iPad 52); 8 less under pressure.
    static let targetsRow: CGFloat = 44
    static let targetsRowLarge: CGFloat = 52
    static let targetsRowStep: CGFloat = 8
    /// The scrolling list's Targets rows (the cue on line 2).
    static let listTargetsRow: CGFloat = 84
    static let tile: CGFloat = 72
    static let tileTablet: CGFloat = 96
    /// `quadCompact`, `twoRow` and `mapRows`.
    static let tileCompact: CGFloat = 64
    /// Medium's rows grow to 88 (live, row 2 to 176); Large's to 104.
    static let tileGrown: CGFloat = 88
    static let tileTall: CGFloat = 176
    static let tileLarge: CGFloat = 104
    /// Medium's Sun tile adds the daylight and the moon once its row is this tall.
    static let tallSun: CGFloat = 150
    static let strip: CGFloat = 88
    static let stripTablet: CGFloat = 104
    static let stripGrown: CGFloat = 120
    /// Small's band along the map card's bottom: 68 × k, 12 padding, three columns 8 apart.
    static let band: CGFloat = 68
    static let bandPadding: CGFloat = 12
    /// The strip's dividers.
    static let divider: CGFloat = 1
    /// The compact row: Elevation and Sun are max(104, 0.27 C) wide.
    static let compactMin: CGFloat = 104
    static let compactShare: CGFloat = 0.27
    static let mapMin: CGFloat = 140
    /// Two panes: the map card is at least this tall (Small: also 60% of the pane).
    static let mapPane: CGFloat = 240
    static let mapPaneSmall: CGFloat = 0.60
    /// The scrolling list: tiles 96, the Map tile 176.
    static let listRow: CGFloat = 96
    static let listMap: CGFloat = 176
    /// The most ever left empty at the bottom (unless the stack is centred).
    static let maxSpare: CGFloat = 24
    /// The owner's hard rule: the compass takes up at least 40% of the screen.
    static let ownerShare: CGFloat = 0.40
    /// Large text: the three-column arrangements become two rows.
    static let largeTextK: CGFloat = 1.3
    static let dialMin: CGFloat = 120
    /// Moving: Large's sixth tile shows Speed from this many metres a second.
    static let movingSpeed: Double = 0.5
    /// A window whose shorter side is at least this is a tablet (iPad, or a large Mac window).
    static let tabletSide: CGFloat = 700
    static let twoPaneWidth: CGFloat = 700
    static let landscapePhone: CGFloat = 480
    /// Two panes: the right pane is 360 to 560 wide, 32 from the left pane.
    static let paneMin: CGFloat = 360
    static let paneMax: CGFloat = 560
    static let paneGap: CGFloat = 32
    /// The Mac's update banner (44), between the location card and the Targets card.
    static let banner: CGFloat = 44
    static let bannerGap: CGFloat = 8
    /// The text multiplier's cap on Apple devices.
    static let maxK: CGFloat = 1.3
    /// The Mac window's smallest size: every layout with the sample fits without scrolling.
    static let macMinWidth: CGFloat = 420
    static let macMinHeight: CGFloat = 780

    // MARK: Heights, shared with MainView so what it draws is what was planned

    static func cardHeight(k: CGFloat, tablet: Bool) -> CGFloat { (tablet ? cardTablet : card) * k }
    /// The readout's trimmed block: cap height to 4 under the baseline.
    static func readoutHeight(headingSize: CGFloat) -> CGFloat { headingSize * readoutCap + readoutBelow }
    /// The readout's slot: with no compass it also holds "No heading" on its 40 × k line.
    static func readoutSlot(headingSize: CGFloat, k: CGFloat, noCompass: Bool) -> CGFloat {
        let readout = readoutHeight(headingSize: headingSize)
        return noCompass ? max(readout, noHeadingLine * k) : readout
    }
    static func statusHeight(k: CGFloat, lines: CGFloat, tablet: Bool = false) -> CGFloat {
        (tablet ? statusLineTablet : statusLine) * k * lines
    }
    static func targetsRowHeight(layout: Layout, k: CGFloat, tablet: Bool, compact: Bool) -> CGFloat {
        let base: CGFloat = layout == .extraLarge || tablet ? targetsRowLarge : targetsRow
        return (compact ? base - targetsRowStep : base) * k
    }
    /// The sixth tile for a speed in metres a second.
    static func sixth(speed: Double?) -> Sixth { (speed ?? 0) >= movingSpeed ? .speed : .pressure }
    /// Rounded up to a multiple of 8.
    static func ceil8(_ v: CGFloat) -> CGFloat { (v / 8 - 0.0001).rounded(.up) * 8 }

    // MARK: The planner

    /// Everything the planner is given.
    private struct Input {
        var w: CGFloat
        var h: CGFloat
        var s: CGFloat
        var layout: Layout
        var k: CGFloat
        var accessibilityText: Bool
        var hasSpot: Bool
        var locked: Bool
        var noCompass: Bool
        var banner: Bool
        var mac: Bool
        var landscapePhone: Bool
        var home: Bool
        var topBand: CGFloat
        var speed: Double?
        var split: Bool
    }

    /// `w` the window's (safe) width, `h` its full height including the safe-area insets, `s` the safe
    /// height, `k` the Text Size multiplier (capped at 1.3), `accessibilityText` an accessibility Text Size.
    /// `locked` and `hasSpot` the Targets card's rows; `noCompass` "No heading"; `mac` a Mac window.
    /// `homeIndicator`: the stack ends at the safe bottom (nil: guessed from H − S). `topBand`: a Mac
    /// window's title band still inside the safe area (nil: 28 on a Mac). `speed` picks Large's sixth tile;
    /// `splitPosition` (decimal degrees) gives Large its Latitude and Longitude tiles. `neighbours` keeps the
    /// dials in order (each at most the next layout's; Extra Large at least Large's).
    static func plan(w: CGFloat, h: CGFloat, s: CGFloat, layout: Layout = .default, k: CGFloat = 1,
                     accessibilityText: Bool = false, hasSpot: Bool = false, locked: Bool = false,
                     noCompass: Bool = false, hasUpdateBanner: Bool = false, mac: Bool = false,
                     isLandscapePhone: Bool = false, homeIndicator: Bool? = nil, topBand: CGFloat? = nil,
                     speed: Double? = nil, splitPosition: Bool = true, neighbours: Bool = true) -> LayoutPlan {
        let input = Input(w: w, h: h, s: s, layout: layout, k: min(max(k, 1), maxK),
                          accessibilityText: accessibilityText, hasSpot: hasSpot, locked: locked,
                          noCompass: noCompass, banner: hasUpdateBanner, mac: mac, landscapePhone: isLandscapePhone,
                          home: homeIndicator ?? (!mac && h - s > 30), topBand: topBand ?? (mac ? macTitleBand : 0),
                          speed: speed, split: splitPosition)
        return plan(input, neighbours: neighbours)
    }

    private static func plan(_ i: Input, neighbours: Bool) -> LayoutPlan {
        if i.accessibilityText { return listPlan(i) }
        if i.landscapePhone || (i.w > i.h && (i.w >= twoPaneWidth || i.s < landscapePhone)) { return twoPanePlan(i) }
        var limit = CGFloat.infinity
        var want: CGFloat?
        if neighbours {
            if i.layout == .extraLarge {
                // Extra Large keeps at least Large's dial where it can (it gives way further for it).
                var large = i
                large.layout = .large
                if let l = core(large, limit: .infinity, want: nil) { want = l.dial }
            } else if let next = i.layout.larger {
                // Every other layout stays at or under the next one's dial.
                var n = i
                n.layout = next
                let p = plan(n, neighbours: true)
                if !p.list && !p.twoPane { limit = p.dial }
            }
        }
        return core(i, limit: limit, want: want) ?? listPlan(i)
    }

    /// What every arrangement shares.
    private static func base(_ i: Input) -> LayoutPlan {
        var p = LayoutPlan()
        p.layout = i.layout
        p.k = i.k
        p.mac = i.mac
        p.locked = i.locked
        p.hasSpot = i.hasSpot
        p.noCompass = i.noCompass
        p.hasBanner = i.banner
        p.accessibilityText = i.accessibilityText
        p.tablet = min(i.w, i.h) >= tabletSide
        p.margin = i.mac || p.tablet ? marginLarge : marginPhone
        p.columnWidth = min(i.w - 2 * p.margin, p.tablet ? maxColumnTablet : maxColumn)
        p.widthCap = p.columnWidth + 2 * p.margin - 2 * i.layout.e
        p.readoutScale = i.layout.readoutScale
        p.headingSize = (p.tablet ? headingTablet : heading) * i.layout.readoutScale
        p.readoutSlot = readoutSlot(headingSize: p.headingSize, k: i.k, noCompass: i.noCompass)
        p.statusLines = i.k > 1.1 ? 2 : 1
        p.statusHeight = statusHeight(k: i.k, lines: p.statusLines, tablet: p.tablet)
        p.cardHeight = cardHeight(k: i.k, tablet: p.tablet)
        p.gapReadoutStatus = readoutToStatus * i.k
        p.sixth = sixth(speed: i.speed)
        p.splitPosition = i.split
        p.targetsRows = (i.locked ? 1 : 0) + (i.hasSpot ? 1 : 0)
        p.topBand = i.topBand
        p.bottomInset = i.home ? 0 : (i.mac ? macInset : bottomPhone)
        p.end = i.s - p.bottomInset
        p.floor = min((ownerShare * i.h - 0.001).rounded(.up), p.widthCap)
        return p
    }

    /// The grid and map surface for a layout with the steps it has given up.
    private static func gridAndMap(_ layout: Layout, largeText: Bool, tablet: Bool, steps: Set<Step>) -> (Grid, Map) {
        switch layout {
        case .small:
            if steps.contains(.button) { return (largeText ? .twoRow : .row, .tile) }
            if steps.contains(.mapTile) { return (.mapRows, .tile) }
            return (largeText ? .twoRow : .band, .card)
        case .medium:
            if steps.contains(.button) { return (largeText ? .twoRow : .row, .button) }
            return (.quad, tablet && !steps.contains(.mapTile) ? .card : .tile)
        case .large:
            if steps.contains(.button) { return (largeText ? .twoRow : .row, .button) }
            if steps.contains(.dense) || largeText { return (.quadCompact, .button) }
            return (.six, .button)
        case .extraLarge:
            return (largeText ? .twoRow : .strip, .button)
        }
    }

    /// Whether a step means anything for this plan.
    private static func applies(_ step: Step, to p: LayoutPlan) -> Bool {
        switch step {
        case .tight: return true
        case .compactRows: return p.hasTargets
        case .dense: return p.layout == .large && !p.largeText
        case .mapTile: return p.layout == .small || (p.layout == .medium && p.tablet)
        case .button: return p.layout != .extraLarge
        }
    }

    /// The grid's rows at their smallest.
    private static func minRows(_ grid: Grid, k: CGFloat, tablet: Bool, largeText: Bool) -> [CGFloat] {
        let t = (tablet ? tileTablet : tile) * k, compact = tileCompact * k
        switch grid {
        case .band, .list: return []
        case .quad, .six: return [t, t]
        case .quadCompact, .twoRow: return [compact, compact]
        case .row: return [tile * k]
        case .mapRows: return largeText ? [compact, compact, compact] : [compact, compact]
        case .strip: return [(tablet ? stripTablet : strip) * k]
        }
    }

    /// Applies a set of given-up steps: the gaps, the Targets rows, the grid and the map at their smallest.
    private static func apply(_ steps: Set<Step>, to p: inout LayoutPlan) {
        let tight = steps.contains(.tight)
        p.gapTopDial = tight ? topGapTight : topGap
        p.gapStatusCard = tight ? statusToCardTight : statusToCard
        p.targetsRowHeight = targetsRowHeight(layout: p.layout, k: p.k, tablet: p.tablet, compact: steps.contains(.compactRows))
        let surface = gridAndMap(p.layout, largeText: p.largeText, tablet: p.tablet, steps: steps)
        p.grid = surface.0
        p.map = surface.1
        p.rowHeights = minRows(p.grid, k: p.k, tablet: p.tablet, largeText: p.largeText)
        p.mapHeight = p.map == .card ? mapMin : 0
        p.steps = steps
    }

    /// Everything but the dial, with these steps given up, from the top of the safe area.
    private static func fixedHeight(_ p: LayoutPlan, steps: Set<Step>) -> CGFloat {
        var q = p
        apply(steps, to: &q)
        q.topExtra = 0
        q.dial = 0
        return q.contentBottom
    }

    /// One column. Nil when even every step leaves the dial under its floor (the list then).
    private static func core(_ i: Input, limit: CGFloat, want: CGFloat?) -> LayoutPlan? {
        var p = base(i)
        let k = i.k
        var cap = p.widthCap, grow = p.widthCap
        if let share = i.layout.capShare {
            cap = min(ceil8(share * i.h), p.widthCap)
            // Small and Medium stay at their cap; Large may grow to its width cap from spare.
            if i.layout != .large { grow = cap }
        }
        cap = min(cap, limit)
        grow = min(grow, limit)
        p.dialCap = cap
        let target: CGFloat = want.map { max(p.floor, min($0, cap)) } ?? p.floor
        apply([], to: &p)
        var steps: Set<Step> = []
        var taken: [Step] = []
        if p.end - fixedHeight(p, steps: steps) < target - 0.5 {
            for step in Step.allCases where applies(step, to: p) {
                steps.insert(step)
                taken.append(step)
                if p.end - fixedHeight(p, steps: steps) >= target - 0.5 { break }
            }
        }
        let room = p.end - fixedHeight(p, steps: steps)
        if room < p.floor - 0.5 { return nil }
        var dial = min(cap, room)
        if dial < p.floor - 0.5 { return nil }
        var spare = room - dial
        // What fits comes back, last given up first.
        for step in taken.reversed() {
            var without = steps
            without.remove(step)
            let cost = fixedHeight(p, steps: without) - fixedHeight(p, steps: steps)
            if cost <= spare + 0.001 {
                steps = without
                spare -= cost
            }
        }
        apply(steps, to: &p)
        // The layout's growth.
        if p.map == .card {
            p.mapHeight += spare
            spare = 0
        } else if !p.tablet && !p.rowHeights.isEmpty {
            let rowCap: CGFloat
            if p.grid == .strip {
                rowCap = stripGrown * k
            } else if i.layout == .large {
                rowCap = tileLarge * k
            } else {
                rowCap = tileGrown * k
            }
            let n = CGFloat(p.rowHeights.count)
            let add = max(0, min(rowCap - p.rowHeights[0], spare / n))
            p.rowHeights = p.rowHeights.map { $0 + add }
            spare -= add * n
            // Live Medium: row 2 grows on to 176 (the Sun tile adds the daylight and the moon).
            if i.layout == .medium && p.grid == .quad && !p.hasTargets && p.rowHeights.count == 2 {
                let more = max(0, min(tileTall * k - p.rowHeights[1], spare))
                p.rowHeights[1] += more
                spare -= more
            }
        }
        // Then the dial, up to its width cap (Large, Extra Large).
        let add = max(0, min(grow - dial, spare))
        dial += add
        spare -= add
        // Then at most 24 at the bottom; anything more centres the stack.
        p.bottomSpare = min(maxSpare, spare)
        spare -= p.bottomSpare
        if spare > 0.5 {
            p.centred = true
            p.topExtra = spare / 2
            p.bottomSpare += spare / 2
        }
        p.dial = dial
        p.share = dial / i.h
        p.used = p.contentBottom + p.bottomSpare
        return p
    }

    /// Accessibility sizes, or nothing fits: one scrolling list. The dial keeps the owner's 0.40 H.
    private static func listPlan(_ i: Input) -> LayoutPlan {
        var p = base(i)
        p.list = true
        p.twoPane = false
        p.grid = .list
        p.map = .tile
        p.dial = max(min(ceil8(ownerShare * i.h), p.widthCap), p.floor)
        p.dialCap = p.dial
        p.share = p.dial / i.h
        p.statusLines = 2
        p.statusHeight = statusHeight(k: i.k, lines: 2, tablet: p.tablet)
        p.rowHeights = Array(repeating: listRow, count: 4)
        p.mapHeight = listMap
        p.targetsRowHeight = listTargetsRow
        p.used = p.contentBottom + gapAboveListMap + listMap
        return p
    }

    /// The list's Map tile sits 8 under the last row.
    static let gapAboveListMap: CGFloat = 8

    /// Two panes (iPad landscape, wide Mac windows, a phone on its side): no full-width header. The dial,
    /// readout and status line top-aligned in the left pane; the location card, the Targets card, the grid
    /// and a map card (240 or more) in the right pane, level with the dial.
    private static func twoPanePlan(_ i: Input) -> LayoutPlan {
        var p = base(i)
        p.twoPane = true
        p.margin = marginLarge
        let right = min(max(i.layout.rightShare * i.w, paneMin), paneMax)
        p.trailingWidth = right
        p.columnWidth = right
        p.leftWidth = i.w - 2 * marginLarge - paneGap - right
        p.widthCap = p.leftWidth
        apply([], to: &p)
        let group = p.gapDialReadout + p.readoutSlot + p.gapReadoutStatus + p.statusHeight
        let dial = min(p.leftWidth, p.end - p.topBand - p.gapTopDial - group, i.layout.paneShare * i.h)
        if dial < dialMin { return listPlan(i) }
        p.dial = dial
        p.floor = dial
        p.dialCap = dial
        p.share = dial / i.h
        // The right pane always ends with a map card (so Medium's quad is Sun | Moon).
        p.map = .card
        let pane = p.end - p.topBand - p.gapTopDial
        // Split up so the type checker never has to solve one long mixed expression.
        let bannerPart: CGFloat = p.hasBanner ? banner + bannerGap : 0
        let targetsPart: CGFloat = p.hasTargets ? p.gap + p.targetsHeight : 0
        let gridPart: CGFloat = p.gridHeight > 0 ? p.gap + p.gridHeight : 0
        let above: CGFloat = p.cardHeight + bannerPart + targetsPart + gridPart + p.gap
        let least: CGFloat = i.layout == .small ? max(mapPane, mapPaneSmall * pane) : mapPane
        p.mapHeight = max(least, pane - above)
        p.trailingScrolls = above + p.mapHeight > pane + 0.5
        p.bottomSpare = max(0, pane - above - p.mapHeight)
        p.used = p.contentBottom + p.bottomSpare
        return p
    }

    // MARK: The golden table (docs/REFINE.md A.4 and A.11)

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

    /// The golden devices: the four layouts must look different in the sample state on these.
    static let goldenDevices: Set<String> = ["iPhone 16", "iPhone 16 Pro"]

    /// Nothing (live), locked, marked, both (the sample).
    static let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    /// Runs the whole table (devices × layouts × states × compass or not × text sizes × banner) and returns
    /// the cases that break a rule: the owner's 0.40 H in portrait (the list too), a gap that isn't its token,
    /// anything above the dial, the location card not under the status line, the Targets card's rows, more
    /// than 24 empty at the bottom (unless centred), anything cut, a row whose widths don't add up to C, the
    /// dials out of order, neighbouring layouts that are the same plan, four landscape plans that aren't four,
    /// and the worked numbers. Empty when all is well.
    static func tableFailures() -> [String] {
        var failures: [String] = []
        let textSizes: [(CGFloat, Bool)] = [(1, false), (1.15, false), (1.3, false), (1.3, true)]
        for d in devices {
            for state in states {
                for (k, acc) in textSizes {
                    for banner in [false, true] where !banner || d.mac {
                        for noCompass in [false, true] {
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
                            guard !acc else { continue }
                            let golden = goldenDevices.contains(d.name) && state.locked && state.spot && !banner && !noCompass
                            failures += distinct(plans, k: k, golden: golden,
                                                 name: "\(d.name) \(state.name) k\(k)\(banner ? " banner" : "")\(noCompass ? " no compass" : "")")
                        }
                    }
                }
            }
        }
        failures += workedNumbers()
        return failures
    }

    /// The worked numbers (docs/REFINE.md A.3, A.4, A.6).
    static func workedNumbers() -> [String] {
        var failures: [String] = []
        // iPhone 16 Pro, 402 × 874, S = 778, the sample (locked and marked).
        func pro(_ layout: Layout, sample: Bool = true) -> LayoutPlan {
            plan(w: 402, h: 874, s: 778, layout: layout, hasSpot: sample, locked: sample)
        }
        let small = pro(.small), medium = pro(.medium), large = pro(.large), xl = pro(.extraLarge)
        let smallOK = small.grid == .band && small.map == .card && abs(small.dial - 352) <= 0.5
            && abs(small.mapHeight - 166) <= 2
        if !smallOK {
            failures.append("16 Pro Small sample: \(small.description), expected dial 352, band, map card ≈ 166")
        }
        let mediumSurface: Bool = medium.grid == .quad && medium.map == .tile && medium.targetsRows == 2
        let mediumDial: Bool = abs(medium.dial - 352) <= 0.5 && abs(medium.tileHeight - 79) <= 1.5
        let mediumCard: CGFloat = medium.locationTop + 62
        let mediumEnd: CGFloat = medium.used + 62
        let mediumStack: Bool = abs(mediumCard - 522.3) <= 2 && abs(medium.targetsRowHeight - 44) <= 0.5
            && abs(mediumEnd - 840) <= 0.5
        if !(mediumSurface && mediumDial && mediumStack) {
            failures.append("16 Pro Medium sample: \(medium.description), location card at \(Int(medium.locationTop + 62)), expected dial 352, the location card at ≈ 522 on screen, tiles ≈ 79, end 840")
        }
        let largeOK = large.grid == .six && large.map == .button && abs(large.dial - 365.7) <= 1
            && abs(large.tileHeight - 72) <= 0.5
        if !largeOK {
            failures.append("16 Pro Large sample: \(large.description), expected dial ≈ 365, six, tiles 72")
        }
        let xlOK = xl.grid == .strip && xl.map == .button && abs(xl.dial - 386) <= 0.5
            && abs(xl.readoutScale - 1.25) <= 0.001 && abs(xl.targetsRowHeight - 52) <= 0.5
        if !xlOK {
            failures.append("16 Pro Extra Large sample: \(xl.description), expected dial 386, strip, rows 52")
        }
        // Live: Medium's row 1 at 88 and row 2 grown; Large's rows at 104 and its dial at the width cap.
        let liveMedium = pro(.medium, sample: false), liveLarge = pro(.large, sample: false)
        let liveMediumOK = !liveMedium.hasTargets && liveMedium.rowHeights.count == 2
            && abs(liveMedium.rowHeights[0] - tileGrown) <= 0.5 && liveMedium.rowHeights[1] >= tallSun
        let liveLargeOK = abs(liveLarge.tileHeight - tileLarge) <= 0.5 && abs(liveLarge.dial - 386) <= 0.5
        if !(liveMediumOK && liveLargeOK) {
            failures.append("16 Pro live: Medium \(liveMedium.description); Large \(liveLarge.description)")
        }
        // iPhone SE, Medium, the sample: steps 2, 3 and 6 keep a 272 dial; the rows and gaps come back and the
        // row grows to 88.
        let se = plan(w: 375, h: 667, s: 647, hasSpot: true, locked: true)
        let seOK = abs(se.dial - 272) <= 0.5 && se.grid == .row && se.map == .button
            && abs(se.tileHeight - tileGrown) <= 0.5 && se.steps == [.button]
        if !seOK {
            failures.append("iPhone SE Medium sample: \(se.description), expected dial 272 · compact · map button")
        }
        // The compact row at C = 370, 380 and 700: 146 | 104 | 104, 156 | 104 | 104, 306 | 189 | 189.
        let w370 = compactWidths(370), w380 = compactWidths(380), w700 = compactWidths(700)
        if w370.position != 146 || w370.other != 104 || w380.position != 156 || w380.other != 104
            || w700.position != 306 || w700.other != 189 {
            failures.append("Compact row widths: \(w370) at 370, \(w380) at 380, \(w700) at 700")
        }
        // The smallest Mac window holds every layout with the sample without scrolling.
        for layout in Layout.allCases where plan(w: macMinWidth, h: macMinHeight, s: macMinHeight, layout: layout,
                                                 hasSpot: true, locked: true, mac: true).list {
            failures.append("Mac \(Int(macMinWidth)) × \(Int(macMinHeight)): \(layout.rawValue) scrolls")
        }
        if sixth(speed: nil) != .pressure || sixth(speed: 0.4) != .pressure || sixth(speed: 0.5) != .speed {
            failures.append("Large's sixth tile: Pressure when still, Speed from 0.5 m/s")
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
        // The owner's hard rule: in one column, portrait, the dial is at least min(0.40 H, its width cap),
        // in the list too.
        if !p.twoPane && d.h >= d.w && p.dial < p.ownerFloor(h: d.h) - 0.5 {
            failures.append("\(name): dial \(Int(p.dial)) is \(Int((100 * p.dial / d.h).rounded()))% of H, under the owner's floor \(Int(p.ownerFloor(h: d.h)))")
        }
        // The frozen gaps.
        let tight = p.steps.contains(.tight)
        let gaps: [(CGFloat, CGFloat, String)] = [
            (p.gapTopDial, tight ? topGapTight : topGap, "safe top → dial"),
            (p.gapDialReadout, dialToReadout, "dial → readout"),
            (p.gapReadoutStatus, readoutToStatus * k, "readout → status"),
            (p.gapStatusCard, tight ? statusToCardTight : statusToCard, "status → location card"),
            (p.gap, rowGap, "between blocks"),
        ]
        for (gap, token, what) in gaps where abs(gap - token) > 0.01 {
            failures.append("\(name): \(what) is \(gap), not \(token)")
        }
        if d.mac && (p.margin < macInset - 0.5 || (!p.list && abs(p.bottomInset - macInset) > 0.5)) {
            failures.append("\(name): Mac edges \(Int(p.margin)) / \(Int(p.bottomInset)), expected 24")
        }
        // Every row's widths and gutters add up to C.
        for row in p.rowWidths {
            let sum = row.reduce(0, +) + CGFloat(row.count - 1) * rowGap
            if abs(sum - p.columnWidth) > 0.5 { failures.append("\(name): a row is \(Int(sum)) wide in a column of \(Int(p.columnWidth))") }
            if (p.grid == .row || p.grid == .mapRows) && row.count == 3 && row.contains(where: { $0 < compactMin - 0.5 }) {
                failures.append("\(name): a compact tile under \(Int(compactMin))")
            }
            if p.largeText && row.count == 3 && p.grid != .six {
                failures.append("\(name): a three-column compact row at large text")
            }
        }
        let bandSum: CGFloat = p.bandWidths.reduce(0, +) + 2 * bandPadding + 2 * rowGap
        let stripSum: CGFloat = p.stripWidths.reduce(0, +) + 2 * divider
        if abs(bandSum - p.columnWidth) > 0.5 || abs(stripSum - p.columnWidth) > 0.5 {
            failures.append("\(name): the band or strip doesn't add up to C")
        }
        // The Targets card: a row for each target, at its height.
        if p.targetsRows != (p.locked ? 1 : 0) + (p.hasSpot ? 1 : 0) { failures.append("\(name): \(p.targetsRows) Targets rows") }
        if p.list { return failures }
        let rowBase: CGFloat = p.layout == .extraLarge || p.tablet ? targetsRowLarge : targetsRow
        if abs(p.targetsRowHeight - rowBase * k) > 0.5 && abs(p.targetsRowHeight - (rowBase - targetsRowStep) * k) > 0.5 {
            failures.append("\(name): Targets rows \(Int(p.targetsRowHeight))")
        }
        if (p.layout == .large || p.layout == .extraLarge) && !p.twoPane && p.map != .button {
            failures.append("\(name): \(p.layout.rawValue) shows the map as \(p.map)")
        }
        if p.twoPane {
            if p.dial < dialMin - 0.5 { failures.append("\(name): two panes, dial \(Int(p.dial))") }
            if p.map != .card || p.mapHeight < mapPane - 0.5 { failures.append("\(name): two panes, map card \(Int(p.mapHeight))") }
            if p.locationTop != p.dialTop { failures.append("\(name): two panes, the location card isn't level with the dial") }
            if !p.trailingScrolls && p.bottomSpare > maxSpare + 0.5 {
                failures.append("\(name): two panes, \(Int(p.bottomSpare)) empty under the map card")
            }
            return failures
        }
        // Nothing above the dial; the location card under the status line.
        if p.locationTop < p.dialTop + p.dial { failures.append("\(name): the location card is above the dial") }
        if abs(p.locationTop - (p.statusBottom + p.gapStatusCard)) > 0.5 { failures.append("\(name): the location card isn't under the status line") }
        if p.map == .card && p.mapHeight < mapMin - 0.5 { failures.append("\(name): map card \(Int(p.mapHeight))") }
        if p.bottomSpare > maxSpare + 0.5 && !p.centred { failures.append("\(name): \(Int(p.bottomSpare)) empty at the bottom") }
        if p.used > p.end + 0.5 { failures.append("\(name): \(Int(p.used - p.end)) cut off") }
        if p.used < p.end - 0.5 { failures.append("\(name): \(Int(p.end - p.used)) unaccounted for") }
        if p.dial > p.widthCap + 0.5 { failures.append("\(name): dial \(Int(p.dial)) over its width cap \(Int(p.widthCap))") }
        // The golden devices in the sample state: no empty band wider than 24.
        if goldenDevices.contains(d.name) && p.locked && p.hasSpot && k == 1 && (p.centred || p.bottomSpare > maxSpare + 0.5) {
            failures.append("\(name): an empty band of \(Int(max(p.topExtra, p.bottomSpare)))")
        }
        return failures
    }

    /// The layouts differ (A.4): the dials rise from Small to Extra Large; neighbours differ in at least one
    /// of grid, map surface or dial; on the golden devices in the sample state each layout has its own grid
    /// (band, quad, six, strip) and map surface (card, tile, button, button). In two panes (landscape, at
    /// Text Size 1.0) the four grids are four.
    private static func distinct(_ plans: [LayoutPlan], k: CGFloat, golden: Bool, name: String) -> [String] {
        var failures: [String] = []
        if plans.allSatisfy(\.twoPane) {
            if k == 1 && Set(plans.map(\.grid)).count != plans.count { failures.append("\(name) landscape: two plans share a grid") }
            return failures
        }
        for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
            if b.dial < a.dial - 0.5 {
                failures.append("\(name): \(b.layout.rawValue)'s dial \(Int(b.dial)) is under \(a.layout.rawValue)'s \(Int(a.dial))")
            }
            if a.grid == b.grid && a.map == b.map && abs(a.dial - b.dial) < 0.5 {
                failures.append("\(name): \(a.layout.rawValue) and \(b.layout.rawValue) are the same plan")
            }
        }
        if golden && k == 1 {
            let grids = plans.map(\.grid), maps = plans.map(\.map)
            if grids != [.band, .quad, .six, .strip] || maps != [.card, .tile, .button, .button] {
                failures.append("\(name): grids \(grids.map(\.rawValue)), maps \(maps.map(\.rawValue))")
            }
        }
        return failures
    }

    /// One line per layout for a device and state: "medium: dial 352 (40% of H), quad, map tile, tiles 79,
    /// bottom 0". For the self-tests' reports.
    static func summary(w: CGFloat, h: CGFloat, s: CGFloat, hasSpot: Bool, locked: Bool, noCompass: Bool = false,
                        mac: Bool = false) -> [String] {
        Layout.allCases.map { (layout: Layout) -> String in
            let p = plan(w: w, h: h, s: s, layout: layout, hasSpot: hasSpot, locked: locked, noCompass: noCompass, mac: mac)
            return "\(layout.rawValue): \(p.description)"
        }
    }

    /// "dial 352 (40% of H), quad, map tile, tiles 79, bottom 0".
    var description: String {
        let dialText = "dial \(Int(dial.rounded())) (\(Int((100 * share).rounded()))% of H)"
        if list { return "\(dialText), scrolling list" }
        let mapText: String
        switch map {
        case .tile: mapText = "map tile"
        case .card: mapText = "map card \(Int(mapHeight.rounded()))"
        case .button: mapText = "map button"
        }
        let rows = rowHeights.map { "\(Int($0.rounded()))" }.joined(separator: "/")
        let stepNames: [String] = steps.sorted { $0.rawValue < $1.rawValue }.map { String(describing: $0) }
        let gaveUp: String = stepNames.isEmpty ? "" : ", gave up " + stepNames.joined(separator: " ")
        let spare = Int(bottomSpare.rounded())
        let foot: String
        if twoPane {
            foot = "pane spare \(spare)" + (trailingScrolls ? ", scrolls" : "")
        } else {
            foot = "bottom \(spare)" + (centred ? " (centred)" : "")
        }
        let tiles: String = rows.isEmpty ? "none" : rows
        let targets = "Targets \(targetsRows) × \(Int(targetsRowHeight.rounded()))"
        return "\(dialText), \(grid.rawValue), \(mapText), \(targets), tiles \(tiles)\(gaveUp), \(foot)"
    }
}
