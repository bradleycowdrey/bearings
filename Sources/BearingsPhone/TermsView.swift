import SwiftUI

/// Terms of Use and Privacy on iPhone and iPad: asked once, and again when `Brand.termsVersion` changes,
/// at most once a month (TermsSchedule). An iPhone app can't quit, so there's no Quit: the screen stays
/// until the person agrees. Agreeing then asks iOS for location, which Bearings needs to show where you are.
/// Laid out as docs/REFINE.md §4.1 and C2.3 #20: the content block centred in the space above the buttons
/// (never closer than 48 to the safe area's top) in a column of at most 480, the app mark (80) and title
/// (28 bold) centred, three short rows instead of a paragraph, the legal sentence with the terms as an
/// underlined link in a 44 pt target, and the buttons pinned 16 above the home indicator on iPhone, or
/// grouped 32 under the text on iPad. C3.4 #18: "Next, Bearings asks for your location." no longer floats
/// alone in the text; it heads the buttons at 13 pt secondary, 24 above them (the buttons 12 apart).
struct TermsView: View {
    let agree: () -> Void
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// iPad: the buttons sit 32 under the text instead of pinned to the bottom.
    private var grouped: Bool { sizeClass == .regular }

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

    var body: some View {
        // The text follows Text Size and scrolls when it no longer fits; on iPhone the buttons stay pinned below it.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    content
                    if grouped { buttons }
                }
                .padding(.horizontal, 24)
                .padding(.top, 48)
                .padding(.bottom, 24)
                .frame(maxWidth: 480, alignment: .leading)
                // Centred in the space above the buttons (the padding keeps it 48 or more from the top).
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaInset(edge: .bottom) {
            if !grouped {
                buttons
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    // So the text doesn't show through behind the buttons, or below them by the Home indicator, as it scrolls.
                    .background(Palette.bg.ignoresSafeArea(edges: .bottom))
            }
        }
        .foregroundStyle(.white)
        .background(Palette.bg.ignoresSafeArea())
    }

    private var content: some View {
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
            VStack(alignment: .leading, spacing: 0) {
                Text("By choosing I Agree and using \(Brand.appName), you agree to the Terms of Use and Privacy at")
                    .font(.system(size: 15))
                    // #E0D8D0 on #1A1816: well above 4.5:1.
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                // The address as an underlined accent link, 44 high to tap.
                Link(destination: Brand.legal) {
                    Text("bradcowdrey.com/legal")
                        .font(.system(size: 15, weight: .medium))
                        .underline()
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityHint("Opens the terms")
            }
        }
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Text("Next, \(Brand.appName) asks for your location.")
                .font(.system(size: 13))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                // 24 above the buttons (12 here and the stack's 12).
                .padding(.bottom, 12)
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
    }
}
