import AppKit
import SwiftUI
import WidgetKit

/// `Bearings --selftest <folder>`: what CI checks on a real Mac. The core's known answers, a live ground
/// elevation from Open-Meteo, naming a place (the geocoder and the bundled list), the update check, the
/// screen drawn with the sample place (and in night mode), and every widget size drawn the way the
/// widget draws it. Writes report.txt (first line "ALL PASSED" or "FAILED …") and PNGs to the folder,
/// then quits.
@MainActor
enum SelfTest {
    static var folder: URL? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--selftest"), i + 1 < args.count else { return nil }
        return URL(fileURLWithPath: args[i + 1], isDirectory: true)
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

        nav.showSample(lock: 240)
        try? await Task.sleep(for: .milliseconds(300))
        check(nav.spotText != nil && nav.sunTimes?.sunrise != nil, "Sample has a marked spot and the sun's day (\(nav.spotText ?? "no spot"))")
        check(render(MainView().environmentObject(nav).frame(width: 420, height: 840), to: folder.appendingPathComponent("mac-main.png")),
              "Drew the screen (mac-main.png)")
        let night = nav.nightMode
        nav.nightMode = true
        check(render(MainView().environmentObject(nav).frame(width: 420, height: 840), to: folder.appendingPathComponent("mac-night.png")),
              "Drew night mode (mac-night.png)")
        nav.nightMode = night

        // The widgets, drawn from the sample with the sun and moon for its time, and before any fix.
        var snapshot = WidgetSnapshot.sample
        snapshot.time = Navigator.sampleTime
        let map = await MapSnapshot.make(latitude: snapshot.latitude, longitude: snapshot.longitude, size: WidgetTimeline.mapSize)
        check(map != nil, "Map picture for the large widget")
        let entries = WidgetTimeline.entries(snapshot: snapshot, map: map, start: Navigator.sampleTime)
        let span = entries.last.map { $0.date.timeIntervalSince(Navigator.sampleTime) } ?? 0
        check(entries.count == 9 && span == 2 * 3600, "Widget timeline: every 15 minutes for 2 hours")
        let empty = BearingsEntry(date: Date(), snapshot: nil)
        for (family, size, name) in widgetSizes {
            check(render(widget(entries[0], family, size), to: folder.appendingPathComponent("widget-\(name).png")), "\(name) widget draws")
            check(render(widget(empty, family, size), to: folder.appendingPathComponent("widget-\(name)-empty.png")), "\(name) widget draws before a fix")
        }

        let head = failed == 0 ? "ALL PASSED (\(lines.count) checks)" : "FAILED \(failed) of \(lines.count) checks"
        try? ([head] + lines).joined(separator: "\n").appending("\n").write(to: folder.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
        print(head)
        NSApp.terminate(nil)
    }

    static let widgetSizes: [(WidgetFamily, CGSize, String)] = [
        (.systemSmall, CGSize(width: 170, height: 170), "small"),
        (.systemMedium, CGSize(width: 364, height: 170), "medium"),
        (.systemLarge, CGSize(width: 364, height: 382), "large"),
    ]

    /// A widget as the desktop shows it: padded, on the widget background, rounded.
    static func widget(_ entry: BearingsEntry, _ family: WidgetFamily, _ size: CGSize) -> some View {
        WidgetView(entry: entry, family: family)
            .padding(16)
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
