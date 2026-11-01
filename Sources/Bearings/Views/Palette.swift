import SwiftUI

/// bradcowdrey.com colours: warm near-black, cream, crimson. One dark look, like Two Degrees and Meridian.
enum Palette {
    static let bg = Color(red: 0x1A / 255, green: 0x18 / 255, blue: 0x16 / 255)
    static let tile = Color(red: 0x23 / 255, green: 0x20 / 255, blue: 0x1D / 255)
    static let dial = Color(red: 0x20 / 255, green: 0x1D / 255, blue: 0x1A / 255)
    static let border = Color(red: 0x3A / 255, green: 0x35 / 255, blue: 0x30 / 255)
    static let cream = Color(red: 0xFF / 255, green: 0xF1 / 255, blue: 0xE5 / 255)
    static let textSecondary = Color(red: 0xE0 / 255, green: 0xD8 / 255, blue: 0xD0 / 255)
    static let textMuted = Color(red: 0xB0 / 255, green: 0xA8 / 255, blue: 0x98 / 255)
    static let textFaint = Color(red: 0x9A / 255, green: 0x92 / 255, blue: 0x86 / 255)
    static let tickMinor = Color(red: 0x5A / 255, green: 0x53 / 255, blue: 0x4B / 255)
    static let crimson = Color(red: 0x99 / 255, green: 0x0F / 255, blue: 0x3D / 255)
    static let accent = Color(red: 0xE0 / 255, green: 0x4A / 255, blue: 0x7A / 255)
    static let level = Color(red: 0x8F / 255, green: 0xC8 / 255, blue: 0x9A / 255)
    static let warn = Color(red: 0xF2 / 255, green: 0xA6 / 255, blue: 0x5A / 255)
}

/// The app's mark: a compass needle, crimson to the north.
struct AppMark: View {
    var size: CGFloat = 28

    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 64
            ctx.fill(Path(roundedRect: CGRect(origin: .zero, size: s), cornerRadius: 15 * k), with: .color(Palette.tile))
            ctx.stroke(Path(ellipseIn: CGRect(x: 11 * k, y: 11 * k, width: 42 * k, height: 42 * k)), with: .color(Palette.border), lineWidth: 2.5 * k)
            var north = Path(); north.move(to: CGPoint(x: 32 * k, y: 9 * k)); north.addLine(to: CGPoint(x: 39 * k, y: 32 * k)); north.addLine(to: CGPoint(x: 25 * k, y: 32 * k)); north.closeSubpath()
            var south = Path(); south.move(to: CGPoint(x: 32 * k, y: 55 * k)); south.addLine(to: CGPoint(x: 25 * k, y: 32 * k)); south.addLine(to: CGPoint(x: 39 * k, y: 32 * k)); south.closeSubpath()
            ctx.fill(north, with: .color(Palette.accent))
            ctx.fill(south, with: .color(Palette.cream))
            ctx.fill(Path(ellipseIn: CGRect(x: 28.8 * k, y: 28.8 * k, width: 6.4 * k, height: 6.4 * k)), with: .color(Palette.bg))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
