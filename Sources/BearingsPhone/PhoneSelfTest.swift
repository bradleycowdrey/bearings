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

        // The layout planner (docs/LAYOUTS.md): the dial never under 40% of the height in a portrait column.
        let planFailures = LayoutPlan.tableFailures()
        check(planFailures.isEmpty, "Layout planner table (\(planFailures.first ?? "all cases keep the dial at 40% or more"))")

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

        let head = failed == 0 ? "ALL PASSED (\(lines.count) checks)" : "FAILED \(failed) of \(lines.count) checks"
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
