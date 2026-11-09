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

        // The layout planner (docs/REFINE.md "Concept A (chosen)", the same steps as Android): every device ×
        // layout × state × compass × text size keeps every gap at its token, the slim location bar first (safe
        // top + 8, 40 × k) with the dial 12 under it (8 after giving way), the Targets card under the status
        // line, the Targets card's rows, no more than 24 empty at the bottom (unless the stack is centred), nothing cut, every
        // dial at the owner's 0.40 H or more, rows whose widths add up to C, the dials in order and
        // neighbouring layouts never the same plan; the golden phones keep band / quad / six / strip.
        let planFailures = LayoutPlan.tableFailures()
        check(planFailures.isEmpty, "Layout planner table (\(planFailures.isEmpty ? "gaps are tokens, the 40 pt location bar first, the dial 12 under it, Targets under the status line, nothing empty or cut, rows add up to C, layouts distinct" : planFailures.prefix(3).joined(separator: "; ")))")
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
        // No "…" anywhere: the tiles' and the location card's strings, and what the tiles and the card must
        // hold measured in the system font on every device, at Text Size 1.0 and 1.3.
        let sampleTimes = Sky.sunTimes(at: Navigator.sampleTime, lat: 39.09898, lon: -106.94117)
        if let rise = sampleTimes.sunriseDate, let set = sampleTimes.sunsetDate {
            let fit = MainView.fitFailures(sunrise: rise, sunset: set, now: Navigator.sampleTime, lat: 39.09898, lon: -106.94117)
            check(fit.isEmpty, "No ellipsis in the tiles, the Targets card or the location card (\(fit.isEmpty ? "every value fits or wraps" : fit.prefix(3).joined(separator: "; ")))")
        } else {
            check(false, "No ellipsis in the tiles or the location card's time (no sunrise for the sample)")
        }
        // What is drawn: "No heading" in words where the readout goes (it replaces the drawn dash), both
        // Position lines at one size, and the whole screen against its plan in every layout and state: the
        // location bar where planned (first, 40 high), the grid each layout plans, and no more empty at the
        // bottom than planned.
        let noHeading = MainView.noHeadingFailures()
        check(noHeading.isEmpty, "No heading in words (\(noHeading.isEmpty ? "centred, 12 under the dial, 34 semibold, white 55%" : noHeading.prefix(2).joined(separator: "; ")))")
        let position = MainView.positionSizeFailures()
        check(position.isEmpty, "Both Position lines drawn at one size\(position.isEmpty ? "" : " (\(position.joined(separator: "; ")))")")
        let drawNav = Navigator(defaults: UserDefaults(suiteName: "bearings.selftest.drawing") ?? .standard)
        let drawSizes: [(CGFloat, CGFloat)] = [(402, 874), (375, 667), (834, 1210)]
        for (w, h) in drawSizes {
            let drawn = MainView.drawingFailures(nav: drawNav, width: w, height: h)
            check(drawn.failures.isEmpty, "Screen drawn as planned at \(Int(w)) × \(Int(h)) (\(drawn.failures.isEmpty ? "location bar at the top and 40 high as planned, grids as planned and distinct, bottom as planned" : drawn.failures.prefix(3).joined(separator: "; ")))")
            lines += drawn.info.map { "INFO \($0)" }
        }
        // iPad landscape (two panes) as drawn: the dial, readout and status line centred in the left pane
        // (no empty band under the status line), the map card down to the bottom on the right.
        let wide = MainView.twoPaneFailures(nav: drawNav, width: 1210, height: 834)
        check(wide.isEmpty, "Two panes drawn as planned at 1210 × 834 (\(wide.isEmpty ? "left pane centred, right pane to the bottom" : wide.prefix(3).joined(separator: "; ")))")
        // `--store` (the App Store screenshots): no Sample pill, today's date at the sample's time of day.
        drawNav.showSample(lock: 240, store: true)
        let storeDay: Bool = Calendar.current.isDateInToday(drawNav.now)
        let storeClock: Bool = Look.timeText(drawNav.now) == Look.timeText(Navigator.sampleTime)
        check(drawNav.sample && !drawNav.showsSamplePill && storeDay && storeClock,
              "Store sample: no Sample pill, today's date, the sample's time (\(MainView.dateLines(drawNav.now).full))")
        drawNav.showSample(lock: 240)
        check(drawNav.showsSamplePill, "The plain sample keeps its Sample pill")
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

        // The Lock Screen's W1 elevation design (no dial): the rectangular widget's one coordinate line to 4
        // places, and the circular gauge's 0–14,000 ft fill (clamped, the same in metres) and "9.6k" / "2.9k".
        let lockSample = WidgetReadings(snapshot: .sample, date: Date())
        var lockMetres = WidgetSnapshot.sample
        lockMetres.feet = false
        let lockMetresReadings = WidgetReadings(snapshot: lockMetres, date: Date())
        var lockHigh = WidgetSnapshot.sample, lockLow = WidgetSnapshot.sample, lockNone = WidgetSnapshot.sample
        lockHigh.elevation = 5000
        lockLow.elevation = -400
        lockNone.elevation = nil
        let gauge = lockSample.gaugeFraction ?? -1
        let gaugeOK = abs(gauge - 2922 / Geo.foot / 14000) < 0.0001 && lockMetresReadings.gaugeFraction == lockSample.gaugeFraction
            && WidgetReadings(snapshot: lockHigh, date: Date()).gaugeFraction == 1
            && WidgetReadings(snapshot: lockLow, date: Date()).gaugeFraction == 0
            && WidgetReadings(snapshot: lockNone, date: Date()).gaugeFraction == nil
        check(gaugeOK, String(format: "Lock Screen circular gauge fills 0–14,000 ft, clamped, the same in metres (%.3f)", gauge))
        let compactFeet = lockSample.compactElevation, compactMetres = lockMetresReadings.compactElevation
        check(compactFeet?.number == "9.6k" && compactFeet?.unit == "ft" && compactMetres?.number == "2.9k" && compactMetres?.unit == "m",
              "Lock Screen circular reads 9.6k ft / 2.9k m (\(compactFeet?.number ?? "—") \(compactFeet?.unit ?? ""), \(compactMetres?.number ?? "—") \(compactMetres?.unit ?? ""))")
        check(lockSample.lockCoordinates == "39.0990° N  106.9412° W",
              "Lock Screen rectangular coordinates on one line to 4 places (\(lockSample.lockCoordinates))")
        check(lockSample.shortPlace == "Maroon Bells", "Lock Screen short place (\(lockSample.shortPlace))")

        // The widgets, from the app's own last fix as the widget reads it, with the sample's marked spot and
        // locked bearing on the Home Screen's north-up dial; the Lock Screen sizes in the W1 elevation design.
        if let fix = nav.fix {
            var snapshot = WidgetSnapshot.sample
            snapshot.latitude = fix.latitude
            snapshot.longitude = fix.longitude
            // The sample's spot moved with the fix (about 9 mi NE), so the pin and pill read as in the mock
            // wherever the simulator is.
            let spotDLat: Double = 39.1911 - WidgetSnapshot.sample.latitude
            let spotDLon: Double = -106.8175 - WidgetSnapshot.sample.longitude
            snapshot.spotLatitude = fix.latitude + spotDLat
            snapshot.spotLongitude = fix.longitude + spotDLon
            snapshot.place = nav.place
            snapshot.time = fix.time
            if case let .value(metres, fromGPS, _) = nav.elevation { snapshot.elevation = metres; snapshot.elevationFromGPS = fromGPS }
            let entry = WidgetTimeline.entries(snapshot: snapshot)[0]
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
        // No padding: the widget has no system content margins; its views keep their own 8 pt inset.
        return WidgetView(entry: entry, family: family)
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
