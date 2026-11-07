import CoreGraphics
import XCTest
@testable import Bearings

/// The "Instrument panel" planner (docs/REFINE.md §3.3–§3.6 and §4.7; docs/LAYOUTS.md): nothing empty
/// (no more than 24 at the bottom), nothing cut, every dial at its floor or more, the map whole or a tile,
/// and the four layouts different from each other. The same golden table runs in the Mac and iPhone
/// self-tests and, ported, in android/app/src/test/.../LayoutPlanTest.kt and SelfTest.kt.
final class LayoutPlanTests: XCTestCase {
    /// Width, full height, safe height (pt; dp on the Pixel).
    private let phones: [(name: String, w: CGFloat, h: CGFloat, s: CGFloat)] = [
        ("iPhone SE", 375, 667, 647),
        ("iPhone 16", 393, 852, 759),
        ("iPhone 16 Pro", 402, 874, 778),
        ("iPhone 17 Pro Max", 440, 956, 862),
        ("Pixel 7", 412, 915, 839),
        ("Mac 420x840", 420, 840, 840),
        ("Mac 380x720", 380, 720, 720),
        ("iPad 11 portrait", 834, 1210, 1166),
        ("iPad 13 portrait", 1032, 1376, 1332),
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
                                                hasSpot: state.spot, locked: state.locked)
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
                        XCTAssertLessThanOrEqual(p.tileHeight, LayoutPlan.tileGrown * p.k + 0.5, name)
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

    /// The worked numbers of REFINE.md §3.4 on iPhone 16 Pro (402 × 874, S = 778, C = 370).
    func testWorkedNumbersIPhone16Pro() {
        let small = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .small)
        XCTAssertEqual(small.grid, .compact)
        XCTAssertEqual(small.map, .card)
        XCTAssertEqual(small.dial, 0.36 * 874, accuracy: 1)
        XCTAssertGreaterThanOrEqual(small.mapHeight, 140)

        let medium = LayoutPlan.plan(w: 402, h: 874, s: 778)
        XCTAssertEqual(medium.layout, .medium)
        XCTAssertEqual(medium.dial, 370, accuracy: 1)
        XCTAssertEqual(medium.grid, .full)
        XCTAssertEqual(medium.map, .tile)
        XCTAssertEqual(medium.tileHeight, LayoutPlan.tileGrown, accuracy: 0.5)

        let mediumSample = LayoutPlan.plan(w: 402, h: 874, s: 778, hasSpot: true, locked: true)
        XCTAssertEqual(mediumSample.grid, .full)
        XCTAssertEqual(mediumSample.map, .tile)
        XCTAssertGreaterThanOrEqual(mediumSample.dial, 345)
        XCTAssertLessThanOrEqual(mediumSample.dial, 360)

        let large = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large)
        XCTAssertEqual(large.grid, .full)
        XCTAssertGreaterThan(large.dial, medium.dial)
        let largeSample = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .large, hasSpot: true, locked: true)
        XCTAssertEqual(largeSample.grid, .compact, "Large gives up the second row before the dial shrinks")
        XCTAssertEqual(largeSample.map, .button)
        XCTAssertGreaterThan(largeSample.dial, mediumSample.dial)

        let xl = LayoutPlan.plan(w: 402, h: 874, s: 778, layout: .extraLarge)
        XCTAssertEqual(xl.grid, .compact)
        XCTAssertEqual(xl.map, .button)
        XCTAssertGreaterThanOrEqual(xl.dial, large.dial)
        XCTAssertEqual(xl.readoutScale, 1.15, accuracy: 0.001)
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
                let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout, showsFooter: true)
                let name = "\(Int(w))x\(Int(h)) \(layout.rawValue)"
                XCTAssertTrue(p.twoPane, name)
                XCTAssertGreaterThanOrEqual(p.trailingWidth, LayoutPlan.paneMin - 0.5, name)
                XCTAssertLessThanOrEqual(p.trailingWidth, LayoutPlan.paneMax + 0.5, name)
                XCTAssertEqual(p.grid, .full, name)
                XCTAssertNotEqual(p.map, .button, name)
                if p.map == .card { XCTAssertGreaterThanOrEqual(p.mapHeight, LayoutPlan.mapMin - 0.5, name) }
                XCTAssertLessThanOrEqual(p.bottomSpare, LayoutPlan.maxSpare + 0.5, name)
            }
        }
        // A phone on its side is two panes too.
        XCTAssertTrue(LayoutPlan.plan(w: 852, h: 393, s: 372, isLandscapePhone: true).twoPane)
    }
}
