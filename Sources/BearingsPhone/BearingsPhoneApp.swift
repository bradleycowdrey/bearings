import SwiftUI
import UIKit

/// Bearings for iPhone and iPad: the same one screen as the Mac, with the live compass and level.
/// Launch arguments for CI: `--selftest` (checks, report in Documents), `--sample` (the sample place),
/// `--format <id>`, `--show-terms`.
@main
struct BearingsPhoneApp: App {
    @StateObject private var nav = Navigator.shared
    @Environment(\.scenePhase) private var phase
    @State private var askTerms = PhoneLaunch.showTerms || (!PhoneLaunch.selfTest && !PhoneLaunch.sample && TermsSchedule.shouldAsk(in: .standard))

    var body: some Scene {
        WindowGroup {
            Group {
                if askTerms {
                    TermsView {
                        TermsSchedule.agree(in: .standard)
                        askTerms = false
                        nav.start()
                    }
                } else {
                    MainView()
                        .environmentObject(nav)
                }
            }
            .preferredColorScheme(.dark)
            .task { await launch() }
            .onChange(of: phase) {
                guard !askTerms, !nav.sample else { return }
                if phase == .active { nav.start() } else if phase == .background { nav.stop() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                nav.updateHeadingOrientation()
            }
        }
    }

    @MainActor
    private func launch() async {
        if let id = PhoneLaunch.value(after: "--format"), let format = Geo.Format(rawValue: id) { nav.format = format }
        if PhoneLaunch.sample { SharedStore.enabled = false; nav.showSample(lock: 240); return }
        if PhoneLaunch.selfTest { await PhoneSelfTest.run(nav: nav); return }
        if !askTerms { nav.start() }
    }
}

enum PhoneLaunch {
    static let args = ProcessInfo.processInfo.arguments
    static let selfTest = args.contains("--selftest")
    static let sample = args.contains("--sample")
    static let showTerms = args.contains("--show-terms")
    static func value(after flag: String) -> String? {
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

extension Navigator {
    /// One for the whole app.
    static let shared = Navigator()
}
