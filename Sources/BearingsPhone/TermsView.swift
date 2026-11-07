import SwiftUI

/// Terms of Use and Privacy on iPhone and iPad: asked once, and again when `Brand.termsVersion` changes,
/// at most once a month (TermsSchedule). An iPhone app can't quit, so there's no Quit: the screen stays
/// until the person agrees. Agreeing then asks iOS for location, which Bearings needs to show where you are.
/// Laid out as docs/REFINE.md §4.1: top-aligned 48 under the safe area in a column of at most 480, the app
/// mark (80) and title (28 bold) centred, three short rows instead of a paragraph, the legal sentence with
/// the terms as a link, and the buttons pinned 16 above the home indicator.
struct TermsView: View {
    let agree: () -> Void

    private struct Row: Hashable {
        let symbol: String
        let text: String
    }

    /// The three rows: symbol and text.
    private static let rows: [Row] = [
        Row(symbol: "exclamationmark.triangle", text: "Not a navigation instrument"),
        Row(symbol: "location", text: "Your location stays on this device"),
        Row(symbol: "map", text: "Map from Apple Maps"),
    ]

    /// "By choosing I Agree and using Bearings, you agree to the Terms of Use and Privacy at
    /// bradcowdrey.com/legal.", the address a link.
    private var legal: AttributedString {
        var text = AttributedString("By choosing I Agree and using \(Brand.appName), you agree to the Terms of Use and Privacy at ")
        // A word joiner keeps "bradcowdrey.com/legal" from breaking after the slash.
        var link = AttributedString("bradcowdrey.com/\u{2060}legal")
        link.link = Brand.legal
        link.foregroundColor = Palette.cream
        text.append(link)
        text.append(AttributedString("."))
        return text
    }

    var body: some View {
        // The text follows Text Size and scrolls when it no longer fits; the buttons stay pinned below it.
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(spacing: 16) {
                    AppMark(size: 80)
                    Text("Terms of Use and Privacy")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Self.rows, id: \.self) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Image(systemName: row.symbol)
                                .font(.system(size: 17, weight: .medium))
                                .frame(width: 24)
                                .accessibilityHidden(true)
                            Text(row.text)
                                .font(.system(size: 17))
                                // 17 pt at 1.35 line height.
                                .lineSpacing(17 * 0.35 - 3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Text(legal)
                    .font(.system(size: 15))
                    // #E0D8D0 on #1A1816: well above 4.5:1.
                    .foregroundStyle(Palette.textSecondary)
                    .tint(Palette.cream)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Next, \(Brand.appName) asks for your location.")
                    .font(.system(size: 15))
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 24)
            .frame(maxWidth: 480, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 12) {
                Link(destination: Brand.legal) {
                    Text("Read the Terms")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .foregroundStyle(.white)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
                        .contentShape(Capsule())
                }
                Button(action: agree) {
                    Text("I Agree")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(Palette.bg)
                        .background(Capsule().fill(Palette.cream))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 16)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            // So the text doesn't show through behind the buttons, or below them by the Home indicator, as it scrolls.
            .background(Palette.bg.ignoresSafeArea(edges: .bottom))
        }
        .foregroundStyle(.white)
        .background(Palette.bg.ignoresSafeArea())
    }
}
