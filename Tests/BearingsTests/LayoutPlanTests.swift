import CoreGraphics
import XCTest
@testable import Bearings

/// The "Instrument panel" planner (docs/REFINE.md §3.3–§3.6, §4.7 and Cycle 2; docs/LAYOUTS.md): nothing
/// empty (no more than 24 at the bottom), nothing cut, every dial at its floor or more, the map whole or a
/// tile, every row's widths adding up to C, a Mac window 16 or more from its edges, and the four layouts
/// different from each other (24 of dial or a grid mode between neighbours). The same golden table runs in the Mac and iPhone
/// self-tests and, ported, in android/app/src/test/.../LayoutPlanTest.kt and SelfTest.kt.
final class LayoutPlanTests: XCTestCase {
    /// Width, full height, safe height (pt; dp on the Pixel).
    private let phones: [(name: String, w: CGFloat, h: CGFloat, s: CGFloat, mac: Bool)] = [
        ("iPhone SE", 375, 667, 647, false),
        ("iPhone 16", 393, 852, 759, false),
        ("iPhone 16 Pro", 402, 874, 778, false),
        ("iPhone 17 Pro Max", 440, 956, 862, false),
        ("Pixel 7", 412, 915, 839, false),
        ("Mac 420x840", 420, 840, 840, true),
        ("Mac 380x740", 380, 740, 740, true),
        ("iPad 11 portrait", 834, 1210, 1166, false),
        ("iPad 13 portrait", 1032, 1376, 1332, false),
    ]
    private let states: [(name: String, locked: Bool, spot: Bool)] = [
        ("none", false, false), ("locked", true, false), ("marked", false, true), ("both", true, true),
    ]

    func testGoldenTable() {
        XCTAssertEqual(LayoutPlan.tableFailures(), [])
    }

    func testNothingEmptyNothingCut() {
        for d in phones {
            for layout in Layout.allCases {
                for state in states {
                    for k in [CGFloat(1), 1.3] {
                        let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k,
                                                hasSpot: state.spot, locked: state.locked, mac: d.mac)
                        let name = "\(d.name) \(layout.rawValue) \(state.name) k\(k)"
                        if p.list {
                            // The scrolling list: complete blocks, the dial at min(C − 32, 0.40 H) or 120.
                            XCTAssertEqual(p.grid, .list, name)
                            XCTAssertEqual(p.map, .card, name)
                            XCTAssertGreaterThanOrEqual(p.dial, LayoutPlan.dialMin - 0.5, name)
                            continue
                        }
                        XCTAssertFalse(p.twoPane, name)
                        XCTAssertLessThanOrEqual(p.bottomSpare, LayoutPlan.maxSpare + 0.5, "\(name): empty at the bottom")
                        XCTAssertLessThanOrEqual(p.used, d.s + 0.5, "\(name): cut off")
                        XCTAssertGreaterThanOrEqual(p.used, d.s - 0.5, "\(name): height unaccounted for")
                        XCTAssertGreaterThanOrEqual(p.dial + 0.5, p.floor, "\(name): dial under its floor")
                        XCTAssertGreaterThanOrEqual(p.tileHeight, LayoutPlan.tile * p.k - 0.5, name)
                        XCTAssertLessThanOrEqual(p.tileHeight, (p.tablet ? LayoutPlan.tileGrownTablet : LayoutPlan.tileGrown) * p.k + 0.5, name)
                        // Only Medium grows its tiles; dial → readout is always 12.
                        if p.layout != .medium { XCTAssertEqual(p.tileHeight, LayoutPlan.tile * p.k, accuracy: 0.5, name) }
                        XCTAssertEqual(p.gapDialReadout, LayoutPlan.dialToReadout, accuracy: 0.01, name)
                        // Extra Large's map is the header button on every device.
                        if p.layout == .extraLarge { XCTAssertEqual(p.map, .button, name) }
                        // The map is whole or a tile, never a sliver.
                        if p.map == .card { XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapMin - 0.5, "\(name): map card") }
                        // The compact row has no Map tile: the map is a card or the header button.
                        if p.grid == .compact { XCTAssertNotEqual(p.map, .tile, name) }
                        XCTAssertEqual(p.mapInHeader, p.map == .button, name)
                    }
                }
            }
        }
    }

    /// The worked numbers on iPhone 16 Pro (402 × 874, S = 778, C = 370), with Cycle 2's layout rules.
    func testWorkedNumbersIPhone16Pro() {
        let small = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .small)
        XCTAssertEqual(small.grid, .compact)
        XCTAssertEqual(small.map, .card)
        XCTAssertEqual(small.dial, 0.36 * 874, accuracy: 1)
        XCTAssertGreaterThanOrEqual(small.mapHeight, 140)

        let medium = LayoutPlan.plan(w: 402, h: 874, s: 778)
        XCTAssertEqual(medium.layout, .medium)
        XCTAssertEqual(medium.dial, 362, accuracy: 1)
        XCTAssertEqual(medium.grid, .full)
        XCTAssertEqual(medium.map, .tile)
        XCTAssertEqual(medium.tileHeight, LayoutPlan.tileGrown, accuracy: 0.5)

        let large = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large)
        XCTAssertEqual(large.grid, .full)
        XCTAssertEqual(large.map, .tile)
        XCTAssertEqual(large.tileHeight, LayoutPlan.tile, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(large.dial - medium.dial, 24 - 0.5)

        let mediumSample = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        let largeSample = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        XCTAssertEqual(mediumSample.grid, .full)
        XCTAssertEqual(largeSample.grid, .full, "Large keeps the full grid")
        XCTAssertEqual(largeSample.map, .tile)
        XCTAssertGreaterThanOrEqual(largeSample.dial - mediumSample.dial, 24 - 0.5)

        let xl = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .extraLarge)
        XCTAssertEqual(xl.grid, .compact)
        XCTAssertEqual(xl.map, .button)
        XCTAssertEqual(xl.dial, 386, accuracy: 1)
        XCTAssertEqual(xl.readoutScale, 1.25, accuracy: 0.001)
        XCTAssertEqual(xl.headingSize, 70, accuracy: 0.01)
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

    /// C2.2 #2: neighbouring layouts differ by 24 or more of dial, or by grid mode.
    func testLayoutsAreDistinct() {
        for d in LayoutPlan.devices {
            for state in [(false, false), (true, true)] {
                let plans = Layout.allCases.map {
                    LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: $0, hasSpot: state.1, locked: state.0, mac: d.mac)
                }
                for (a, b) in zip(plans, plans.dropFirst()) where !a.list && !b.list && !a.twoPane && !b.twoPane {
                    XCTAssertTrue(a.grid != b.grid || b.dial - a.dial >= 24 - 0.5,
                                  "\(d.name): \(a.layout.rawValue) \(Int(a.dial)) and \(b.layout.rawValue) \(Int(b.dial))")
                }
            }
        }
    }

    /// C2.3 #17: a Mac window keeps 16 or more on every edge (24 at 600 or wider), and the smallest window
    /// holds every layout with the sample without scrolling.
    func testMacMargins() {
        let narrow = LayoutPlan.plan(w: 420, h: 840, s: 840, mac: true)
        XCTAssertEqual(narrow.margin, 16)
        XCTAssertEqual(narrow.topInset, 16)
        XCTAssertEqual(narrow.bottomInset, 16)
        let wide = LayoutPlan.plan(w: 1200, h: 800, s: 800, mac: true)
        XCTAssertEqual(wide.margin, 24)
        XCTAssertEqual(wide.bottomInset, 24)
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: LayoutPlan.macMinWidth, h: LayoutPlan.macMinHeight, s: LayoutPlan.macMinHeight,
                                    layout: layout, hasSpot: true, locked: true, mac: true)
            XCTAssertFalse(p.list, layout.rawValue)
        }
    }

    /// C2.3 #5 and #13: iPad portrait Medium promotes the map to a card of 200 or more; with no compass,
    /// Medium's tiles stay 72 and the map is a card.
    func testMapCards() {
        let ipad = LayoutPlan.plan(w: 834, h: 1210, s: 1166)
        XCTAssertEqual(ipad.map, .card)
        XCTAssertGreaterThanOrEqual(ipad.mapHeight, LayoutPlan.mapPromoted - 0.5)
        let ipadXL = LayoutPlan.plan(w: 834, h: 1210, s: 1166, layout: .extraLarge)
        XCTAssertEqual(ipadXL.map, .button)
        let noCompass = LayoutPlan.plan(w: 420, h: 840, s: 840, noCompass: true, mac: true)
        XCTAssertEqual(noCompass.map, .card)
        XCTAssertEqual(noCompass.tileHeight, LayoutPlan.tile, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(noCompass.mapHeight, LayoutPlan.mapNoCompass - 0.5)
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

    /// C2's tests: no "…" in any tile value or in the header time (the strings, and what the compact row and
    /// the header must hold, measured on every device at Text Size 1.0 and 1.3), and the no-compass readout
    /// is "—°" (U+2014 and the degree sign).
    @MainActor
    func testNoEllipsisAnywhere() throws {
        // The sample: Maroon Bells, 1 November 2026 (Navigator.sampleTime).
        let lat = 39.09898, lon = -106.94117, now = Date(timeIntervalSince1970: 1793551260)
        let times = Sky.sunTimes(at: now, lat: lat, lon: lon)
        let rise = try XCTUnwrap(times.sunriseDate), set = try XCTUnwrap(times.sunsetDate)
        XCTAssertEqual(MainView.fitFailures(sunrise: rise, sunset: set, now: now, lat: lat, lon: lon), [])
        XCTAssertEqual(MainView.noHeadingText, "\u{2014}°")
        XCTAssertFalse(MainView.noCompassText.contains("…"))
    }

    /// C2.2 #2: the ⋯ menu's subtitle states the result ("Dial 386 · map in header").
    func testMenuSubtitle() {
        let xl = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .extraLarge, hasSpot: true, locked: true)
        XCTAssertEqual(xl.menuSubtitle, "Dial 386 · map in header")
        XCTAssertTrue(LayoutPlan.plan(w: 402, h: 874, s: 778).menuSubtitle.hasSuffix("map tile"))
        XCTAssertTrue(LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .small).menuSubtitle.hasSuffix("map card"))
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

    func testAccessibilityTextScrollsAsOneList() {
        for layout in Layout.allCases {
            let p = LayoutPlan.plan(w: 393, h: 852, s: 759, layout: layout, k: 1.3, accessibilityText: true,
                                    hasSpot: true, locked: true)
            XCTAssertTrue(p.list, layout.rawValue)
            XCTAssertEqual(p.grid, .list, layout.rawValue)
            XCTAssertEqual(p.map, .card, layout.rawValue)
            XCTAssertEqual(p.mapHeight, LayoutPlan.listMap, accuracy: 0.5, layout.rawValue)
            XCTAssertLessThanOrEqual(p.dial, min(393 - 32, 0.40 * 852) + 0.5, layout.rawValue)
        }
    }

    func testTwoPanes() {
        for layout in Layout.allCases {
            let windows: [(w: CGFloat, h: CGFloat, s: CGFloat)] = [(1210, 834, 790), (1376, 1032, 988)]
            for (w, h, s) in windows {
                let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout)
                let name = "\(Int(w))x\(Int(h)) \(layout.rawValue)"
                XCTAssertTrue(p.twoPane, name)
                XCTAssertGreaterThanOrEqual(p.trailingWidth, LayoutPlan.paneMin - 0.5, name)
                XCTAssertLessThanOrEqual(p.trailingWidth, LayoutPlan.paneMax + 0.5, name)
                XCTAssertEqual(p.grid, .full, name)
                // Extra Large's map is the header button everywhere; the others keep a tile or a card.
                if layout == .extraLarge { XCTAssertEqual(p.map, .button, name) } else { XCTAssertNotEqual(p.map, .button, name) }
                XCTAssertEqual(p.tileHeight, LayoutPlan.tilePane, accuracy: 0.5, "\(name): fixed 80 rows")
                if p.map == .card { XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapMin - 0.5, name) }
            }
        }
        // A phone on its side is two panes too.
        XCTAssertTrue(LayoutPlan.plan(w: 852, h: 393, s: 372, isLandscapePhone: true).twoPane)
    }
}
