import SwiftUI

/// Terms of Use and Privacy on iPhone and iPad: asked once, and again when `Brand.termsVersion` changes,
/// at most once a month (TermsSchedule). An iPhone app can't quit, so there's no Quit: the screen stays
/// until the person agrees. Agreeing then asks iOS for location, which Bearings needs to show where you are.
struct TermsView: View {
    let agree: () -> Void

    var body: some View {
        // The text follows Text Size and scrolls when it no longer fits; the buttons stay pinned below it.
        // At least a screen tall, so at the usual sizes the text sits where it always has and nothing scrolls.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 24)
                    AppMark(size: 56)
                    Text("Terms of Use and Privacy")
                        .font(.title.weight(.semibold))
                        .tracking(-0.4)
                    Text(Brand.termsSummary)
                        .font(.body)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // A word joiner keeps "bradcowdrey.com/legal" from breaking after the slash.
                    Text("By choosing I Agree and using \(Brand.appName), you agree to the Terms of Use and Privacy at bradcowdrey.com/\u{2060}legal.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity)
                .frame(minHeight: geo.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 18) {
                Button(action: agree) {
                    Text("I Agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(Palette.bg)
                        .background(Capsule().fill(Palette.cream))
                }
                .buttonStyle(.plain)
                Link(destination: Brand.legal) {
                    Text("Read the Terms")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            // So the text doesn't show through behind the buttons, or below them by the Home indicator, as it scrolls.
            .background(Palette.bg.ignoresSafeArea(edges: .bottom))
        }
        .foregroundStyle(.white)
        .background(Palette.bg.ignoresSafeArea())
    }
}
