import CoreGraphics
import XCTest
@testable import Bearings

/// The Concept A planner (docs/REFINE.md "Concept A (chosen)", Option 1 with the owner's mod; docs/LAYOUTS.md):
/// the slim 40 pt location bar first, 8 under the safe top, then the dial 12 under it, the readout, the status
/// line, the Targets card and the layout's tiles or map; every gap a frozen token; spare spent in a fixed order; nothing cut; every row's
/// widths adding up to C; the four layouts different from each other; and the owner's hard rule: in
/// portrait, one column, no dial under 0.40 H. The same golden table runs in the Mac and iPhone self-tests
/// (which also check the drawing against the plan) and, ported, on Android.
final class LayoutPlanTests: XCTestCase {
    /// A window the tests plan for: width, full height, safe height (pt; dp on the Pixel), and whether it is a
    /// Mac window. (A struct, so a list of them never infers as [Any].)
    private struct TestWindow {
        let name: String
        let w: CGFloat
        let h: CGFloat
        let s: CGFloat
        let mac: Bool
    }

    private let phones: [TestWindow] = [
        TestWindow(name: "iPhone SE", w: 375, h: 667, s: 647, mac: false),
        TestWindow(name: "iPhone 16", w: 393, h: 852, s: 759, mac: false),
        TestWindow(name: "iPhone 16 Pro", w: 402, h: 874, s: 778, mac: false),
        TestWindow(name: "iPhone 17 Pro Max", w: 440, h: 956, s: 862, mac: false),
        TestWindow(name: "Pixel 7", w: 412, h: 915, s: 839, mac: false),
        TestWindow(name: "Mac 420x840", w: 420, h: 840, s: 840, mac: true),
        TestWindow(name: "Mac 420x780", w: 420, h: 780, s: 780, mac: true),
        TestWindow(name: "iPad 11 portrait", w: 834, h: 1210, s: 1166, mac: false),
        TestWindow(name: "iPad 13 portrait", w: 1032, h: 1376, s: 1332, mac: false),
    ]
    /// iPhone 16 and iPhone 16 Pro: width, full height, safe height.
    private let goldenPhones: [(CGFloat, CGFloat, CGFloat)] = [(393, 852, 759), (402, 874, 778)]
    private let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    func testGoldenTable() {
        XCTAssertEqual(LayoutPlan.tableFailures(), [])
    }

    /// A.1 with the owner's mod: the location bar's top is the safe top + 8 (a Mac window 28 + 8), 40 × k
    /// high, the dial 12 under it (8 after giving way), and every gap is its token: dial → readout 12,
    /// readout → status 6 × k, status → Targets card 12 (8), 8 between the cards and the grid. The stack fills to its end, with 24 or less left at the bottom unless centred.
    func testFrozenRhythm() {
        for d in phones {
            for layout in Layout.allCases {
                for state in states {
                    for k in [CGFloat(1), 1.3] {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k,
                                                hasSpot: state.spot, locked: state.locked, mac: d.mac)
                        let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)"
                        let tight = p.steps.contains(.tight)
                        XCTAssertEqual(p.topBand, d.mac ? 28 : 0, name)
                        XCTAssertEqual(p.gapTopCard, 8, name)
                        XCTAssertEqual(p.gapCardDial, tight ? 8 : 12, name)
                        XCTAssertEqual(p.cardHeight, 40 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapDialReadout, 12, name)
                        XCTAssertEqual(p.gapReadoutStatus, 6 * p.k, accuracy: 0.01, name)
                        XCTAssertEqual(p.gapStatusTargets, tight ? 8 : 12, name)
                        XCTAssertEqual(p.gap, 8, name)
                        if p.list {
                            XCTAssertEqual(p.grid, .list, name)
                            XCTAssertGreaterThanOrEqual(p.dial, p.ownerFloor(h: d.h) - 0.5, "\(name): list dial under 0.40 H")
                            continue
                        }
                        XCTAssertFalse(p.twoPane, name)
                        if !p.centred {
                            XCTAssertLessThanOrEqual(p.bottomSpare, LayoutPlan.maxSpare + 0.5, "\(name): empty at the bottom")
                            XCTAssertEqual(p.topExtra, 0, name)
                        } else {
                            // Centred: what the dial and the growth couldn't take, split above and below.
                            XCTAssertGreaterThan(p.topExtra, 0, name)
                            XCTAssertGreaterThanOrEqual(p.bottomSpare, p.topExtra - 0.5, name)
                        }
                        XCTAssertEqual(p.used, p.end, accuracy: 0.5, "\(name): the stack doesn't end at its end")
                        XCTAssertEqual(p.end, d.s - p.bottomInset, accuracy: 0.01, name)
                        XCTAssertGreaterThanOrEqual(p.dial, p.ownerFloor(h: d.h) - 0.5, "\(name): dial under 0.40 H")
                        // Large and Extra Large put the map in the location card on every device.
                        if p.layout == .large || p.layout == .extraLarge { XCTAssertEqual(p.map, .button, name) }
                        if p.map == .card { XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapMin - 0.5, "\(name): map card") }
                        XCTAssertEqual(p.mapInHeader, p.map == .button, name)
                    }
                }
            }
        }
        // A Mac window: the bar at 28 + 8, the dial at 36 + 40 + 12 = 88; 24 at the sides and the bottom.
        let mac = LayoutPlan.plan(w: 420, h: 840, s: 840, hasSpot: true, locked: true, mac: true)
        XCTAssertEqual(mac.locationTop, 36, accuracy: 0.01)
        XCTAssertEqual(mac.dialTop, 88, accuracy: 0.01)
        XCTAssertEqual(mac.margin, 24)
        XCTAssertEqual(mac.bottomInset, 24)
        // iPhone 16 Pro: the bar at 62 + 8 = 70 on screen (70–110), the dial at 122; the stack ends at
        // 874 − 34 = 840.
        let pro = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        XCTAssertEqual(pro.locationTop + 62, 70, accuracy: 0.01)
        XCTAssertEqual(pro.cardHeight, 40, accuracy: 0.01)
        XCTAssertEqual(pro.dialTop + 62, 122, accuracy: 0.01)
        XCTAssertEqual(pro.end + 62, 840, accuracy: 0.01)
    }

    /// A.3: the four layouts on iPhone 16 Pro (402 × 874, S = 778, C = 370) with the sample (locked and
    /// marked; still, so Large shows Pressure).
    func testWorkedNumbersIPhone16Pro() {
        func plan(_ layout: Layout, sample: Bool = true) -> LayoutPlan {
            LayoutPlan.plan(w: 402, h: 874, s: 778, layout: layout, hasSpot: sample, locked: sample)
        }
        let small = plan(.small)
        XCTAssertEqual(small.grid, .band)
        XCTAssertEqual(small.map, .card)
        XCTAssertEqual(small.dial, 352, accuracy: 0.5)
        XCTAssertEqual(small.mapHeight, 180, accuracy: 2)
        XCTAssertEqual(small.targetsRowHeight, 44, accuracy: 0.5)

        let medium = plan(.medium)
        XCTAssertEqual(medium.layout, .medium)
        XCTAssertEqual(medium.grid, .quad)
        XCTAssertEqual(medium.map, .tile)
        XCTAssertEqual(medium.dial, 352, accuracy: 0.5)
        XCTAssertEqual(medium.locationTop + 62, 70, accuracy: 0.5)
        XCTAssertEqual(medium.dialTop + 62, 122, accuracy: 0.5)
        XCTAssertEqual(medium.targetsTop + 62, 564.3, accuracy: 1)
        XCTAssertEqual(medium.targetsRows, 2)
        XCTAssertEqual(medium.targetsRowHeight, 44, accuracy: 0.5)
        XCTAssertEqual(medium.tileHeight, 85.8, accuracy: 1)
        XCTAssertEqual(medium.used + 62, 840, accuracy: 0.5)
        XCTAssertEqual(medium.cells.map(\.count), [2, 2])
        XCTAssertEqual(medium.cells.last?.last?.tile, LayoutPlan.Tile.map)

        let large = plan(.large)
        XCTAssertEqual(large.grid, .six)
        XCTAssertEqual(large.map, .button)
        XCTAssertEqual(large.dial, 368, accuracy: 0.5)
        XCTAssertEqual(large.tileHeight, 77.8, accuracy: 1)
        XCTAssertEqual(large.sixth, .pressure)
        XCTAssertEqual(large.cells.map { $0.map(\.tile) }, [[.latitude, .longitude, .elevation], [.sunrise, .moon, .sixth]])

        let xl = plan(.extraLarge)
        XCTAssertEqual(xl.grid, .strip)
        XCTAssertEqual(xl.map, .button)
        XCTAssertEqual(xl.dial, 386, accuracy: 0.5)
        XCTAssertEqual(xl.readoutScale, 1.25, accuracy: 0.001)
        XCTAssertEqual(xl.headingSize, 70, accuracy: 0.01)
        XCTAssertEqual(xl.targetsRowHeight, 52, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(xl.tileHeight, LayoutPlan.strip - 0.5)
        XCTAssertLessThanOrEqual(xl.tileHeight, LayoutPlan.stripGrown + 0.5)

        // Live (no lock, no spot): no Targets card; its room goes to each layout's growth.
        let liveSmall = plan(.small, sample: false)
        XCTAssertGreaterThan(liveSmall.mapHeight, small.mapHeight + 90)
        let live = plan(.medium, sample: false)
        XCTAssertEqual(live.rowHeights[0], LayoutPlan.tileGrown, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(live.rowHeights[1], LayoutPlan.tallSun)
        XCTAssertEqual(live.dial, 352, accuracy: 0.5)
        let liveLarge = plan(.large, sample: false)
        XCTAssertEqual(liveLarge.tileHeight, LayoutPlan.tileLarge, accuracy: 0.5)
        XCTAssertEqual(liveLarge.dial, 386, accuracy: 0.5)
        let liveXL = plan(.extraLarge, sample: false)
        XCTAssertEqual(liveXL.tileHeight, LayoutPlan.stripGrown, accuracy: 0.5)
    }

    /// The owner's hard rule: "the compass takes up at least 40% of the screen". In one column, portrait
    /// (phones, iPad portrait, Mac windows taller than wide), at every text size, every layout's dial is at
    /// least min(0.40 H, its width cap), in the scrolling list too; and the dials rise from Small to Extra
    /// Large. A dial under 0.40 H fails.
    func testOwnersRuleDialAtLeast40PercentOfH() {
        let more: [TestWindow] = [
            TestWindow(name: "iPhone 16e", w: 390, h: 844, s: 763, mac: false),
            TestWindow(name: "Mac 420x1000", w: 420, h: 1000, s: 1000, mac: true),
            TestWindow(name: "iPad mini portrait", w: 744, h: 1133, s: 1089, mac: false),
        ]
        let windows: [TestWindow] = phones + more
        let textSizes: [(CGFloat, Bool)] = [(1, false), (1.15, false), (1.3, false), (1.3, true)]
        for d in windows {
            for state in states {
                for (k, acc) in textSizes {
                    for noCompass in [false, true] where !(noCompass && state.locked) {
                        let plans = Layout.allCases.map {
                            LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: $0, k: k, accessibilityText: acc,
                                            hasSpot: state.spot, locked: state.locked, noCompass: noCompass, mac: d.mac)
                        }
                        let name = "\(d.name) \(state.name) k\(k)\(acc ? " acc" : "")\(noCompass ? " no compass" : "")"
                        for p in plans {
                            let widthCap: CGFloat = p.columnWidth + 2 * p.margin - 2 * p.layout.e
                            let floor: CGFloat = min(LayoutPlan.ownerShare * d.h, widthCap)
                            XCTAssertFalse(p.twoPane, name)
                            XCTAssertGreaterThanOrEqual(p.dial, floor - 0.5,
                                                        "\(name) \(p.layout.rawValue): dial \(Int(p.dial)) is \(Int(100 * p.dial / d.h))% of H")
                            XCTAssertEqual(p.ownerFloor(h: d.h), floor, accuracy: 0.01, name)
                        }
                        for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list {
                            XCTAssertGreaterThanOrEqual(b.dial, a.dial - 0.5, "\(name): \(b.layout.rawValue) under \(a.layout.rawValue)")
                        }
                    }
                }
            }
        }
    }

    /// A.6: the order of giving way before the dial goes under 0.40 H: tile growth, the spare gaps, the
    /// Targets rows to compact height, Large's grid density, Small's map card, the header map button, and
    /// only then the scrolling list (whose dial keeps 0.40 H too). What fits comes back afterwards.
    func testGivingWayOrder() {
        // iPhone SE (375 × 667) Medium with the sample takes steps 2, 3 and 6 to keep a 272 dial; the rows
        // and gaps then come back and the compact row grows to 88: "dial 272 · compact · map button".
        let se = LayoutPlan.plan(w: 375, h: 667, s: 647, hasSpot: true, locked: true)
        XCTAssertEqual(se.dial, 272, accuracy: 0.5)
        XCTAssertEqual(se.grid, .row)
        XCTAssertEqual(se.map, .button)
        XCTAssertEqual(se.steps, [.button])
        XCTAssertEqual(se.gapCardDial, 12)
        XCTAssertEqual(se.gapStatusTargets, 12)
        XCTAssertEqual(se.targetsRowHeight, 44, accuracy: 0.5)
        XCTAssertEqual(se.tileHeight, LayoutPlan.tileGrown, accuracy: 0.5)
        XCTAssertEqual(se.cells.map(\.count), [3])
        // iPhone 16 Pro: the sample gives nothing up; tile growth is all that went.
        let pro = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        XCTAssertTrue(pro.steps.isEmpty)
        XCTAssertLessThan(pro.tileHeight, LayoutPlan.tileGrown)
        // Large gives up its density (quadCompact) before its map; Small its card before the button.
        let seLarge = LayoutPlan.plan(w: 375, h: 667, s: 647, layout: .large, hasSpot: true, locked: true)
        XCTAssertTrue(seLarge.grid == .quadCompact || seLarge.grid == .row, "\(seLarge.grid)")
        XCTAssertGreaterThanOrEqual(seLarge.dial, se.dial - 0.5)
        let seSmall = LayoutPlan.plan(w: 375, h: 667, s: 647, layout: .small, hasSpot: true, locked: true)
        XCTAssertFalse(seSmall.list)
        XCTAssertNotEqual(seSmall.map, .button)
        // Every step comes in the owner's order.
        XCTAssertEqual(LayoutPlan.Step.allCases, [.tight, .compactRows, .dense, .mapTile, .button])
        // Nothing fits at all: the list, its dial still at 0.40 H.
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 375, h: 667, s: 647, layout: layout, k: 1.3, hasSpot: true, locked: true)
            XCTAssertGreaterThanOrEqual(p.dial, 0.40 * 667 - 0.5, layout.rawValue)
        }
    }

    /// Every row's widths plus gutters equal C: the compact row from C, the quad, the six (3u + 16), the
    /// band (three columns + 24 padding + 2 × 8), the strip (three columns + 2 dividers) and the two rows.
    func testRowWidthsAddUpToC() {
        let w370 = LayoutPlan.compactWidths(370)
        XCTAssertEqual(w370.position, 146)
        XCTAssertEqual(w370.other, 104)
        let w700 = LayoutPlan.compactWidths(700)
        XCTAssertEqual(w700.position, 306)
        XCTAssertEqual(w700.other, 189)
        for c in [CGFloat(343), 370, 388, 720] {
            XCTAssertEqual(LayoutPlan.bandWidths(c).reduce(0, +) + 24 + 16, c, accuracy: 0.01)
            XCTAssertEqual(LayoutPlan.stripWidths(c).reduce(0, +) + 2, c, accuracy: 0.01)
        }
        for d in LayoutPlan.devices {
            for layout in Layout.allCases {
                for k in [CGFloat(1), 1.3] {
                    for (locked, spot) in [(false, false), (true, true)] {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, hasSpot: spot, locked: locked, mac: d.mac)
                        for row in p.rowWidths {
                            let sum = row.reduce(0, +) + CGFloat(row.count - 1) * LayoutPlan.rowGap
                            XCTAssertEqual(sum, p.columnWidth, accuracy: 0.5, "\(d.name) \(layout.rawValue) k\(k)")
                        }
                    }
                }
            }
        }
        // Large's six at C = 370: 118-wide tiles.
        let large = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        XCTAssertEqual(large.rowWidths[0][0], (370 - 16) / 3, accuracy: 0.01)
        // Other formats: one Position tile across two columns (2u + 8).
        let dms = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true, splitPosition: false)
        XCTAssertEqual(dms.cells[0].map(\.tile), [.position, .elevation])
        XCTAssertEqual(dms.rowWidths[0][0], 2 * (370 - 16) / 3 + 8, accuracy: 0.01)
    }

    /// A.4: the four layouts are four. In the sample on the golden phones each has its own grid (band, quad,
    /// six, strip) and map surface (card, tile, button, button); everywhere the dials rise and neighbours are
    /// never the same plan; in landscape the four grids are four.
    func testLayoutsAreDistinct() {
        for (w, h, s) in goldenPhones {
            let plans = Layout.allCases.map { LayoutPlan.plan(w: w, h: h, s: s, layout: $0, hasSpot: true, locked: true) }
            XCTAssertEqual(plans.map(\.grid), [.band, .quad, .six, .strip], "\(Int(w))")
            XCTAssertEqual(plans.map(\.map), [.card, .tile, .button, .button], "\(Int(w))")
            XCTAssertEqual(plans.map(\.dial), plans.map(\.dial).sorted(), "\(Int(w))")
            for p in plans { XCTAssertGreaterThanOrEqual(p.dial, 0.40 * h - 0.5) }
        }
        for d in LayoutPlan.devices {
            for state in [(false, false), (true, true)] {
                let plans = Layout.allCases.map {
                    LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: $0, hasSpot: state.1, locked: state.0, mac: d.mac)
                }
                if plans.allSatisfy(\.twoPane) {
                    XCTAssertEqual(Set(plans.map(\.grid)).count, 4, "\(d.name): landscape plans")
                    continue
                }
                for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
                    XCTAssertGreaterThanOrEqual(b.dial, a.dial - 0.5, "\(d.name): \(b.layout.rawValue) under \(a.layout.rawValue)")
                    let same = a.grid == b.grid && a.map == b.map && abs(a.dial - b.dial) < 0.5
                    XCTAssertFalse(same, "\(d.name): \(a.layout.rawValue) and \(b.layout.rawValue) are the same plan")
                }
            }
        }
    }

    /// The owner's mod: in every portrait plan the location bar comes first, at the safe top + 8 (a Mac window
    /// 28 + 8), 40 × k high and the column's width; the dial is 12 under it (8 after giving way, plus any
    /// centring spare); the Targets card (or the grid) is 12 (8) under the status line.
    func testLocationBarAtTop() {
        for d in phones {
            for layout in Layout.allCases {
                for state in states {
                    for k in [CGFloat(1), 1.3] {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k,
                                                hasSpot: state.spot, locked: state.locked, mac: d.mac)
                        let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)"
                        let tight: CGFloat = p.steps.contains(.tight) ? 8 : 12
                        XCTAssertEqual(p.locationTop, p.topBand + 8, accuracy: 0.01, name)
                        XCTAssertEqual(p.cardHeight, 40 * p.k, accuracy: 0.01, name)
                        XCTAssertGreaterThanOrEqual(p.cardHeight, 40, name)
                        XCTAssertEqual(p.dialTop, p.locationTop + p.cardHeight + tight + p.topExtra, accuracy: 0.01, name)
                        if p.list { continue }
                        XCTAssertEqual(p.cardWidth, p.columnWidth, accuracy: 0.01, name)
                        XCTAssertEqual(p.lowerTop, p.statusBottom + tight, accuracy: 0.01, name)
                        XCTAssertGreaterThan(p.targetsTop, p.statusBottom, name)
                    }
                }
            }
        }
    }

    /// A.11: the Targets card has 0, 1 or 2 rows by state, the lock row first; rows 44 (36 compact), Extra
    /// Large and iPad 52 (44 compact).
    func testTargetsCardRows() {
        for state in states {
            for layout in Layout.allCases {
                let p = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: layout, hasSpot: state.spot, locked: state.locked)
                XCTAssertEqual(p.targetsRows, (state.locked ? 1 : 0) + (state.spot ? 1 : 0), "\(state.name) \(layout.rawValue)")
                XCTAssertEqual(p.hasTargets, state.locked || state.spot)
                XCTAssertEqual(p.targetsRowHeight, layout == .extraLarge ? 52 : 44, accuracy: 0.5, layout.rawValue)
                if !p.hasTargets { XCTAssertEqual(p.gridTop, p.targetsTop, accuracy: 0.01) }
            }
        }
        XCTAssertEqual(LayoutPlan.targetsRowHeight(layout: .medium, k: 1, tablet: false, compact: true), 36)
        XCTAssertEqual(LayoutPlan.targetsRowHeight(layout: .extraLarge, k: 1, tablet: false, compact: true), 44)
        XCTAssertEqual(LayoutPlan.targetsRowHeight(layout: .medium, k: 1, tablet: true, compact: false), 52)
        // The lock row first: "Locked 240°" and "turn 12° right" never split.
        let lock = MainView.lockParts("Locked 240° · turn 12° right")
        XCTAssertEqual(lock.label, "Locked\u{00A0}240°")
        XCTAssertFalse(lock.cue.contains(" "))
    }

    /// A.3: Large's sixth tile is Speed while moving (0.5 m/s or more), otherwise Pressure.
    func testLargeSixthTile() {
        XCTAssertEqual(LayoutPlan.sixth(speed: nil), .pressure)
        XCTAssertEqual(LayoutPlan.sixth(speed: 0), .pressure)
        XCTAssertEqual(LayoutPlan.sixth(speed: 0.49), .pressure)
        XCTAssertEqual(LayoutPlan.sixth(speed: 0.5), .speed)
        XCTAssertEqual(LayoutPlan.sixth(speed: 3), .speed)
        XCTAssertEqual(LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, speed: 1.4).sixth, .speed)
        XCTAssertEqual(LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large).sixth, .pressure)
    }

    /// A.7: at k ≥ 1.3 (2.0 is capped at 1.3 on Apple) no three-column compact row, rows of a grid equal in
    /// height (Medium's live row 2 aside), times never split, the last row at or above the end.
    func testLargeTextTwoRows() {
        for d in phones {
            for k in [CGFloat(1.3), 2.0] {
                for state in states {
                    for layout in Layout.allCases {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k,
                                                hasSpot: state.spot, locked: state.locked, mac: d.mac)
                        let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)"
                        XCTAssertEqual(p.k, 1.3, accuracy: 0.001, name)
                        if p.list { continue }
                        XCTAssertNotEqual(p.grid, .row, name)
                        XCTAssertNotEqual(p.grid, .band, name)
                        XCTAssertNotEqual(p.grid, .strip, name)
                        XCTAssertNotEqual(p.grid, .six, name)
                        for row in p.cells { XCTAssertLessThanOrEqual(row.count, 2, name) }
                        if !(layout == .medium && p.grid == .quad && !p.hasTargets), let first = p.rowHeights.first {
                            for h in p.rowHeights { XCTAssertEqual(h, first, accuracy: 0.5, name) }
                        }
                        XCTAssertLessThanOrEqual(p.contentBottom, p.end + 0.5, name)
                    }
                }
            }
        }
        let date = Date(timeIntervalSince1970: 1793551260)
        XCTAssertFalse(Look.timeText(date).contains(" "), "a time may break")
    }

    /// A.11: no portrait golden (the sample on iPhone 16 and 16 Pro) has an empty band wider than 24.
    func testNoEmptyBandOnTheGoldens() {
        for (w, h, s) in goldenPhones {
            for layout in Layout.allCases {
                let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout, hasSpot: true, locked: true)
                XCTAssertFalse(p.centred, layout.rawValue)
                XCTAssertEqual(p.topExtra, 0, layout.rawValue)
                XCTAssertLessThanOrEqual(p.bottomSpare, 24, layout.rawValue)
            }
        }
    }

    /// A Mac window keeps 24 at the sides and the bottom, and the smallest window holds every layout with the
    /// sample without scrolling.
    func testMacMargins() {
        for (w, h) in [(CGFloat(420), CGFloat(840)), (1200, 800)] {
            let p = LayoutPlan.plan(w: w, h: h, s: h, mac: true)
            XCTAssertEqual(p.margin, 24)
            XCTAssertEqual(p.bottomInset, 24)
            XCTAssertEqual(p.locationTop, 36, accuracy: 0.01)
            XCTAssertEqual(p.dialTop - p.topExtra, 88, accuracy: 0.01)
        }
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: LayoutPlan.macMinWidth, h: LayoutPlan.macMinHeight, s: LayoutPlan.macMinHeight,
                                    layout: layout, hasSpot: true, locked: true, mac: true)
            XCTAssertFalse(p.list, layout.rawValue)
        }
    }

    /// A.8: iPad portrait: one column at most 720, the regular-width ramp (tiles 96, captions 13, values 22,
    /// the 40 pt location bar as on a phone, Targets rows 52, readout 96), the dial at ceil8(0.40 H) in Medium with a map card under
    /// the quad.
    func testIPad() {
        let ipad = LayoutPlan.plan(w: 834, h: 1210, s: 1166, hasSpot: true, locked: true)
        XCTAssertTrue(ipad.tablet)
        XCTAssertLessThanOrEqual(ipad.columnWidth, 720)
        XCTAssertEqual(ipad.headingSize, 96)
        XCTAssertEqual(ipad.cardHeight, 40)
        XCTAssertEqual(ipad.targetsRowHeight, 52)
        XCTAssertEqual(ipad.tileHeight, 96)
        XCTAssertEqual(ipad.grid, .quad)
        XCTAssertEqual(ipad.map, .card)
        XCTAssertEqual(ipad.cells.last?.last?.tile, LayoutPlan.Tile.moon)
        XCTAssertGreaterThanOrEqual(ipad.mapHeight, LayoutPlan.mapMin - 0.5)
        XCTAssertEqual(ipad.dial, 488, accuracy: 0.5)
        XCTAssertEqual(Ramp.tablet.caption, 13)
        XCTAssertEqual(Ramp.tablet.value, 22)
        for layout in Layout.allCases {
            XCTAssertEqual(LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout).columnWidth, 720, layout.rawValue)
        }
        // No compass: the same grid as the layout's normal state.
        for layout in Layout.allCases {
            let normal = LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout, hasSpot: true)
            let none = LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: layout, hasSpot: true, noCompass: true)
            XCTAssertEqual(normal.grid, none.grid, layout.rawValue)
        }
    }

    /// "No heading" in words replaces the drawn dash: as rendered, centred on the column, 12 under the dial,
    /// a 24 capital (34 semibold), 150–200 wide, white at 55%, not a bar. Both Position lines at one size.
    @MainActor
    func testDrawnReadoutAndPosition() {
        XCTAssertEqual(MainView.noHeadingFailures(), [])
        XCTAssertEqual(MainView.positionSizeFailures(), [])
        XCTAssertEqual(MainView.noHeadingText, "No heading")
        XCTAssertEqual(MainView.noHeadingSpoken, "Heading unavailable")
        XCTAssertEqual(Palette.Op.noHeading, 0.55)
    }

    /// As drawn: the location bar where planned (first, 40 high), "No heading" under the dial, grids as each layout plans
    /// (and different), and the bottom as the plan left it, in every layout and in the sample, no-compass and
    /// live states.
    @MainActor
    func testDrawnScreenMatchesPlan() {
        let nav = Navigator(defaults: UserDefaults(suiteName: "bearings.tests.drawing") ?? .standard)
        let drawn = MainView.drawingFailures(nav: nav, width: 420, height: 840)
        XCTAssertEqual(drawn.failures, [])
    }

    /// One time formatter; the day period splits off for the narrow Sun tile.
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

    /// No "…" in any tile value, the Targets card or the location card (the strings, and what they must
    /// hold, measured on every device at Text Size 1.0 and 1.3); the lock row's values never split.
    @MainActor
    func testNoEllipsisAnywhere() throws {
        // The sample: Maroon Bells, 1 November 2026 (Navigator.sampleTime).
        let lat = 39.09898, lon = -106.94117, now = Date(timeIntervalSince1970: 1793551260)
        let times = Sky.sunTimes(at: now, lat: lat, lon: lon)
        let rise = try XCTUnwrap(times.sunriseDate), set = try XCTUnwrap(times.sunsetDate)
        XCTAssertEqual(MainView.fitFailures(sunrise: rise, sunset: set, now: now, lat: lat, lon: lon), [])
        XCTAssertFalse(MainView.noCompassText.contains("…"))
        XCTAssertFalse(MainView.noHeadingText.contains("…"))
        let lock = MainView.lockParts("Locked 240° · turn 12° right")
        XCTAssertEqual(lock.label, "Locked\u{00A0}240°")
        XCTAssertFalse(lock.cue.contains(" "))
    }

    /// The menus say what each layout changes.
    func testMenuSubtitles() {
        XCTAssertEqual(Layout.allCases.map(\.subtitle), [
            "Compass + big map", "Balanced · map tile", "Bigger compass · map in header", "Biggest compass · one row",
        ])
    }

    /// Night mode's secondary text is 4.5:1 or better on black.
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

    /// A.7: accessibility sizes scroll as one list: the location bar (wrapping, at least 40), the dial
    /// (0.40 H), the readout, the status line, then the Targets card, 96 rows and a 176 Map tile.
    func testAccessibilityTextScrollsAsOneList() {
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: layout, k: 1.3, accessibilityText: true,
                                    hasSpot: true, locked: true)
            XCTAssertTrue(p.list, layout.rawValue)
            XCTAssertEqual(p.grid, .list, layout.rawValue)
            XCTAssertEqual(p.dial, 352, accuracy: 0.5, layout.rawValue)
            XCTAssertEqual(p.rowHeights, [96, 96, 96, 96], layout.rawValue)
            XCTAssertEqual(p.mapHeight, LayoutPlan.listMap, accuracy: 0.5, layout.rawValue)
            XCTAssertEqual(p.targetsRowHeight, LayoutPlan.listTargetsRow, accuracy: 0.5, layout.rawValue)
            // The location bar first; the Targets card after the status line.
            XCTAssertLessThan(p.locationTop + p.cardHeight, p.dialTop, layout.rawValue)
            XCTAssertGreaterThanOrEqual(p.cardHeight, 40, layout.rawValue)
            XCTAssertGreaterThan(p.targetsTop, p.statusBottom, layout.rawValue)
            XCTAssertGreaterThan(p.gridTop, p.targetsTop, layout.rawValue)
        }
    }

    /// A.8 with the owner's mod: two panes: the location bar full width at the top (as in portrait), then the
    /// dial and the right pane level 12 under it, the right pane's spare 24 or less, and a map card of 240 or
    /// more; the four plans are four.
    func testTwoPanes() {
        let windows: [(w: CGFloat, h: CGFloat, s: CGFloat, mac: Bool)] = [(1210, 834, 790, false), (1376, 1032, 988, false), (1200, 800, 800, true)]
        for (w, h, s, mac) in windows {
            var grids: [LayoutPlan.Grid] = []
            for layout in Layout.allCases {
                let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout, hasSpot: true, locked: true, mac: mac)
                let name = "\(Int(w))x\(Int(h)) \(layout.rawValue)"
                XCTAssertTrue(p.twoPane, name)
                XCTAssertEqual(p.locationTop, p.topBand + 8, accuracy: 0.01, name)
                XCTAssertEqual(p.dialTop, p.locationTop + 40 + 12, accuracy: 0.01, name)
                XCTAssertEqual(p.targetsTop, p.dialTop, accuracy: 0.01, name)
                XCTAssertEqual(p.cardWidth, w - 48, accuracy: 0.01, name)
                XCTAssertGreaterThanOrEqual(p.trailingWidth, LayoutPlan.paneMin - 0.5, name)
                XCTAssertLessThanOrEqual(p.trailingWidth, LayoutPlan.paneMax + 0.5, name)
                XCTAssertEqual(p.map, .card, name)
                XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapPane - 0.5, name)
                if !p.trailingScrolls { XCTAssertLessThanOrEqual(p.bottomSpare, LayoutPlan.maxSpare + 0.5, name) }
                XCTAssertFalse(p.mapInHeader, name)
                XCTAssertEqual(p.mapButtonSlot, layout == .large || layout == .extraLarge, name)
                grids.append(p.grid)
            }
            XCTAssertEqual(grids, [.band, .quad, .six, .strip], "\(Int(w))x\(Int(h))")
        }
        // Expected dials: about 520 on iPad 11" landscape Medium, about 496 on a 1200 × 800 Mac window.
        XCTAssertEqual(LayoutPlan.plan(w: 1210, h: 834, s: 790).dial, 517, accuracy: 8)
        XCTAssertEqual(LayoutPlan.plan(w: 1200, h: 800, s: 800, mac: true).dial, 496, accuracy: 1)
        // A phone on its side is two panes too.
        XCTAssertTrue(LayoutPlan.plan(w: 852, h: 393, s: 372, isLandscapePhone: true).twoPane)
        // Extra Large keeps its strip only where the strip's Position column holds a longitude: a 900 × 700
        // window's 360 pane can't (134 of 156), so it takes two rows, Position full width, at 96.
        let narrow = LayoutPlan.plan(w: 900, h: 700, s: 700, layout: .extraLarge, hasSpot: true, locked: true, mac: true)
        XCTAssertTrue(narrow.twoPane)
        XCTAssertEqual(narrow.grid, .twoRow)
        XCTAssertEqual(narrow.cells[0].map(\.tile), [.position])
        XCTAssertEqual(narrow.rowHeights, [LayoutPlan.tileTablet, LayoutPlan.tileTablet])
        XCTAssertGreaterThanOrEqual(narrow.mapHeight, LayoutPlan.mapPane - 0.5)
        for d in LayoutPlan.devices {
            let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: .extraLarge, mac: d.mac)
            if p.twoPane && p.grid == .strip {
                XCTAssertGreaterThanOrEqual(p.stripWidths[0], LayoutPlan.stripPositionNeed(k: 1, tablet: p.tablet) - 0.5, d.name)
            }
        }
    }
}
