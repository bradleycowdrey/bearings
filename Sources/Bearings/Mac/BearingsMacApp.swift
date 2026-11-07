import AppKit
import CoreServices
import SwiftUI
import WidgetKit

/// Bearings for Mac: the same one screen as on iPhone. Macs have no compass, so the dial rests at
/// north with a note; coordinates, elevation and the map work as on a phone.
/// `--selftest <folder>` runs the checks CI uses (SelfTest) and quits; `--layout <id>` shows a layout
/// without saving it; `--map-sheet` opens the map sheet.
@main
struct BearingsMacApp: App {
    @StateObject private var nav = Navigator.shared
    @StateObject private var updater = Updater.shared

    var body: some Scene {
        // The window's title is "Bearings" (the title bar is hidden; the screen's header bar shows the place).
        WindowGroup(Brand.appName) {
            MainView(update: updater.available.map { (version: $0.version, url: $0.url) })
                .environmentObject(nav)
                .frame(minWidth: 380, idealWidth: 420, minHeight: 720, idealHeight: 840)
                .task { await launch() }
        }
        // The screen's header bar takes the title's place; the content stays in the safe area below the
        // window's buttons.
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 420, height: 840)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .pasteboard) {
                Button("Copy Coordinates") {
                    guard let text = nav.copyText else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(nav.fix == nil)
            }
            CommandMenu("Coordinates") {
                Picker("Format", selection: $nav.format) {
                    ForEach(Geo.Format.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.inline)
                Divider()
                Button(nav.spot == nil ? "Mark This Spot" : "Clear Marked Spot") {
                    if nav.spot == nil { nav.markSpot() } else { nav.clearSpot() }
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(nav.fix == nil && nav.spot == nil)
            }
            CommandGroup(after: .toolbar) {
                // View › Layout: how large the compass is (docs/LAYOUTS.md §6).
                Menu("Layout") {
                    Picker("Layout", selection: $nav.layout) {
                        ForEach(Layout.allCases) { layout in
                            Label {
                                Text(layout.name)
                                Text(layout.subtitle)
                            } icon: {
                                Image(systemName: layout.symbol)
                            }
                            .tag(layout)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Divider()
                    Button("Larger Compass") { nav.stepLayout(larger: true) }
                        .keyboardShortcut("=", modifiers: .command)
                        .disabled(nav.layout.larger == nil)
                    Button("Smaller Compass") { nav.stepLayout(larger: false) }
                        .keyboardShortcut("-", modifiers: .command)
                        .disabled(nav.layout.smaller == nil)
                    Button("Medium") { nav.layout = .medium }
                        .keyboardShortcut("0", modifiers: .command)
                }
                Toggle("Night Mode", isOn: $nav.nightMode)
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Toggle("Satellite Map", isOn: $nav.satellite)
            }
            CommandGroup(replacing: .help) {
                Link("Bearings on GitHub", destination: Brand.repository)
                Link("Report an Issue", destination: Brand.issues)
                Link("Terms of Use and Privacy", destination: Brand.legal)
            }
        }
    }

    @MainActor
    private func launch() async {
        // `--layout small|medium|large|extraLarge`: shown, not saved (also with --selftest).
        if let id = SelfTest.argument(after: "--layout") { nav.showLayout(id) }
        if let folder = SelfTest.folder {
            await SelfTest.run(nav: nav, folder: folder)
            return
        }
        if CommandLine.arguments.contains("--sample") {
            SharedStore.enabled = false
            nav.showSample(lock: 240)
            if CommandLine.arguments.contains("--map-sheet") { nav.mapSheet = true }
            return
        }
        // Make sure LaunchServices has this exact build registered: macOS checks the widget's version
        // against it and throws the widget's content away on a mismatch (an app replaced in place by an
        // update keeps the old record). Then redraw the widgets, so they show this version right away.
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
        WidgetCenter.shared.reloadAllTimelines()
        Terms.askIfNeeded()
        nav.start()
        if CommandLine.arguments.contains("--map-sheet") { nav.mapSheet = true }
        await updater.check()
    }
}

extension Navigator {
    /// One for the whole app.
    static let shared = Navigator()
}
