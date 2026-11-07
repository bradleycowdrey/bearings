import SwiftUI

/// bradcowdrey.com colours (warm near-black, cream, crimson) and the Two Degrees look the app wears inside
/// (docs/LOOK.md): black, white type in steps of opacity, sky cards and frosted tiles. The warm colours stay
/// on the widgets, the Terms screen and the app mark; inside the app the highlights are white, and pink means
/// north and nothing else. Shared with the widget extensions, so this file needs only SwiftUI and Core/Sky.swift.
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

    // MARK: The Two Degrees look (docs/LOOK.md)

    /// A colour from 0xRRGGBB.
    static func rgb(_ hex: UInt32) -> Color {
        Color(.sRGB,
              red: Double((hex >> 16) & 0xFF) / 255,
              green: Double((hex >> 8) & 0xFF) / 255,
              blue: Double(hex & 0xFF) / 255,
              opacity: 1)
    }

    /// The main screen's background: pure black, as Two Degrees' and Meridian's lists.
    static let screen = Color.black
    /// A frosted tile on black: white at 8% (#141414 on black). Flat rather than a material, so it draws the
    /// same in ImageRenderer (the self-tests) and on Android.
    static let tileFill = Color.white.opacity(Op.tile)
    /// The tile's 1 pt edge: white at 12%.
    static let tileStroke = Color.white.opacity(Op.stroke)
    /// A choice that is off, or a quiet round button: white at 12%.
    static let chipOff = Color.white.opacity(Op.fill)
    /// North on the dial and on the widget's rose, as on the app icon: the one place pink stays inside the app.
    static let north = accent
    /// Warnings ("Magnet or metal nearby") and the Sample badge: Two Degrees' notice amber (the same as `warn`).
    static let notice = warn
    /// Switches (white on white would hide the knob), as in Two Degrees and Meridian.
    static let switchOn = rgb(0x30D158)
    /// A sky card before there is a location to work out the sun for (Two Degrees' card with no forecast).
    static let skyUnknown = rgb(0x262626)
    /// The dividers inside a widget (Two Degrees' borderStrong; the same as `border`).
    static let widgetRule = border

    /// White on black, in steps (Meridian's ladder). Use as `Color.white.opacity(Palette.Op.caption)`.
    enum Op {
        /// The heading's point ("SW") and secondary values beside a reading.
        static let strong = 0.9
        static let body = 0.85
        static let label = 0.8
        /// Second lines on a sky card, and values beside the main one.
        static let sub = 0.7
        /// Captions, details, the subline, the dial's numbers.
        static let caption = 0.6
        /// Intercardinal points on the dial.
        static let points = 0.45
        /// Dots between parts of a line, disabled text.
        static let faint = 0.35
        /// The dial's 2° ticks.
        static let minor = 0.3
        static let track = 0.15
        static let stroke = 0.12
        static let fill = 0.12
        static let tile = 0.08
        static let rowFill = 0.07
    }
}

/// Sizes shared by every screen (DESIGN.md's grid, in Two Degrees' shapes). Points on Apple, dp on Android.
enum Look {
    /// Tiles, sky cards, the map and the dial's surroundings: Two Degrees' 16 with continuous corners.
    static let radius: CGFloat = 16
    /// Inside a tile: 14 across, 12 down (DESIGN.md's tile padding).
    static let padding: CGFloat = 14
    static let paddingV: CGFloat = 12
    /// Inside a sky card: 14 all round (12 on screens under 700 high).
    static let skyPadding: CGFloat = 14
    /// Screen margins.
    static let margin: CGFloat = 16
    /// Between blocks.
    static let gap: CGFloat = 12
    /// Between tiles.
    static let tileGap: CGFloat = 8
    /// The large "Bearings" title: 34 bold, in a row 48 high with the ⋯ menu.
    static let titleSize: CGFloat = 34
    static let titleRow: CGFloat = 48
    /// A tile's caption: 12 semibold, uppercase, white at 60%, with its symbol.
    static let captionSize: CGFloat = 12
    /// A tile's value: 20 medium.
    static let valueSize: CGFloat = 20
    /// The 1 pt edge of tiles, the map and the dial.
    static let stroke: CGFloat = 1
    /// Screens shorter than this drop the title row; the ⋯ menu moves into the sky card.
    static let compactHeight: CGFloat = 700
}

/// The sky behind the place card, as in Two Degrees, following the sun's real altitude where you are: deep
/// navy at night, Two Degrees' steel blue around sunrise and sunset, its clear-day blue once the sun is well
/// up. Colours are interpolated between these stops (degrees of altitude), top and bottom of the gradient:
///   -12° and below: night    #141E3C → #0A0E1C
///   -2° to 8°:      twilight #4F78A3 → #24384F
///   15° and above:  day      #3D74B0 → #1C3A5E
/// With no location yet, a flat #262626.
enum SkyTone {
    private static let stops: [(altitude: Double, top: UInt32, bottom: UInt32)] = [
        (-12, 0x141E3C, 0x0A0E1C),
        (-2, 0x4F78A3, 0x24384F),
        (8, 0x4F78A3, 0x24384F),
        (15, 0x3D74B0, 0x1C3A5E),
    ]

    /// Top and bottom of the sky for the sun's altitude in degrees (nil: no location yet).
    static func colors(altitude: Double?) -> (top: Color, bottom: Color) {
        guard let altitude else { return (Palette.skyUnknown, Palette.skyUnknown) }
        let first = stops[0], last = stops[stops.count - 1]
        if altitude <= first.altitude { return (Palette.rgb(first.top), Palette.rgb(first.bottom)) }
        if altitude >= last.altitude { return (Palette.rgb(last.top), Palette.rgb(last.bottom)) }
        for i in 1..<stops.count where altitude <= stops[i].altitude {
            let a = stops[i - 1], b = stops[i]
            let t = (altitude - a.altitude) / (b.altitude - a.altitude)
            return (mix(a.top, b.top, t), mix(a.bottom, b.bottom, t))
        }
        return (Palette.rgb(last.top), Palette.rgb(last.bottom))
    }

    /// The card's background: the two colours, top to bottom.
    static func gradient(altitude: Double?) -> LinearGradient {
        let sky = colors(altitude: altitude)
        return LinearGradient(colors: [sky.top, sky.bottom], startPoint: .top, endPoint: .bottom)
    }

    /// The SF Symbol in the card's corner, as Two Degrees shows the weather's: the sun when it's 8° or more
    /// up, sunrise or sunset within twilight (morning while the sun is in the east), the moon and stars
    /// below -6°, a location arrow before there is a fix. Decorative (hidden from VoiceOver).
    static func symbol(for sun: Sky.Position?) -> String {
        guard let sun else { return "location" }
        if sun.altitude >= 8 { return "sun.max.fill" }
        if sun.altitude >= -6 { return sun.azimuth < 180 ? "sunrise.fill" : "sunset.fill" }
        return "moon.stars.fill"
    }

    private static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> Color {
        func part(_ hex: UInt32, _ shift: UInt32) -> Double { Double((hex >> shift) & 0xFF) / 255 }
        func lerp(_ shift: UInt32) -> Double { part(a, shift) + (part(b, shift) - part(a, shift)) * t }
        return Color(.sRGB, red: lerp(16), green: lerp(8), blue: lerp(0), opacity: 1)
    }
}

/// A sky card's background (see SkyTone).
struct SkyBackground: View {
    let altitude: Double?

    var body: some View {
        SkyTone.gradient(altitude: altitude)
    }
}

/// A tile's caption, as in Two Degrees: a small symbol and an uppercase title, white at 60%. Pass the
/// title in its normal case ("Latitude"); it is shown in capitals and VoiceOver keeps the tile's own label.
struct CardCaption: View {
    let title: String
    let symbol: String
    var size: CGFloat = Look.captionSize

    init(_ title: String, _ symbol: String, size: CGFloat = Look.captionSize) {
        self.title = title
        self.symbol = symbol
        self.size = size
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.92, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: size, weight: .semibold))
                .tracking(0.3)
        }
        .foregroundStyle(Color.white.opacity(Palette.Op.caption))
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}

/// The app's buttons: white capsule, black text. `full` is the full-width primary button (50 high, 17
/// semibold); otherwise a compact capsule (14 semibold, 14 × 8) as on the location tile and the update banner.
struct LookButtonStyle: ButtonStyle {
    var full = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: full ? 17 : 14, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(Color.black)
            .padding(.horizontal, full ? 20 : 14)
            .padding(.vertical, full ? 0 : 8)
            .frame(maxWidth: full ? .infinity : nil, minHeight: full ? 50 : nil)
            .background(Capsule().fill(Color.white))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

extension View {
    /// A frosted tile: white at 8% with a 1 pt edge at 12%, rounded 16 (continuous).
    func frostedTile(radius: CGFloat = Look.radius) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(shape.fill(Palette.tileFill))
            .overlay(shape.strokeBorder(Palette.tileStroke, lineWidth: Look.stroke))
    }

    /// A sky card: the sky for the sun's altitude behind, clipped to 16 (continuous). White type on it.
    func skyCard(altitude: Double?, radius: CGFloat = Look.radius) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(SkyBackground(altitude: altitude))
            .clipShape(shape)
            .contentShape(shape)
    }
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
