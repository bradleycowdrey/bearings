import AppKit

/// Terms of Use and Privacy: asked once, and again when `Brand.termsVersion` changes, at most once a
/// month (TermsSchedule). Never asked during the CI self-test.
enum Terms {
    @MainActor
    static func askIfNeeded(defaults: UserDefaults = .standard) {
        guard TermsSchedule.shouldAsk(in: defaults) else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Terms of Use and Privacy"
        alert.informativeText = Brand.termsSummary + "\n\nBy choosing I Agree and using \(Brand.appName), you agree to the Terms of Use and Privacy at bradcowdrey.com/legal."
        alert.addButton(withTitle: "I Agree")
        alert.addButton(withTitle: "Read the Terms")
        alert.addButton(withTitle: "Quit")
        while true {
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                TermsSchedule.agree(in: defaults)
                return
            case .alertSecondButtonReturn:
                NSWorkspace.shared.open(Brand.legal)
            default:
                NSApp.terminate(nil)
                return
            }
        }
    }
}
