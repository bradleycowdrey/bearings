import SwiftUI
import WidgetKit

// Widget views, shared by the widget extension and the app (whose self-tests draw them). Widgets can't
// run the compass, so they show where you are and the sky: the place, the elevation in feet and metres,
// the coordinates, sunrise and sunset, the moon, and on the large one a map and the marked spot.

struct BearingsEntry: TimelineEntry {
    let date: Date
    /// The app's last fix (or the widget's own fresher one); nil before the app has found you.
    let snapshot: WidgetSnapshot?
    /// The large widget's map picture.
    var map: PlatformImage? = nil
    var isPlaceholder = false

    static func placeholder(_ date: Date = Date()) -> BearingsEntry {
        BearingsEntry(date: date, snapshot: .sample, isPlaceholder: true)
    }
}

enum WidgetTimeline {
    /// An entry every 15 minutes for two hours, each with the sun and moon for its own time.
    static func entries(snapshot: WidgetSnapshot?, map: PlatformImage?, start: Date = Date()) -> [BearingsEntry] {
        (0...8).map { i in
            BearingsEntry(date: start.addingTimeInterval(Double(i) * 15 * 60), snapshot: snapshot, map: map)
        }
    }

    /// When WidgetKit should ask again (DESIGN.md: every 30 minutes).
    static let refresh: TimeInterval = 30 * 60

    /// The large widget's map size, points.
    static let mapSize = CGSize(width: 340, height: 132)
}

/// Warm near-black with the crimson rule, as in Two Degrees; the rule steps aside in tinted and clear modes.
struct WidgetBackground: View {
    @Environment(\.widgetRenderingMode) private var mode

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bg
            if mode == .fullColor { Palette.crimson.frame(height: 3) }
        }
    }
}

/// What the entry's numbers read as, in the app's units and coordinate format.
struct WidgetReadings {
    let snapshot: WidgetSnapshot
    let date: Date

    var feet: Bool { snapshot.feet }

    var place: String { snapshot.place ?? "Where you are" }
    /// "Aspen" from "Aspen, Colorado", for the Lock Screen's one line.
    var shortPlace: String { place.components(separatedBy: ",").first ?? place }

    var elevation: (big: String, small: String)? {
        guard let m = snapshot.elevation else { return nil }
        let e = Geo.elevation(m)
        return feet ? (e.ft, e.m) : (e.m, e.ft)
    }

    /// "9.6k ft" for the circular Lock Screen widget; under 1,000 as is.
    var compactElevation: (number: String, unit: String)? {
        guard let m = snapshot.elevation else { return nil }
        let v = feet ? m / Geo.foot : m
        if abs(v) < 1000 { return (Geo.group(v), feet ? "ft" : "m") }
        return ("\(Geo.fixed(v / 1000, 1))k", feet ? "ft" : "m")
    }

    /// Two lines for latitude and longitude, or one grid reference.
    var coordinates: [String] {
        switch Geo.format(snapshot.coordinateFormat, lat: snapshot.latitude, lon: snapshot.longitude) {
        case let .pair(lat, lon): [lat, lon]
        case let .single(text): [text]
        }
    }

    /// "9:41 AM": when the fix is from.
    var asOf: String { snapshot.time.formatted(date: .omitted, time: .shortened) }

    var sun: Sky.Position { Sky.sunPosition(at: date, lat: snapshot.latitude, lon: snapshot.longitude) }
    var times: Sky.Times { Sky.sunTimes(at: date, lat: snapshot.latitude, lon: snapshot.longitude) }
    var moon: Sky.Phase { Sky.moonPhase(at: date) }

    var sunrise: String? { times.sunriseDate?.formatted(date: .omitted, time: .shortened) }
    var sunset: String? { times.sunsetDate?.formatted(date: .omitted, time: .shortened) }
    var polarText: String { times.polar == .day ? "Sun up all day" : "Sun down all day" }
    /// "53% · Last quarter": the same wording as the app's Moon tile (Look.moonText).
    var moonText: String { Look.moonText(moon) }

    /// "9.2 mi · 46° NE" to the marked spot, if there is one.
    var spotText: String? {
        guard let lat = snapshot.spotLatitude, let lon = snapshot.spotLongitude else { return nil }
        let d = Geo.distance(lat1: snapshot.latitude, lon1: snapshot.longitude, lat2: lat, lon2: lon)
        let b = Geo.bearing(lat1: snapshot.latitude, lon1: snapshot.longitude, lat2: lat, lon2: lon)
        return "\(Geo.distanceText(d, feet: feet)) · \(Int(Geo.jsRound(b)) % 360)° \(Geo.point(b))"
    }

    var spokenElevation: String {
        guard let m = snapshot.elevation else { return "Elevation unknown" }
        let ft = "\(Geo.group(m / Geo.foot)) feet", metres = "\(Geo.group(m)) metres"
        return "Elevation \(feet ? ft : metres), \(feet ? metres : ft)"
    }

    /// "9,587 ft" as ("9,587", "ft"), so the unit can be drawn smaller on the number's baseline.
    static func split(_ text: String) -> (number: String, unit: String) {
        guard let space = text.lastIndex(of: " ") else { return (text, "") }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }

    /// "6:36" and "AM" on a 12-hour clock, "06:36" and "" on a 24-hour one: the system's own short time
    /// with AM or PM taken out (as MainView.shortTime does; MainView isn't in the widget target).
    static func clock(_ date: Date) -> (time: String, period: String) {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        let full = f.string(from: date)
        var text = full, period = ""
        for symbol in [f.amSymbol, f.pmSymbol].compactMap({ $0 }) where !symbol.isEmpty && full.contains(symbol) {
            text = text.replacingOccurrences(of: symbol, with: "")
            period = symbol
        }
        return (text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{202F}\u{00A0}"))), period)
    }
}

/// The widget's colours. In full colour: white type and Two Degrees' warm greys, cream for the first
/// column's label, the sun's gold. In the tinted and clear modes (the tinted Home Screen, StandBy, a Mac
/// desktop widget in the background) the system draws everything in one colour, so the widget uses that
/// colour in steps of opacity and draws no opaque blocks.
struct WidgetInk {
    let tinted: Bool

    var primary: Color { tinted ? Color.primary : Color.white }
    var secondary: Color { tinted ? Color.primary.opacity(0.8) : Palette.textSecondary }
    var muted: Color { tinted ? Color.primary.opacity(0.6) : Palette.textMuted }
    /// The first column's label ("Sun"), as Two Degrees' "Now".
    var label: Color { tinted ? Color.primary : Palette.cream }
    var rule: Color { tinted ? Color.primary.opacity(0.3) : Palette.widgetRule }
    var sun: Color { tinted ? Color.primary : SkyMarks.sun }

    /// The sky symbol's colour: the sun's gold by day and in twilight, cream at night.
    func sky(_ symbol: String) -> Color {
        if tinted { return Color.primary }
        return symbol == "moon.stars.fill" ? Palette.cream : SkyMarks.sun
    }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let entry: BearingsEntry
    /// Set by the app's self-tests, which draw widgets outside WidgetKit (always in full colour).
    var family: WidgetFamily? = nil

    /// Tinted, accented or vibrant, or clear (StandBy): one colour, no opaque blocks (as Meridian does).
    private var ink: WidgetInk {
        WidgetInk(tinted: renderingMode != .fullColor || (!showsBackground && family == nil))
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let r = WidgetReadings(snapshot: snapshot, date: entry.date)
                switch family ?? environmentFamily {
                case .systemMedium: MediumWidget(r: r, ink: ink)
                case .systemLarge: LargeWidget(r: r, ink: ink, map: entry.map)
                #if os(iOS)
                case .accessoryInline: InlineAccessory(r: r)
                case .accessoryCircular: CircularAccessory(r: r)
                case .accessoryRectangular: RectangularAccessory(r: r)
                #endif
                default: SmallWidget(r: r, ink: ink)
                }
            } else {
                EmptyWidget(family: family ?? environmentFamily, ink: ink)
            }
        }
        .environment(\.colorScheme, .dark)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Home Screen and desktop (Two Degrees' layout)

/// The elevation as Two Degrees draws a reading: the number large, its unit smaller on the same baseline.
private struct WidgetElevation: View {
    let r: WidgetReadings
    let ink: WidgetInk
    var size: CGFloat = 36

    var body: some View {
        let parts = WidgetReadings.split(r.elevation?.big ?? "—")
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            Text(parts.number)
                .font(.system(size: size, weight: .semibold))
                .tracking(-size * 0.03)
                .foregroundStyle(ink.primary)
                .widgetAccentable()
            if !parts.unit.isEmpty {
                Text(parts.unit)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(ink.muted)
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
}

/// The sky symbol for the sun where you are: the sun, sunrise or sunset, or the moon and stars.
private struct WidgetSkySymbol: View {
    let r: WidgetReadings
    let ink: WidgetInk
    var size: CGFloat = 15

    var body: some View {
        let symbol = SkyTone.symbol(for: r.sun)
        Image(systemName: symbol)
            .font(.system(size: size, weight: .medium))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(ink.sky(symbol))
            .accessibilityHidden(true)
    }
}

/// Two Degrees' NowBlock: the place with the sky symbol, the elevation right under it, and at the foot
/// the coordinates and the time of the fix, so the space sits between the two groups.
private struct WhereBlock: View {
    let r: WidgetReadings
    let ink: WidgetInk

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Text(r.place)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    // No fixed height: when a long place and two coordinate lines leave no room, the
                    // place gives way to one line rather than pushing the block out of the widget.
                    .frame(maxWidth: .infinity, alignment: .leading)
                WidgetSkySymbol(r: r, ink: ink, size: 15)
            }
            VStack(alignment: .leading, spacing: 0) {
                WidgetElevation(r: r, ink: ink, size: 36)
                Text(r.elevation?.small ?? "Elevation unknown")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ink.muted)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(r.spokenElevation)
            Spacer(minLength: 2)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(r.coordinates, id: \.self) { line in
                    Text(line)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ink.secondary)
                }
                Text(r.asOf)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ink.muted)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        // Hug the leading edge: without this the column shrinks to its text and centres in the widget.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// The small rose with the sun's direction; in the tinted modes a plain outline in the system's colour.
private struct RoseMark: View {
    let sun: Sky.Position
    let ink: WidgetInk
    var size: CGFloat = 34

    var body: some View {
        if ink.tinted {
            let a = sun.azimuth * Double.pi / 180
            ZStack {
                Circle().stroke(Color.primary.opacity(0.5), lineWidth: 1)
                Text("N")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .offset(y: -size * 0.27)
                Circle()
                    .fill(Color.primary)
                    .frame(width: size * 0.2, height: size * 0.2)
                    .opacity(sun.altitude > 0 ? 1 : 0.4)
                    .offset(x: CGFloat(sin(a)) * size * 0.3, y: CGFloat(-cos(a)) * size * 0.3)
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else {
            SunRose(sun: sun, size: size)
        }
    }
}

/// The moon for its phase; in the tinted modes the plain moon symbol (the glyph's dark disc would fill solid).
private struct MoonMark: View {
    let phase: Double
    let ink: WidgetInk
    var size: CGFloat = 12

    var body: some View {
        if ink.tinted {
            Image(systemName: "moon.fill")
                .font(.system(size: size * 0.9, weight: .medium))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            MoonGlyph(phase: phase, size: size)
        }
    }
}

/// Two Degrees' hours row, for the sun: three columns of equal width (the sun's direction with the rose,
/// sunrise, sunset). In polar day or night, sunrise and sunset become one wide column.
private struct SunRow: View {
    let r: WidgetReadings
    let ink: WidgetInk

    /// The row's height in polar day or night, when the wide column needs a fixed frame.
    private static let height: CGFloat = 86

    var body: some View {
        if let rise = r.times.sunriseDate, let down = r.times.sunsetDate {
            HStack(alignment: .top, spacing: 0) {
                sunColumn
                // Read together, as before: "Sunrise 6:36 AM, sunset 6:02 PM" (the sunset column is
                // folded into the sunrise column's label, so the columns keep their equal widths).
                timeColumn("Sunrise", symbol: "sunrise.fill", date: rise)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sunrise \(r.sunrise ?? ""), sunset \(r.sunset ?? "")")
                timeColumn("Sunset", symbol: "sunset.fill", date: down)
                    .accessibilityHidden(true)
            }
        } else {
            GeometryReader { proxy in
                let third = proxy.size.width / 3
                HStack(alignment: .top, spacing: 0) {
                    sunColumn.frame(width: third)
                    // No label of its own (a blank keeps the line level with the Sun column's).
                    column(" ", value: r.polarText, sub: "") {
                        Image(systemName: r.times.polar == .day ? "sun.max.fill" : "moon.stars.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(r.times.polar == .day ? ink.sun : ink.sky("moon.stars.fill"))
                    }
                    .frame(width: third * 2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(r.polarText)
                }
            }
            .frame(height: Self.height)
        }
    }

    private var sunColumn: some View {
        let sun = r.sun
        let direction = "\(Int(Geo.jsRound(sun.azimuth)) % 360)° \(Geo.point(sun.azimuth))"
        let height = sun.altitude > 0 ? "\(Int(Geo.jsRound(sun.altitude)))° up" : "Below"
        return column("Sun", first: true, value: direction, sub: height) {
            RoseMark(sun: sun, ink: ink, size: 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sun, \(direction), \(sun.altitude > 0 ? height : "below the horizon")")
    }

    private func timeColumn(_ label: String, symbol: String, date: Date) -> some View {
        let clock = WidgetReadings.clock(date)
        return column(label, value: clock.time, sub: clock.period) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(ink.sun)
        }
    }

    private func column<Mark: View>(_ label: String, first: Bool = false, value: String, sub: String,
                                    @ViewBuilder mark: () -> Mark) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: Look.widgetCaptionSize, weight: first ? .semibold : .medium))
                .foregroundStyle(first ? ink.label : ink.muted)
            mark()
                .frame(height: 34)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ink.primary)
            // A space keeps the columns' lines level when there is no AM or PM.
            Text(sub.isEmpty ? " " : sub)
                .font(.system(size: 10))
                .foregroundStyle(ink.muted)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .frame(maxWidth: .infinity)
    }
}

/// "82% · Waxing gibbous" with the moon's glyph.
private struct MoonLine: View {
    let r: WidgetReadings
    let ink: WidgetInk

    var body: some View {
        HStack(spacing: 5) {
            MoonMark(phase: r.moon.phase, ink: ink, size: 12)
            Text(r.moonText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ink.muted)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Moon, \(r.moon.name), \(Int(Geo.jsRound(r.moon.fraction * 100))) percent lit")
    }
}

private struct SmallWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk
    var body: some View { WhereBlock(r: r, ink: ink) }
}

/// Two Degrees' medium widget: the small block on the left, the sun's row and the moon on the right.
private struct MediumWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk

    var body: some View {
        HStack(spacing: 14) {
            WhereBlock(r: r, ink: ink)
                .frame(width: 128)
            Rectangle().fill(ink.rule).frame(width: 0.5)
            VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                SunRow(r: r, ink: ink)
                MoonLine(r: r, ink: ink)
                    .padding(.leading, 4)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Two Degrees' large widget: the reading on top, a map of where you are, the sun's row, then the moon,
/// the marked spot and the time of the fix.
private struct LargeWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk
    let map: PlatformImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            top
            Rectangle().fill(ink.rule).frame(height: 0.5)
            mapCard
            SunRow(r: r, ink: ink)
            Rectangle().fill(ink.rule).frame(height: 0.5)
            foot
        }
    }

    /// The place and the elevation on the left, the sky and the coordinates on the right.
    private var top: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.place)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    WidgetElevation(r: r, ink: ink, size: 46)
                    Text(r.elevation?.small ?? "Elevation unknown")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(ink.muted)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.spokenElevation)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 6) {
                WidgetSkySymbol(r: r, ink: ink, size: 32)
                    .frame(height: 40)
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(r.coordinates, id: \.self) { line in
                        Text(line)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ink.secondary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
        }
    }

    /// The map, which gives way first if the widget is short of room. In the tinted modes the picture
    /// would fill solid, so only its outline and your position are drawn.
    private var mapCard: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return Color.clear
            .frame(maxWidth: .infinity, minHeight: 64, maxHeight: 112)
            .overlay {
                if let map, !ink.tinted {
                    mapImage(map)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else if !ink.tinted {
                    Palette.tile
                    Image(systemName: "map")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textFaint)
                }
            }
            .overlay {
                // The snapshot is centred on you.
                Circle().fill(ink.primary).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(Color.black.opacity(ink.tinted ? 0 : 0.35), lineWidth: 2.5))
            }
            .clipShape(shape)
            .overlay { if ink.tinted { shape.stroke(ink.rule, lineWidth: 1) } }
            .accessibilityHidden(true)
    }

    /// The moon, then the marked spot if there is one, with the time of the fix at the far right.
    private var foot: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MoonLine(r: r, ink: ink)
                Spacer(minLength: 6)
                if r.spotText == nil { time }
            }
            if let spot = r.spotText {
                HStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin").foregroundStyle(ink.primary)
                        // One Text, so the HStack's spacing doesn't open a wider gap before the dot (as in the app's pill).
                        (Text("Marked spot").fontWeight(.semibold).foregroundColor(ink.primary)
                         + Text("\u{00A0}· \(spot)").foregroundColor(ink.secondary))
                    }
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityElement(children: .combine)
                    Spacer(minLength: 6)
                    time
                }
            }
        }
    }

    private var time: some View {
        Text(r.asOf)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(ink.muted)
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
    }

    private func mapImage(_ image: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }
}

/// Before the app has found you (Two Degrees' unavailable view).
private struct EmptyWidget: View {
    let family: WidgetFamily
    let ink: WidgetInk

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryInline:
            Label("Open Bearings", systemImage: "location")
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "location").font(.system(size: 20, weight: .medium))
            }
            .accessibilityLabel("Open Bearings to find where you are.")
        case .accessoryRectangular:
            Text("Open Bearings to find where you are.")
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, alignment: .leading)
        #endif
        default:
            VStack(alignment: .leading, spacing: 4) {
                if ink.tinted {
                    Image(systemName: "location.north.circle")
                        .font(.system(size: 26, weight: .medium))
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                } else {
                    AppMark(size: 28)
                }
                Spacer(minLength: 2)
                Image(systemName: "location")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(ink.muted)
                    .accessibilityHidden(true)
                Text("Open Bearings to find where you are.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

#if os(iOS)
// MARK: - Lock Screen

// The Lock Screen draws these in one tint, so they carry no colours of their own: the larger unit is
// the accented part, the other unit sits beside or beneath it (as in Two Degrees).

/// One line above the clock: "⛰ 9,587 ft · Aspen".
private struct InlineAccessory: View {
    let r: WidgetReadings

    var body: some View {
        Label {
            Text("\(r.elevation?.big ?? "—") · \(r.shortPlace)")
        } icon: {
            Image(systemName: "mountain.2.fill")
        }
        .accessibilityLabel("\(r.spokenElevation), \(r.place)")
    }
}

/// The elevation, compact: "9.6k" over "ft".
private struct CircularAccessory: View {
    let r: WidgetReadings

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: -1) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(r.compactElevation?.number ?? "—")
                    .font(.system(size: 20, weight: .semibold))
                    .widgetAccentable()
                Text(r.compactElevation?.unit ?? "")
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.75)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(r.spokenElevation)
    }
}

/// The place, the elevation in both units, and the coordinates.
private struct RectangularAccessory: View {
    let r: WidgetReadings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: "mountain.2.fill")
                Text(r.place).lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(r.elevation?.big ?? "—")
                    .font(.system(size: 22, weight: .semibold))
                    .widgetAccentable()
                Text(r.elevation?.small ?? "")
                    .font(.system(size: 14, weight: .medium))
                    .opacity(0.75)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            // "39.09898° N, 106.94117° W": the comma keeps latitude and longitude apart.
            Text(r.coordinates.joined(separator: ",\u{00A0}"))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .opacity(0.75)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(r.place). \(r.spokenElevation). \(r.coordinates.joined(separator: ", "))")
    }
}
#endif
