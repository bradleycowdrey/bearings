import CoreGraphics
import XCTest
@testable import Bearings

/// The "Instrument panel" planner (docs/REFINE.md §3 and Cycle 3 §C3.3, one rule set with Android;
/// docs/LAYOUTS.md): the header pinned at the safe top + 8, every gap a frozen token × k, spare spent in a
/// fixed order (dial → map card → tile growth → top and bottom, each 24 or less, else centred), nothing
/// cut, every row's widths adding up to C, and the four layouts different from each other (grid mode, and
/// between Medium and Large the map surface and 16 of dial), and the owner's hard rule: in portrait, short of
/// the accessibility sizes, no dial under 0.40 H. The same golden table runs in the Mac and
/// iPhone self-tests (which also check the drawing against the plan) and, ported, on Android.
final class LayoutPlanTests: XCTestCase {
    /// Width, full height, safe height (pt; dp on the Pixel), and a Mac window.
    private let phones: [(name: String, w: CGFloat, h: CGFloat, s: CGFloat, mac: Bool)] = [
        ("iPhone SE", 375, 667, 647, false),
        ("iPhone 16", 393, 852, 759, false),
        ("iPhone 16 Pro", 402, 874, 778, false),
        ("iPhone 17 Pro Max", 440, 956, 862, false),
        ("Pixel 7", 412, 915, 839, false),
        ("Mac 420x840", 420, 840, 840, true),
        ("Mac 420x780", 420, 780, 780, true),
        ("iPad 11 portrait", 834, 1210, 1166, false),
        ("iPad 13 portrait", 1032, 1376, 1332, false),
    ]
    private let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    func testGoldenTable() {
        XCTAssertEqual(LayoutPlan.tableFailures(), [])
    }

    func testFrozenRhythm() {
        for d in phones {
            for layout in Layout.allCases {
                for state in states {
                    for k in [CGFloat(1), 1.3] {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k,
                                                hasSpot: state.spot, locked: state.locked, mac: d.mac)
                        let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)"
                        // The header is pinned, and every gap is its token × k, in the list too.
                        XCTAssertEqual(p.topInset, d.mac ? 24 : 8, name)
                        XCTAssertEqual(p.gapHeaderDial, 12 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapDialReadout, 12 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapReadoutStatus, 6 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapStatusRows, 8 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapRows, 8 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapGridMap, 12 * p.k, accuracy: 0.01, name)
                        if p.list {
                            XCTAssertEqual(p.grid, .list, name)
                            XCTAssertEqual(p.map, .card, name)
                            XCTAssertGreaterThanOrEqual(p.dial, LayoutPlan.dialMin - 0.5, name)
                            XCTAssertGreaterThanOrEqual(p.dial, p.ownerFloor(h: d.h) - 0.5, "\(name): list dial under 0.40 H")
                            continue
                        }
                        XCTAssertFalse(p.twoPane, name)
                        if !p.centred {
                            XCTAssertLessThanOrEqual(p.bottomSpare, LayoutPlan.maxSpare + 0.5, "\(name): empty at the bottom")
                            XCTAssertLessThanOrEqual(p.topExtra, LayoutPlan.maxSpare + 0.5, "\(name): empty under the header")
                        } else {
                            XCTAssertEqual(p.topExtra, p.bottomSpare, accuracy: 0.5, "\(name): centred")
                        }
                        XCTAssertLessThanOrEqual(p.used, d.s + 0.5, "\(name): cut off")
                        XCTAssertGreaterThanOrEqual(p.used, d.s - 0.5, "\(name): height unaccounted for")
                        XCTAssertGreaterThanOrEqual(p.dial + 0.5, p.floor, "\(name): dial under its floor")
                        // The owner's rule: 0.40 H (or the width cap) at Text Size 1.0 and 1.3.
                        XCTAssertGreaterThanOrEqual(p.dial, p.ownerFloor(h: d.h) - 0.5, "\(name): dial under 0.40 H")
                        // Only Medium grows its tiles, and only on a phone, to 88.
                        let base = (p.tablet ? LayoutPlan.tileTablet : LayoutPlan.tile) * p.k
                        if p.layout == .medium && !p.tablet {
                            XCTAssertLessThanOrEqual(p.tileHeight, LayoutPlan.tileGrown * p.k + 0.5, name)
                        } else {
                            XCTAssertEqual(p.tileHeight, base, accuracy: 0.5, name)
                        }
                        // Large and Extra Large put the map in the header on every device.
                        if p.layout == .large || p.layout == .extraLarge { XCTAssertEqual(p.map, .button, name) }
                        // A map card is 140 or more; only Small's map tile (its card shrunk for the owner's
                        // rule) is less, and never under a tile.
                        if p.mapStrip {
                            XCTAssertGreaterThanOrEqual(p.mapHeight, p.tileHeight - 0.5, "\(name): map tile")
                        } else if p.map == .card {
                            XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapMin - 0.5, "\(name): map card")
                        }
                        if p.grid == .compact { XCTAssertNotEqual(p.map, .tile, name) }
                        XCTAssertEqual(p.mapInHeader, p.map == .button, name)
                    }
                }
            }
        }
    }

    /// The worked numbers on iPhone 16 Pro (402 × 874, S = 778, C = 370, 0.40 H = 350). With the sample
    /// (locked + marked) no layout's own grid fits at the owner's 0.40 H, so each gives up its grid or map
    /// card (not the dial): Small 350, Medium 370, Large 386, Extra Large 386, all on the compact row with
    /// the map in the header, the lock and spot rows still separate.
    func testWorkedNumbersIPhone16Pro() {
        let small = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .small, hasSpot: true, locked: true)
        XCTAssertEqual(small.grid, .compact)
        XCTAssertEqual(small.map, .button)
        XCTAssertFalse(small.merged)
        XCTAssertEqual(small.dial, 0.40 * 874, accuracy: 0.5)

        let medium = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        XCTAssertEqual(medium.layout, .medium)
        XCTAssertEqual(medium.grid, .compact)
        XCTAssertEqual(medium.map, .button)
        XCTAssertFalse(medium.merged)
        XCTAssertTrue(medium.yielded)
        XCTAssertEqual(medium.dial, 370, accuracy: 1)

        let large = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        XCTAssertEqual(large.grid, .compact)
        XCTAssertEqual(large.map, .button)
        XCTAssertEqual(large.tileHeight, LayoutPlan.tile, accuracy: 0.5)
        XCTAssertEqual(large.dial, 386, accuracy: 1)
        XCTAssertGreaterThanOrEqual(large.dial - medium.dial, LayoutPlan.layoutStep - 0.5)

        let xl = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .extraLarge, hasSpot: true, locked: true)
        XCTAssertEqual(xl.grid, .compact)
        XCTAssertEqual(xl.map, .button)
        XCTAssertEqual(xl.dial, 386, accuracy: 1)
        XCTAssertEqual(xl.readoutScale, 1.25, accuracy: 0.001)
        XCTAssertEqual(xl.headingSize, 70, accuracy: 0.01)
        XCTAssertLessThanOrEqual(xl.bottomSpare, LayoutPlan.maxSpare)

        // Nothing locked or marked: each layout keeps its own grid. Small 350 with a 174 card, Medium at its
        // cap (370) with 88 tiles and the Map tile, Large 386 on 2 × 2, Extra Large 386 on one row.
        let liveSmall = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .small)
        XCTAssertEqual(liveSmall.map, .card)
        XCTAssertEqual(liveSmall.mapHeight, 174, accuracy: 1)
        let live = LayoutPlan.plan(w: 402, h: 874, s: 778)
        XCTAssertEqual(live.grid, .full)
        XCTAssertEqual(live.map, .tile)
        XCTAssertEqual(live.dial, 370, accuracy: 1)
        XCTAssertEqual(live.tileHeight, LayoutPlan.tileGrown, accuracy: 0.5)
        let liveLarge = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large)
        XCTAssertEqual(liveLarge.grid, .twoByTwo)
        XCTAssertEqual(liveLarge.dial, 386, accuracy: 1)
    }

    /// The owner's hard rule: "the compass takes up at least 40% of the screen". In one column, portrait
    /// (phones, iPad portrait, Mac windows taller than wide), at Text Size 1.0 and 1.3 (not the accessibility
    /// sizes), every layout's dial is at least min(0.40 H, its width cap), in the scrolling list too. Small
    /// may sit at that floor, Medium at or over it, Large over Medium, Extra Large the largest. A dial under
    /// 0.40 H fails.
    func testOwnersRuleDialAtLeast40PercentOfH() {
        let windows = phones + [("iPhone 16e", 390, 844, 763, false), ("Mac 420x1000", 420, 1000, 1000, true),
                                ("iPad mini portrait", 744, 1133, 1089, false)]
        for d in windows {
            for state in states {
                for k in [CGFloat(1), 1.15, 1.3] {
                    for noCompass in [false, true] where !(noCompass && state.locked) {
                        let plans = Layout.allCases.map {
                            LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: $0, k: k, hasSpot: state.spot,
                                            locked: state.locked, noCompass: noCompass, mac: d.mac)
                        }
                        let name = "\(d.name) \(state.name) k\(k)\(noCompass ? " no compass" : "")"
                        for p in plans {
                            let floor = min(0.40 * d.h, p.columnWidth + 2 * p.margin - 2 * p.layout.e)
                            XCTAssertFalse(p.twoPane, name)
                            XCTAssertGreaterThanOrEqual(p.dial, floor - 0.5,
                                                        "\(name) \(p.layout.rawValue): dial \(Int(p.dial)) is \(Int(100 * p.dial / d.h))% of H")
                            XCTAssertEqual(p.ownerFloor(h: d.h), floor, accuracy: 0.01, name)
                        }
                        let (small, medium, large, xl) = (plans[0], plans[1], plans[2], plans[3])
                        if !small.list { XCTAssertEqual(small.dial, min(0.40 * d.h, small.dialCap), accuracy: 0.5, "\(name): Small at the floor") }
                        if !small.list && !medium.list { XCTAssertGreaterThanOrEqual(medium.dial, small.dial - 0.5, name) }
                        if !medium.list && !large.list {
                            // (Extra Large held at the floor, on its row or as the list, holds Large there too.)
                            let xlHeld = xl.dial <= xl.floor + 0.5
                            if !xlHeld { XCTAssertGreaterThan(large.dial, medium.dial + 0.5, "\(name): Large over Medium") }
                        }
                        if !large.list && !xl.list { XCTAssertGreaterThanOrEqual(xl.dial, large.dial - 0.5, "\(name): Extra Large the largest") }
                    }
                }
            }
        }
        // The cases that broke it before: iPhone 16 Medium with the sample was 309 of 852 (36%), iPhone SE
        // Medium 200 (30%).
        let iphone16 = LayoutPlan.plan(w: 393, h: 852, s: 759, hasSpot: true, locked: true)
        XCTAssertGreaterThanOrEqual(iphone16.dial, 0.40 * 852 - 0.5)
        let se = LayoutPlan.plan(w: 375, h: 667, s: 647, hasSpot: true, locked: true)
        XCTAssertGreaterThanOrEqual(se.dial, 0.40 * 667 - 0.5)
        // The accessibility sizes are exempt (the list's own min(W − 48, 0.36 H)).
        let ax = LayoutPlan.plan(w: 393, h: 852, s: 759, k: 1.3, accessibilityText: true, hasSpot: true, locked: true)
        XCTAssertLessThanOrEqual(ax.dial, 0.36 * 852 + 0.5)
    }

    /// The owner's order of giving way when the height runs short: tile growth, the spare gaps, Small's map
    /// card (to a map tile, then the header button), Medium's and Large's grids (to the compact row), the lock
    /// and spot rows (one 44 row), and only then the scrolling list, whose dial keeps 0.40 H too. (The same
    /// order as Android's LayoutPlan.Rung.)
    func testGivingWayOrder() {
        // iPhone 16 Pro live: Medium at its cap with taller tiles; with the sample the tiles go back to 72
        // and the 3 columns give way to the compact row before the rows merge.
        let live = LayoutPlan.plan(w: 402, h: 874, s: 778)
        XCTAssertGreaterThan(live.tileHeight, LayoutPlan.tile)
        let sample = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        XCTAssertEqual(sample.tileHeight, LayoutPlan.tile, accuracy: 0.5)
        XCTAssertEqual(sample.grid, .compact)
        XCTAssertFalse(sample.merged)
        // Small: the card where 140 fits at 0.40 H, else a map tile (a strip a tile high or more), else the
        // header button.
        let smallLive = LayoutPlan.plan(w: 393, h: 852, s: 759, layout: .small)
        XCTAssertEqual(smallLive.map, .card)
        XCTAssertFalse(smallLive.mapStrip)
        let smallStrip = LayoutPlan.plan(w: 440, h: 956, s: 862, layout: .small, hasSpot: true, locked: true)
        XCTAssertTrue(smallStrip.mapStrip)
        XCTAssertFalse(smallStrip.merged)
        XCTAssertGreaterThanOrEqual(smallStrip.mapHeight, LayoutPlan.tile - 0.5)
        XCTAssertLessThan(smallStrip.mapHeight, LayoutPlan.mapMin)
        XCTAssertEqual(smallStrip.dial, 0.40 * 956, accuracy: 0.5)
        XCTAssertEqual(LayoutPlan.plan(w: 393, h: 852, s: 759, layout: .small, hasSpot: true, locked: true).map, .button)
        // Large gives up its 2 × 2 rather than sit within 16 of the floor (Mac 420 × 780, sample): Medium keeps
        // its 3 columns at the floor, Large takes the compact row 16 or more over it, Extra Large merges its
        // rows to stay the largest.
        let macMedium = LayoutPlan.plan(w: 420, h: 780, s: 780, hasSpot: true, locked: true, mac: true)
        let macLarge = LayoutPlan.plan(w: 420, h: 780, s: 780, layout: .large, hasSpot: true, locked: true, mac: true)
        let macXL = LayoutPlan.plan(w: 420, h: 780, s: 780, layout: .extraLarge, hasSpot: true, locked: true, mac: true)
        XCTAssertEqual(macMedium.grid, .full)
        XCTAssertEqual(macLarge.grid, .compact)
        XCTAssertFalse(macLarge.merged)
        XCTAssertGreaterThanOrEqual(macLarge.dial, macMedium.dial + LayoutPlan.layoutStep - 0.5)
        XCTAssertGreaterThanOrEqual(macXL.dial, macLarge.dial - 0.5)
        // A 360 × 640 phone with the sample: the compact row is not enough, so the rows merge (one 44 row).
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 360, h: 640, s: 568, layout: layout, hasSpot: true, locked: true)
            XCTAssertFalse(p.list, layout.rawValue)
            XCTAssertTrue(p.merged, layout.rawValue)
            XCTAssertEqual(p.grid, .compact, layout.rawValue)
            XCTAssertGreaterThanOrEqual(p.dial, 0.40 * 640 - 0.5, layout.rawValue)
            XCTAssertEqual(p.used, 568, accuracy: 0.5, layout.rawValue)
        }
        // iPhone SE at Text Size 1.3 with the sample: nothing fits, so the list, with the dial at 0.40 H.
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 375, h: 667, s: 647, layout: layout, k: 1.3, hasSpot: true, locked: true)
            XCTAssertTrue(p.list, layout.rawValue)
            XCTAssertGreaterThanOrEqual(p.dial, 0.40 * 667 - 0.5, layout.rawValue)
        }
    }

    /// C2.2 #1: the compact row's widths come from C, and every row's widths plus gutters equal C.
    func testRowWidthsAddUpToC() {
        let w370 = LayoutPlan.compactWidths(370)
        XCTAssertEqual(w370.position, 146)
        XCTAssertEqual(w370.other, 104)
        let w380 = LayoutPlan.compactWidths(380)
        XCTAssertEqual(w380.position, 156)
        XCTAssertEqual(w380.other, 104)
        let w700 = LayoutPlan.compactWidths(700)
        XCTAssertEqual(w700.position, 306)
        XCTAssertEqual(w700.other, 189)
        for d in LayoutPlan.devices {
            for layout in Layout.allCases {
                for (locked, spot) in [(false, false), (true, true)] {
                    let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, hasSpot: spot, locked: locked, mac: d.mac)
                    for row in p.rowWidths {
                        let sum = row.reduce(0, +) + CGFloat(row.count - 1) * LayoutPlan.rowGap
                        XCTAssertEqual(sum, p.columnWidth, accuracy: 0.5, "\(d.name) \(layout.rawValue)")
                    }
                }
            }
        }
    }

    /// C3.2 #2: one step per layout: neighbours differ in grid mode; Medium and Large also in map surface,
    /// with Large's dial 16 or more over Medium's; in landscape the four plans are four. The one exception
    /// is the owner's rule: a layout that gave up its grid or map card to keep 0.40 H (`yielded`) may match
    /// its neighbour, but the dials still rise (Large over Medium, Extra Large the largest).
    func testLayoutsAreDistinct() {
        for d in LayoutPlan.devices {
            for state in [(false, false), (true, true)] {
                let plans = Layout.allCases.map {
                    LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: $0, hasSpot: state.1, locked: state.0, mac: d.mac)
                }
                if plans.allSatisfy(\.twoPane) {
                    let keys = Set(plans.map { "\($0.grid) \($0.map) \(Int($0.dial / 16))" })
                    XCTAssertEqual(keys.count, 4, "\(d.name): landscape plans")
                    continue
                }
                for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
                    // A layout that gave way to keep the owner's 0.40 H may match its neighbour, as in
                    // LayoutPlan.distinct.
                    let yielded = a.yielded || b.yielded
                    if !yielded {
                        XCTAssertNotEqual(a.grid, b.grid, "\(d.name): \(a.layout.rawValue) and \(b.layout.rawValue)")
                    }
                    XCTAssertGreaterThanOrEqual(b.dial, a.dial - 0.5, "\(d.name): \(b.layout.rawValue) under \(a.layout.rawValue)")
                    if a.layout == .medium {
                        if !yielded { XCTAssertNotEqual(a.map, b.map, d.name) }
                        if a.dial > a.floor + 0.5 {
                            XCTAssertGreaterThanOrEqual(b.dial - a.dial, LayoutPlan.layoutStep - 0.5, d.name)
                        }
                    }
                }
            }
        }
        // The grids as drawn: Medium 3 columns with the Map tile, Large 2 × 2, Extra Large one row.
        let medium = LayoutPlan.plan(w: 402, h: 874, s: 778)
        let large = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large)
        let xl = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .extraLarge)
        XCTAssertEqual(medium.cells.map(\.count), [2, 3])
        XCTAssertEqual(medium.cells.last?.last?.tile, LayoutPlan.Tile.map)
        XCTAssertEqual(large.cells.map(\.count), [2, 2])
        XCTAssertFalse(large.cells.joined().contains { $0.tile == .map })
        XCTAssertEqual(xl.cells.map(\.count), [3])
    }

    /// C3.4 #17: a Mac window keeps 24 on every edge, and the smallest window holds every layout with the
    /// sample without scrolling.
    func testMacMargins() {
        let windows: [(CGFloat, CGFloat)] = [(420, 840), (1200, 800)]
        for (w, h) in windows {
            let p = LayoutPlan.plan(w: w, h: h, s: h, mac: true)
            XCTAssertEqual(p.margin, 24)
            XCTAssertEqual(p.topInset, 24)
            XCTAssertEqual(p.bottomInset, 24)
        }
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: LayoutPlan.macMinWidth, h: LayoutPlan.macMinHeight, s: LayoutPlan.macMinHeight,
                                    layout: layout, hasSpot: true, locked: true, mac: true)
            XCTAssertFalse(p.list, layout.rawValue)
        }
    }

    /// C3.4 #10: iPad portrait has its own ramp (96 tiles, 96 readout, a 56 header) and an equal margin in
    /// every layout but Extra Large's widened column; Medium promotes the map to a card of 200 or more
    /// where 160 or more is spare.
    func testIPad() {
        let ipad = LayoutPlan.plan(w: 834, h: 1210, s: 1166)
        XCTAssertTrue(ipad.tablet)
        XCTAssertEqual(ipad.headingSize, 96)
        XCTAssertEqual(ipad.headerHeight, 56)
        XCTAssertEqual(ipad.tileHeight, 96)
        XCTAssertEqual(ipad.map, .card)
        XCTAssertGreaterThanOrEqual(ipad.mapHeight, LayoutPlan.mapPromoted - 0.5)
        for layout: Layout in [.small, .medium, .large] {
            XCTAssertEqual(LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout).columnWidth, 720, layout.rawValue)
        }
        XCTAssertEqual(LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: .extraLarge).map, .button)
        // No compass: the same grid as the layout's normal state (C3.4 #11).
        for layout in Layout.allCases {
            let normal = LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout, hasSpot: true)
            let none = LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout, hasSpot: true, noCompass: true)
            XCTAssertEqual(normal.grid, none.grid, layout.rawValue)
        }
    }

    /// C3.2 #3 and C3.4 #12: what is drawn. The no-heading dash sits on the digits' midline (it drew as
    /// "_ °"), and both Position lines are drawn at one size.
    @MainActor
    func testDrawnReadoutAndPosition() {
        XCTAssertEqual(MainView.dashFailures(), [])
        XCTAssertEqual(MainView.positionSizeFailures(), [])
    }

    /// C3.2 #1–#2, as drawn: the header never jumps, grids are what each layout plans (and differ), and the
    /// bottom is what the plan left, in every layout and in the sample, no-compass and live states.
    @MainActor
    func testDrawnScreenMatchesPlan() {
        let nav = Navigator(defaults: UserDefaults(suiteName: "bearings.tests.drawing") ?? .standard)
        let drawn = MainView.drawingFailures(nav: nav, width: 420, height: 840)
        XCTAssertEqual(drawn.failures, [])
    }

    /// C2.3 #19: one time formatter; the day period splits off for the narrow Sun tile.
    func testTimeSplit() {
        // The sample's time, 1 November 2026 (Navigator.sampleTime).
        let date = Date(timeIntervalSince1970: 1793551260)
        let t = Look.time(date)
        XCTAssertFalse(t.clock.isEmpty)
        XCTAssertFalse(Look.timeText(date).contains("…"))
        if let period = t.period {
            XCTAssertFalse(period.contains(where: { $0.isNumber }))
            XCTAssertEqual(Look.timeText(date), "\(t.clock)\u{202F}\(period)")
        }
    }

    /// C2's tests: no "…" in any tile value, the lock row or the header (the strings, and what the tiles and
    /// the header must hold, measured on every device at Text Size 1.0 and 1.3); the lock row's values never
    /// split (C3.4 #7).
    @MainActor
    func testNoEllipsisAnywhere() throws {
        // The sample: Maroon Bells, 1 November 2026 (Navigator.sampleTime).
        let lat = 39.09898, lon = -106.94117, now = Date(timeIntervalSince1970: 1793551260)
        let times = Sky.sunTimes(at: now, lat: lat, lon: lon)
        let rise = try XCTUnwrap(times.sunriseDate), set = try XCTUnwrap(times.sunsetDate)
        XCTAssertEqual(MainView.fitFailures(sunrise: rise, sunset: set, now: now, lat: lat, lon: lon), [])
        XCTAssertFalse(MainView.noCompassText.contains("…"))
        let lock = MainView.lockParts("Locked 240° · turn 12° right")
        XCTAssertEqual(lock.label, "Locked\u{00A0}240°")
        XCTAssertFalse(lock.cue.contains(" "))
    }

    /// C3.2 #2: the menus say what each layout changes.
    func testMenuSubtitles() {
        XCTAssertEqual(Layout.allCases.map(\.subtitle), [
            "Compass + big map", "Balanced · map tile", "Bigger compass · map in header", "Biggest compass · one row",
        ])
    }

    /// REFINE.md §4.3 and §4.7: night mode's secondary text is 4.5:1 or better on black.
    func testNightSecondaryContrast() {
        XCTAssertGreaterThanOrEqual(Palette.nightSecondaryContrast(), 4.5)
    }

    func testLayoutIds() {
        // CI passes these ids (--layout on Apple, the "layout" extra on Android); they are the stored values.
        XCTAssertEqual(Layout.allCases.map(\.rawValue), ["small", "medium", "large", "extraLarge"])
        XCTAssertEqual(Layout.allCases.map(\.name), ["Small", "Medium", "Large", "Extra Large"])
        XCTAssertEqual(Layout.default, .medium)
        XCTAssertEqual(Layout.of(nil), .medium)
        XCTAssertEqual(Layout.of("bogus"), .medium)
        XCTAssertEqual(Layout.of("extraLarge"), .extraLarge)
        XCTAssertNil(Layout.small.smaller)
        XCTAssertNil(Layout.extraLarge.larger)
    }

    /// C3.4 #6: accessibility sizes scroll as one list with a smaller dial, min(W − 48, 0.36 H), and the
    /// Position and Elevation rows above the fold.
    func testAccessibilityTextScrollsAsOneList() {
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 393, h: 852, s: 759, layout: layout, k: 1.3, accessibilityText: true,
                                    hasSpot: true, locked: true)
            XCTAssertTrue(p.list, layout.rawValue)
            XCTAssertEqual(p.grid, .list, layout.rawValue)
            XCTAssertEqual(p.map, .card, layout.rawValue)
            XCTAssertEqual(p.mapHeight, LayoutPlan.listMap, accuracy: 0.5, layout.rawValue)
            XCTAssertLessThanOrEqual(p.dial, min(393 - 48, 0.36 * 852) + 0.5, layout.rawValue)
            XCTAssertLessThanOrEqual(p.listFold2, 759, layout.rawValue)
        }
    }

    /// C3.4 #5: two panes, with fixed rows and four different plans.
    func testTwoPanes() {
        let windows: [(w: CGFloat, h: CGFloat, s: CGFloat)] = [(1210, 834, 790), (1376, 1032, 988)]
        for (w, h, s) in windows {
            var dials: [CGFloat] = []
            for layout in Layout.allCases {
                let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout)
                let name = "\(Int(w))x\(Int(h)) \(layout.rawValue)"
                XCTAssertTrue(p.twoPane, name)
                XCTAssertGreaterThanOrEqual(p.trailingWidth, LayoutPlan.paneMin - 0.5, name)
                XCTAssertLessThanOrEqual(p.trailingWidth, LayoutPlan.paneMax + 0.5, name)
                XCTAssertEqual(p.tileHeight, LayoutPlan.tileTablet, accuracy: 0.5, "\(name): fixed rows")
                if layout == .large || layout == .extraLarge {
                    XCTAssertEqual(p.map, .button, name)
                } else {
                    XCTAssertEqual(p.map, .card, name)
                    XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapPaneTablet - 0.5, name)
                }
                dials.append(p.dial)
            }
            // Each layout's dial is larger than the one before.
            XCTAssertEqual(dials, dials.sorted(), "\(Int(w))x\(Int(h))")
        }
        // A phone on its side is two panes too.
        XCTAssertTrue(LayoutPlan.plan(w: 852, h: 393, s: 372, isLandscapePhone: true).twoPane)
    }
}
