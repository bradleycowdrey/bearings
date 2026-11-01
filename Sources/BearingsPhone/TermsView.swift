import SwiftUI

/// Terms of Use and Privacy on iPhone and iPad: asked once, and again when `Brand.termsVersion` changes,
/// at most once a month (TermsSchedule). An iPhone app can't quit, so there's no Quit: the screen stays
/// until the person agrees. Agreeing then asks iOS for location, which Bearings needs to show where you are.
struct TermsView: View {
    let agree: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            AppMark(size: 56)
            Text("Terms of Use and Privacy")
                .font(.system(size: 28, weight: .semibold))
                .tracking(-0.4)
            Text(Brand.termsSummary)
                .font(.system(size: 16))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("By choosing I Agree and using \(Brand.appName), you agree to the Terms of Use and Privacy at bradcowdrey.com/legal.")
                .font(.system(size: 14))
                .foregroundStyle(Palette.textMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: agree) {
                Text("I Agree")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(Palette.bg)
                    .background(Capsule().fill(Palette.cream))
            }
            .buttonStyle(.plain)
            Link(destination: Brand.legal) {
                Text("Read the Terms")
                    .font(.system(size: 17, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(.white)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(Palette.bg.ignoresSafeArea())
    }
}
