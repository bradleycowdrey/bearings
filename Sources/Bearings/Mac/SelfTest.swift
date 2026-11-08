import AppKit
import SwiftUI
import WidgetKit

/// `Bearings --selftest <folder>`: what CI checks on a real Mac. The core's known answers, a live ground
/// elevation from Open-Meteo, naming a place (the geocoder and the bundled list), the update check, the
/// screen drawn with the sample place (and in night mode, and in each layout), the layout planner's golden
/// table (nothing empty, nothing cut, every dial at its floor), night contrast, and every widget size drawn the way the
/// widget draws it. Writes report.txt (first line "ALL PASSED" or "FAILED …") and PNGs to the folder,
/// then quits.
@MainActor
enum SelfTest {
    static var folder: URL? {
        argument(after: "--selftest").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// The launch argument after `flag` (`--selftest <folder>`, `--layout <id>`).
    static func argument(after flag: String) -> String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    static func run(nav: Navigator, folder: URL) async {
        // An ad-hoc signed build isn't in the team's App Group; the self-test doesn't need it.
        SharedStore.enabled = false
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var lines: [String] = []
        var failed = 0
        func check(_ ok: Bool, _ what: String) { lines.append("\(ok ? "PASS" : "FAIL") \(what)"); if !ok { failed += 1 } }

        for (problem, ok) in CoreChecks.run() { check(ok, problem) }

        let metres = await Navigator.fetchGround(latitude: 39.099, longitude: -106.941)
        check(metres.map { abs($0 - 2925) < 150 } ?? false, "Open-Meteo ground elevation at Maroon Bells (\(metres.map { "\(Int($0)) m" } ?? "no answer"))")

        // Naming the place: the bundled list on its own, then the way the app does it.
        check(Geo.bundledCities.count > 10000, "Place list bundled (\(Geo.bundledCities.count) places)")
        let offline = Geo.offlinePlaceName(lat: 39.09898, lon: -106.94117, feet: true)
        check(offline == "66 mi NE of Montrose, Colorado", "Offline place name at Maroon Bells (\(offline ?? "none"))")
        check(Geo.offlinePlaceName(lat: 0, lon: -140, feet: true) == "Far from any town", "Far from any town in the Pacific")
        let named = await PlaceNamer.name(latitude: 39.09898, longitude: -106.94117, feet: true)
        let namedText = named.map { $0.offline ? "\($0.text), offline" : $0.text } ?? "none"
        check(!(named?.text.isEmpty ?? true), "Place name at Maroon Bells (\(namedText))")

        check(Updater.isNewer("0.2.0", than: "0.1.9") && !Updater.isNewer("0.1.0", than: "0.1.0") && !Updater.isNewer("1.0", than: "dev"), "Update version comparison")

        // The layout planner (docs/REFINE.md "Concept A (chosen)", the same steps as Android): every device ×
        // layout × state × compass × text size keeps every gap at its token, the slim location bar first (the
        // title band + 8, 40 × k) with the dial 12 under it (8 after giving way), the Targets card under the
        // status line, the Targets card's rows, no more than 24 empty at the bottom (unless the stack is centred), nothing cut, every
        // dial at the owner's 0.40 H or more, rows whose widths add up to C, the dials in order and
        // neighbouring layouts never the same plan; the golden phones keep band / quad / six / strip.
        let planFailures = LayoutPlan.tableFailures()
        check(planFailures.isEmpty, "Layout planner table (\(planFailures.isEmpty ? "gaps are tokens, the 40 pt location bar first, the dial 12 under it, Targets under the status line, nothing empty or cut, rows add up to C, layouts distinct" : planFailures.prefix(3).joined(separator: "; ")))")
        let mac = LayoutPlan.plan(w: 420, h: 840, s: 840, hasSpot: true, locked: true, mac: true)
        let macLarge = LayoutPlan.plan(w: 420, h: 840, s: 840, layout: .large, hasSpot: true, locked: true, mac: true)
        check(abs(mac.dial - 336) < 1 && mac.layout == .medium && mac.grid == .quad && mac.map == .tile && mac.bottomSpare <= LayoutPlan.maxSpare,
              "Medium at 420 × 840 with the sample: dial \(Int(mac.dial.rounded())) pt, 2 × 2 with the Map tile, \(Int(mac.bottomSpare.rounded())) pt spare")
        check(macLarge.grid == .six && macLarge.map == .button && macLarge.dial >= mac.dial - 0.5,
              "Large at 420 × 840 with the sample: 3 × 2, the map in the location card, dial \(Int(macLarge.dial.rounded())) pt (at least Medium's)")
        let macBarTop: CGFloat = LayoutPlan.macTitleBand + LayoutPlan.topGap
        let macDialTop: CGFloat = macBarTop + LayoutPlan.card + LayoutPlan.cardToDial
        let macTops: Bool = abs(mac.locationTop - macBarTop) < 0.5 && abs(mac.dialTop - mac.topExtra - macDialTop) < 0.5
        check(mac.margin == LayoutPlan.macInset && macTops && mac.bottomInset == LayoutPlan.macInset,
              "Mac window: sides \(Int(mac.margin)), location bar at \(Int(mac.locationTop)) (28 + 8), dial top \(Int(mac.dialTop)) (+ 40 + 12), bottom \(Int(mac.bottomInset)) pt")
        // The owner's hard rule: the compass takes up at least 40% of the window. At 420 × 840 and the smallest
        // window, at Text Size 1.0 and 1.3, every layout's dial is at least min(0.40 H, its width cap) with the
        // sample (locked and marked) and live; a dial under it fails.
        var ownerFailures: [String] = []
        for (w, h) in [(CGFloat(420), CGFloat(840)), (LayoutPlan.macMinWidth, LayoutPlan.macMinHeight)] {
            for (state, both) in [("sample", true), ("live", false)] {
                for k in [CGFloat(1), 1.3] {
                    for layout in Layout.allCases {
                        let p = LayoutPlan.plan(w: w, h: h, s: h, layout: layout, k: k, hasSpot: both, locked: both, mac: true)
                        if p.dial < p.ownerFloor(h: h) - 0.5 {
                            ownerFailures.append("\(Int(w)) × \(Int(h)) \(state) \(layout.rawValue) k\(k): dial \(Int(p.dial)) = \(Int((100 * p.dial / h).rounded()))% of H")
                        }
                    }
                }
            }
        }
        check(ownerFailures.isEmpty, "Owner's rule: dial ≥ 40% of H (\(ownerFailures.isEmpty ? "every layout, sample and live, Text Size 1.0 and 1.3" : ownerFailures.prefix(3).joined(separator: "; ")))")
        for (w, h) in [(CGFloat(420), CGFloat(840)), (LayoutPlan.macMinWidth, LayoutPlan.macMinHeight)] {
            for line in LayoutPlan.summary(w: w, h: h, s: h, hasSpot: true, locked: true, mac: true) {
                lines.append("INFO \(Int(w)) × \(Int(h)), sample: \(line)")
            }
            for line in LayoutPlan.summary(w: w, h: h, s: h, hasSpot: false, locked: false, mac: true) {
                lines.append("INFO \(Int(w)) × \(Int(h)), live: \(line)")
            }
        }
        // No "…" anywhere: the tiles' and the location card's strings, and what the tiles and the card must
        // hold measured in the system font on every device, at Text Size 1.0 and 1.3.
        if let rise = Sky.sunTimes(at: Navigator.sampleTime, lat: 39.09898, lon: -106.94117).sunriseDate,
           let set = Sky.sunTimes(at: Navigator.sampleTime, lat: 39.09898, lon: -106.94117).sunsetDate {
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
        for (w, h) in [(CGFloat(420), CGFloat(840)), (LayoutPlan.macMinWidth, LayoutPlan.macMinHeight)] {
            let drawn = MainView.drawingFailures(nav: drawNav, width: w, height: h)
            check(drawn.failures.isEmpty, "Window drawn as planned at \(Int(w)) × \(Int(h)) (\(drawn.failures.isEmpty ? "location bar at the top and 40 high as planned, grids as planned and distinct, bottom as planned" : drawn.failures.prefix(3).joined(separator: "; ")))")
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

        nav.showSample(lock: 240)
        try? await Task.sleep(for: .milliseconds(300))
        check(nav.spotText != nil && nav.sunTimes?.sunrise != nil, "Sample has a marked spot and the sun's day (\(nav.spotText ?? "no spot"))")
        // The main drawings are Medium (or `--layout`), shown without saving; the setting is put back after.
        let chosen = nav.layout
        nav.showLayout(argument(after: "--layout") ?? Layout.default.rawValue)
        check(render(screen(nav, width: 420, height: 840), to: folder.appendingPathComponent("mac-main.png")),
              "Drew the screen (mac-main.png)")
        let night = nav.nightMode
        nav.nightMode = true
        check(render(screen(nav, width: 420, height: 840), to: folder.appendingPathComponent("mac-night.png")),
              "Drew night mode (mac-night.png)")
        nav.nightMode = night
        // No compass (as on every Mac): "No heading", the rose at 40% and the note.
        nav.showSample(noCompass: true)
        check(nav.noCompass && nav.heading == nil, "Sample without a compass has no heading")
        check(render(screen(nav, width: 420, height: 840), to: folder.appendingPathComponent("mac-nocompass.png")),
              "Drew the no-compass state (mac-nocompass.png)")
        // Live: nothing locked or marked (C3.4 #14), on a navigator of its own so the sample's spot stays.
        drawNav.showSample()
        drawNav.clearSpot()
        drawNav.showLayout(nav.layout.rawValue)
        check(render(screen(drawNav, width: 420, height: 840), to: folder.appendingPathComponent("mac-live.png")),
              "Drew the live state (mac-live.png)")
        nav.showSample(lock: 240)
        // Each other layout at the default window, and Extra Large at the smallest.
        for (layout, width, height, name) in layoutShots {
            nav.showLayout(layout.rawValue)
            let plan = LayoutPlan.plan(w: width, h: height, s: height, layout: layout, hasSpot: true, locked: true, mac: true)
            check(render(screen(nav, width: width, height: height), to: folder.appendingPathComponent(name)),
                  "Drew \(layout.name) at \(Int(width)) × \(Int(height)) (\(name), dial \(Int(plan.dial.rounded())) pt, \(Int((plan.share * 100).rounded()))%, \(plan.list ? "list" : "\(Int(plan.bottomSpare.rounded())) pt spare"))")
        }
        nav.showLayout(chosen.rawValue)

        // The widgets, drawn from the sample (marked spot 9.2 mi at 46° NE, lock 240°) with the sun and moon
        // for its time; again with no spot or lock (those rows and marks drop out); and before any fix.
        var snapshot = WidgetSnapshot.sample
        snapshot.time = Navigator.sampleTime
        let entries = WidgetTimeline.entries(snapshot: snapshot, start: Navigator.sampleTime)
        let span = entries.last.map { $0.date.timeIntervalSince(Navigator.sampleTime) } ?? 0
        check(entries.count == 9 && span == 2 * 3600, "Widget timeline: every 15 minutes for 2 hours")
        let readings = WidgetReadings(snapshot: snapshot, date: Navigator.sampleTime)
        check(readings.spotText == "9.2 mi · 46° NE" && readings.lockText == "240°",
              "Widget dial marks: spot \(readings.spotText ?? "none"), lock \(readings.lockText ?? "none")")
        check(WidgetDial.Density.of(212) == .full && WidgetDial.Density.of(180) == .full && WidgetDial.Density.of(124) == .medium
              && WidgetDial.Density.of(120) == .medium && WidgetDial.Density.of(80) == .small && WidgetDial.tickStep(212) == 2 && WidgetDial.tickStep(120) == 10,
              "Widget dial tick density (2° from 180 pt, 10° below)")
        check(WidgetDial.inUpperHalf(46) && WidgetDial.inUpperHalf(270) && !WidgetDial.inUpperHalf(144) && !WidgetDial.inUpperHalf(258),
              "Half dial keeps W → N → E; the sun at 144° and the moon at 258° become edge arrows")
        var plain = snapshot
        plain.spotLatitude = nil
        plain.spotLongitude = nil
        plain.lockBearing = nil
        let plainEntry = BearingsEntry(date: Navigator.sampleTime, snapshot: plain)
        let empty = BearingsEntry(date: Date(), snapshot: nil)
        for (family, size, name) in widgetSizes {
            check(render(widget(entries[0], family, size), to: folder.appendingPathComponent("widget-\(name).png")), "\(name) widget draws")
            check(render(widget(plainEntry, family, size), to: folder.appendingPathComponent("widget-\(name)-nospot.png")), "\(name) widget draws without a spot or lock")
            check(render(widget(empty, family, size), to: folder.appendingPathComponent("widget-\(name)-empty.png")), "\(name) widget draws before a fix")
        }

        let checks = lines.filter { !$0.hasPrefix("INFO") }.count
        let head = failed == 0 ? "ALL PASSED (\(checks) checks)" : "FAILED \(failed) of \(checks) checks"
        try? ([head] + lines).joined(separator: "\n").appending("\n").write(to: folder.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
        print(head)
        NSApp.terminate(nil)
    }

    /// The layouts drawn besides Medium (docs/REFINE.md §3.4), Extra Large at the smallest window, and two
    /// panes (a wide window, as iPad landscape) in Medium and Large.
    static let layoutShots: [(Layout, CGFloat, CGFloat, String)] = [
        (.small, 420, 840, "mac-layout-small.png"),
        (.large, 420, 840, "mac-layout-large.png"),
        (.extraLarge, 420, 840, "mac-layout-extraLarge.png"),
        (.extraLarge, LayoutPlan.macMinWidth, LayoutPlan.macMinHeight, "mac-layout-extraLarge-min.png"),
        (.medium, 1200, 800, "mac-wide-medium.png"),
        (.large, 1200, 800, "mac-wide-large.png"),
    ]

    /// The main screen at a window size, drawn without ScrollViews or menus (ImageRenderer can't draw them).
    static func screen(_ nav: Navigator, width: CGFloat, height: CGFloat) -> some View {
        MainView()
            .environmentObject(nav)
            .environment(\.flatDetails, true)
            .frame(width: width, height: height)
    }

    static let widgetSizes: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 170, height: 170), "small"),
        (.systemMedium, CGSize(width: 364, height: 170), "medium"),
        (.systemLarge, CGSize(width: 364, height: 382), "large"),
    ]

    /// A widget as the desktop shows it: on the widget background, rounded. The widget has no system
    /// content margins (contentMarginsDisabled); its views keep their own 8 pt inset.
    static func widget(_ entry: BearingsEntry, _ family: WidgetFamily, _ size: CGSize) -> some View {
        WidgetView(entry: entry, family: family)
            .frame(width: size.width, height: size.height)
            .background(WidgetBackground())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    /// Renders at 2x, saves the PNG, and says whether it has real content (more than a few colours), so a
    /// blank drawing fails.
    static func render<V: View>(_ view: V, to url: URL) -> Bool {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 2
        guard let cg = renderer.cgImage else { return false }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let png = rep.representation(using: .png, properties: [:]), (try? png.write(to: url)) != nil else { return false }
        var colours = Set<UInt32>()
        for y in stride(from: 0, to: rep.pixelsHigh, by: max(1, rep.pixelsHigh / 24)) {
            for x in stride(from: 0, to: rep.pixelsWide, by: max(1, rep.pixelsWide / 24)) {
                guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                colours.insert(UInt32(c.redComponent * 255) << 16 | UInt32(c.greenComponent * 255) << 8 | UInt32(c.blueComponent * 255))
            }
        }
        return colours.count > 3
    }
}
