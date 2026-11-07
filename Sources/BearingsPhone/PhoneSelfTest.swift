import SwiftUI
import UIKit
import WidgetKit

/// `--selftest` in the iOS Simulator (CI): the core's known answers, a real location fix (CI sets the
/// Simulator's location to Maroon Bells, Colorado), the live ground elevation for it, the place's name,
/// the heading's absence or presence, and every widget size (Home Screen and Lock Screen) drawn to a PNG.
/// Writes Documents/report.txt, first line "ALL PASSED" or "FAILED …", and the PNGs beside it; CI then
/// photographs the screen.
@MainActor
enum PhoneSelfTest {
    static func run(nav: Navigator) async {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var lines: [String] = []
        var failed = 0
        func check(_ ok: Bool, _ what: String) { lines.append("\(ok ? "PASS" : "FAIL") \(what)"); if !ok { failed += 1 } }

        for (name, ok) in CoreChecks.run() { check(ok, name) }

        // The layout planner (docs/REFINE.md Cycle 3 §C3.3, one rule set with Android): every device × layout ×
        // state × compass × text size keeps every gap at its token × k, the header at the safe top + 8, no
        // more than 24 empty at the bottom (unless the panel is centred), nothing cut, every dial at its floor
        // (the owner's 0.40 H in portrait) or more, tiles under their cap, rows whose widths and gutters add up
        // to C, and neighbouring layouts with different grids (Medium and Large also a different map surface
        // and 16 of dial) unless one gave its grid up to keep the dial at 0.40 H.
        let planFailures = LayoutPlan.tableFailures()
        check(planFailures.isEmpty, "Layout planner table (\(planFailures.isEmpty ? "gaps are tokens, header pinned, nothing empty or cut, rows add up to C, layouts distinct" : planFailures.prefix(3).joined(separator: "; ")))")
        let summaryDevices: [(String, CGFloat, CGFloat, CGFloat)] = [
            ("iPhone SE", 375, 667, 647), ("iPhone 16", 393, 852, 759), ("iPhone 16 Pro", 402, 874, 778),
            ("iPad 11 portrait", 834, 1210, 1166),
        ]
        // The owner's hard rule: the compass takes up at least 40% of the screen. In portrait, at Text Size
        // 1.0 and 1.3, every layout's dial is at least min(0.40 H, its width cap) with the sample (locked and
        // marked) and live (nothing locked or marked); a dial under it fails.
        var ownerFailures: [String] = []
        for (name, w, h, s) in summaryDevices {
            for (state, both) in [("sample", true), ("live", false)] {
                for k in [CGFloat(1), 1.3] {
                    for layout in Layout.allCases {
                        let p = LayoutPlan.plan(w: w, h: h, s: s, layout: layout, k: k, hasSpot: both, locked: both)
                        if p.dial < p.ownerFloor(h: h) - 0.5 {
                            ownerFailures.append("\(name) \(state) \(layout.rawValue) k\(k): dial \(Int(p.dial)) = \(Int((100 * p.dial / h).rounded()))% of H")
                        }
                    }
                }
            }
            for line in LayoutPlan.summary(w: w, h: h, s: s, hasSpot: true, locked: true) {
                lines.append("INFO \(name), sample: \(line)")
            }
            for line in LayoutPlan.summary(w: w, h: h, s: s, hasSpot: false, locked: false) {
                lines.append("INFO \(name), live: \(line)")
            }
        }
        check(ownerFailures.isEmpty, "Owner's rule: dial ≥ 40% of H in portrait (\(ownerFailures.isEmpty ? "every layout, sample and live, Text Size 1.0 and 1.3" : ownerFailures.prefix(3).joined(separator: "; ")))")
        // No "…" anywhere (C2): the tiles' and the header's strings, and what the tiles and the header must
        // hold measured in the system font on every device, at Text Size 1.0 and 1.3.
        let sampleTimes = Sky.sunTimes(at: Navigator.sampleTime, lat: 39.09898, lon: -106.94117)
        if let rise = sampleTimes.sunriseDate, let set = sampleTimes.sunsetDate {
            let fit = MainView.fitFailures(sunrise: rise, sunset: set, now: Navigator.sampleTime, lat: 39.09898, lon: -106.94117)
            check(fit.isEmpty, "No ellipsis in the tiles, the lock row or the header (\(fit.isEmpty ? "every value fits or wraps" : fit.prefix(3).joined(separator: "; ")))")
        } else {
            check(false, "No ellipsis in the tiles or the header time (no sunrise for the sample)")
        }
        // What is drawn (C3): the no-heading dash on the digits' midline (it drew as "_ °"), both Position
        // lines at one size, and the whole screen against its plan in every layout and state: the header
        // pinned, the grid each layout plans (Large is not Medium), and no more empty at the bottom than planned.
        let dash = MainView.dashFailures()
        check(dash.isEmpty, "No-heading readout drawn as a centred dash (\(dash.isEmpty ? "within 4 pt of the digits' midline" : dash.prefix(2).joined(separator: "; ")))")
        let position = MainView.positionSizeFailures()
        check(position.isEmpty, "Both Position lines drawn at one size\(position.isEmpty ? "" : " (\(position.joined(separator: "; ")))")")
        let drawNav = Navigator(defaults: UserDefaults(suiteName: "bearings.selftest.drawing") ?? .standard)
        let drawSizes: [(CGFloat, CGFloat)] = [(402, 874), (375, 667), (834, 1210)]
        for (w, h) in drawSizes {
            let drawn = MainView.drawingFailures(nav: drawNav, width: w, height: h)
            check(drawn.failures.isEmpty, "Screen drawn as planned at \(Int(w)) × \(Int(h)) (\(drawn.failures.isEmpty ? "header pinned, grids as planned and distinct, bottom as planned" : drawn.failures.prefix(3).joined(separator: "; ")))")
            lines += drawn.info.map { "INFO \($0)" }
        }
        // Night secondary text: at least 4.5:1 on black (§4.3).
        let contrast = Palette.nightSecondaryContrast()
        check(contrast >= 4.5, String(format: "Night secondary text contrast %.2f:1", contrast))
        // No coordinate is ever ellipsized (§4.7): the strings themselves never carry "…".
        let ellipsized = Geo.Format.allCases.filter { format in
            switch Geo.format(format, lat: 39.09898, lon: -106.94117) {
            case let .pair(lat, lon): return lat.contains("…") || lon.contains("…")
            case let .single(value): return value.contains("…")
            }
        }
        check(ellipsized.isEmpty, "Coordinates without an ellipsis in every format\(ellipsized.isEmpty ? "" : " (\(ellipsized.map(\.rawValue).joined(separator: ", ")))")")

        check(Geo.bundledCities.count > 10000, "Place list bundled (\(Geo.bundledCities.count) places)")
        let offline = Geo.offlinePlaceName(lat: 39.09898, lon: -106.94117, feet: true)
        check(offline == "66 mi NE of Montrose, Colorado", "Offline place name at Maroon Bells (\(offline ?? "none"))")

        nav.start()
        var waited = 0
        while nav.fix == nil && waited < 40 { try? await Task.sleep(for: .milliseconds(500)); waited += 1 }
        if let fix = nav.fix {
            check(abs(fix.latitude - 39.09898) < 0.01 && abs(fix.longitude + 106.94117) < 0.01,
                  String(format: "Location fix (%.5f, %.5f)", fix.latitude, fix.longitude))
        } else {
            check(false, "Location fix (none in 20 s; access \(nav.access))")
        }
        waited = 0
        while nav.groundState != .ok && nav.groundState != .failed && waited < 40 { try? await Task.sleep(for: .milliseconds(500)); waited += 1 }
        if case let .value(metres, _, source) = nav.elevation {
            check(abs(metres - 2925) < 150, "Elevation \(Int(metres)) m (\(source))")
        } else {
            check(false, "Elevation (state \(nav.groundState))")
        }
        waited = 0
        while !nav.placeLookedUp && waited < 30 { try? await Task.sleep(for: .milliseconds(500)); waited += 1 }
        check(!(nav.place?.isEmpty ?? true), "Place name (\(nav.place ?? "none"))")
        check(nav.sunTimes != nil && nav.sunPosition != nil, "Sun and moon for here and now")
        // The Simulator has no compass: the dial must say so rather than spin.
        try? await Task.sleep(for: .seconds(4.5))
        check(nav.compass == .unavailable || nav.heading != nil, "Compass state (\(nav.compass))")

        // The widgets, from the app's own last fix as the widget reads it, with the large one's map.
        if let fix = nav.fix {
            var snapshot = WidgetSnapshot.sample
            snapshot.latitude = fix.latitude
            snapshot.longitude = fix.longitude
            snapshot.place = nav.place
            snapshot.time = fix.time
            if case let .value(metres, fromGPS, _) = nav.elevation { snapshot.elevation = metres; snapshot.elevationFromGPS = fromGPS }
            let map = await MapSnapshot.make(latitude: fix.latitude, longitude: fix.longitude, size: WidgetTimeline.mapSize)
            check(map != nil, "Map picture for the large widget")
            let entry = WidgetTimeline.entries(snapshot: snapshot, map: map)[0]
            let empty = BearingsEntry(date: Date(), snapshot: nil)
            for (family, size, name) in sizes {
                check(render(widget(entry, family, size), to: docs.appendingPathComponent("widget-\(name).png")), "\(name) widget draws")
                check(render(widget(empty, family, size), to: docs.appendingPathComponent("widget-\(name)-empty.png")), "\(name) widget draws before a fix")
            }
        }

        let checks = lines.filter { !$0.hasPrefix("INFO") }.count
        let head = failed == 0 ? "ALL PASSED (\(checks) checks)" : "FAILED \(failed) of \(checks) checks"
        try? ([head] + lines).joined(separator: "\n").appending("\n").write(to: docs.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
    }

    static let sizes: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 170, height: 170), "small"),
        (.systemMedium, CGSize(width: 364, height: 170), "medium"),
        (.systemLarge, CGSize(width: 364, height: 382), "large"),
        (.accessoryCircular, CGSize(width: 76, height: 76), "lock-circular"),
        (.accessoryRectangular, CGSize(width: 172, height: 76), "lock-rectangular"),
        (.accessoryInline, CGSize(width: 257, height: 26), "lock-inline"),
    ]

    /// A widget as the system shows it: Home Screen sizes on the widget background, Lock Screen sizes in
    /// white on a wallpaper-dark backdrop (the Lock Screen tints them).
    private static func widget(_ entry: BearingsEntry, _ family: WidgetFamily, _ size: CGSize) -> some View {
        let home = ([.systemSmall, .systemMedium, .systemLarge] as [WidgetFamily]).contains(family)
        return WidgetView(entry: entry, family: family)
            .padding(home ? 16 : 0)
            .frame(width: size.width, height: size.height)
            .foregroundStyle(.white)
            .background { if home { WidgetBackground() } else { Color(white: 0.12) } }
            .clipShape(RoundedRectangle(cornerRadius: home ? 22 : (family == .accessoryCircular ? 38 : 10), style: .continuous))
    }

    /// Renders at 2x, saves the PNG, and says whether it has real content (more than a few colours).
    private static func render<V: View>(_ view: V, to url: URL) -> Bool {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2
        guard let image = renderer.uiImage, let png = image.pngData(), let cg = image.cgImage,
              let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else { return false }
        try? png.write(to: url)
        var colours = Set<UInt32>()
        let bpp = cg.bitsPerPixel / 8
        for y in stride(from: 0, to: cg.height, by: max(1, cg.height / 24)) {
            for x in stride(from: 0, to: cg.width, by: max(1, cg.width / 24)) {
                let i = y * cg.bytesPerRow + x * bpp
                colours.insert(UInt32(bytes[i]) << 16 | UInt32(bytes[i + 1]) << 8 | UInt32(bytes[i + 2]))
            }
        }
        return colours.count > 3
    }
}
