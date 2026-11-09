import SwiftUI
import WidgetKit

// Widget views, shared by the widget extension and the app (whose self-tests draw them). A widget can't
// read the compass and may be minutes old, so its dial is fixed north-up and shows only bearings that are
// true wherever the phone points: the sun, the moon, the marked spot and the locked bearing (mock W2,
// docs/DESIGN.md "Widgets"). Every Home Screen and desktop widget is black, with the app's slim sky header
// (the place and the time of the reading) and its frosted tiles. The Lock Screen's keep the W1 elevation
// design (no dial: place, elevation, coordinates and a 0–14,000 ft gauge), drawn in one tint.

struct BearingsEntry: TimelineEntry {
    let date: Date
    /// The app's last fix (or the widget's own fresher one); nil before the app has found you.
    let snapshot: WidgetSnapshot?
    var isPlaceholder = false

    static func placeholder(_ date: Date = Date()) -> BearingsEntry {
        BearingsEntry(date: date, snapshot: .sample, isPlaceholder: true)
    }
}

enum WidgetTimeline {
    /// An entry every 15 minutes for two hours, each with the sun and moon for its own time.
    static func entries(snapshot: WidgetSnapshot?, start: Date = Date()) -> [BearingsEntry] {
        (0...8).map { i in
            BearingsEntry(date: start.addingTimeInterval(Double(i) * 15 * 60), snapshot: snapshot)
        }
    }

    /// When WidgetKit should ask again (DESIGN.md: every 30 minutes).
    static let refresh: TimeInterval = 30 * 60
}

/// The app's black behind every Home Screen and desktop widget (no crimson rule).
struct WidgetBackground: View {
    var body: some View {
        Palette.screen
    }
}

/// What the entry's numbers read as, in the app's units and coordinate format.
struct WidgetReadings {
    let snapshot: WidgetSnapshot
    let date: Date

    var feet: Bool { snapshot.feet }

    var place: String { snapshot.place ?? "Where you are" }
    /// "Aspen" from "Aspen, Colorado", for the small widgets and the Lock Screen.
    var shortPlace: String { place.components(separatedBy: ",").first ?? place }

    /// "9:41 AM": when the reading is from.
    var asOf: String { Look.timeText(snapshot.time) }
    /// "as of 9:41 AM": the Small header's second line. A widget shows its last reading, not a clock, so
    /// the time says so (review 2.3.0, 24).
    var asOfLine: String { "as of \(asOf)" }
    /// "Sun, Nov 1 · as of 9:41 AM": the header's second line on Medium and Large.
    var dateLine: String {
        let day = snapshot.time.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(asOfLine)"
    }

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

    /// The circular Lock Screen gauge's fill: 0 → 14,000 ft, clamped (metres fill the same).
    var gaugeFraction: Double? {
        snapshot.elevation.map { min(max($0 / Geo.foot / 14000, 0), 1) }
    }

    /// The rectangular Lock Screen widget's one line: decimal degrees to 4 places (about 11 m) so both
    /// fit, "39.0990° N  106.9412° W"; the other formats as the app writes them.
    var lockCoordinates: String {
        let lat = snapshot.latitude, lon = snapshot.longitude
        if snapshot.coordinateFormat == .dd {
            return "\(Geo.fixed(abs(lat), 4))° \(lat < 0 ? "S" : "N")  \(Geo.fixed(abs(lon), 4))° \(lon < 0 ? "W" : "E")"
        }
        return coordinates.joined(separator: "  ")
    }

    /// Two lines for latitude and longitude, or one grid reference.
    var coordinates: [String] {
        switch Geo.format(snapshot.coordinateFormat, lat: snapshot.latitude, lon: snapshot.longitude) {
        case let .pair(lat, lon): [lat, lon]
        case let .single(text): [text]
        }
    }

    var sun: Sky.Position { Sky.sunPosition(at: date, lat: snapshot.latitude, lon: snapshot.longitude) }
    var moonPosition: Sky.Position { Sky.moonPosition(at: date, lat: snapshot.latitude, lon: snapshot.longitude) }
    var times: Sky.Times { Sky.sunTimes(at: date, lat: snapshot.latitude, lon: snapshot.longitude) }
    var moon: Sky.Phase { Sky.moonPhase(at: date) }

    /// The app's one time formatter (Look.timeText), so the widgets and the Sun tile read alike (§3.7).
    var sunrise: String? { times.sunriseDate.map { Look.timeText($0) } }
    var sunset: String? { times.sunsetDate.map { Look.timeText($0) } }
    var polarText: String { times.polar == .day ? "Sun up all day" : "Sun down all day" }
    /// "144° SE": the sun's azimuth, as the Large widget's Sun caption.
    var sunDirection: String { Self.direction(sun.azimuth) }
    /// "53%": how much of the moon is lit.
    var moonPercent: String { "\(Int(Geo.jsRound(moon.fraction * 100)))%" }
    /// "Last quarter".
    var moonName: String { Look.phaseName(moon) }
    /// "53% · Last quarter": the same wording as the app's Moon tile (Look.moonText).
    var moonText: String { Look.moonText(moon) }

    /// The true bearing to the marked spot, if there is one.
    var spotBearing: Double? {
        guard let lat = snapshot.spotLatitude, let lon = snapshot.spotLongitude else { return nil }
        return Geo.bearing(lat1: snapshot.latitude, lon1: snapshot.longitude, lat2: lat, lon2: lon)
    }

    /// "9.2 mi" to the marked spot.
    var spotDistance: String? {
        guard let lat = snapshot.spotLatitude, let lon = snapshot.spotLongitude else { return nil }
        let d = Geo.distance(lat1: snapshot.latitude, lon1: snapshot.longitude, lat2: lat, lon2: lon)
        return Geo.distanceText(d, feet: feet)
    }

    /// "9.2 mi · 46° NE" to the marked spot.
    var spotText: String? {
        guard let distance = spotDistance, let bearing = spotBearing else { return nil }
        return "\(distance) · \(Self.direction(bearing))"
    }

    /// The locked bearing (true), if one is set in the app.
    var lockBearing: Double? { snapshot.lockBearing.map { Geo.normalize($0) } }
    /// "240°".
    var lockText: String? { lockBearing.map { "\(Int(Geo.jsRound($0)) % 360)°" } }

    /// Everything the dial can show for this entry.
    var marks: WidgetDialMarks {
        WidgetDialMarks(sun: sun, moon: moonPosition, moonPhase: moon.phase, spot: spotBearing, lock: lockBearing)
    }

    /// "Compass, north up. Sun 144° Southeast. Moon 258° West. Marked spot 9.2 mi, 46° Northeast. Locked 240°."
    func spokenDial(lock: Bool = true) -> String {
        var parts = ["Compass, north up"]
        parts.append("Sun \(Int(Geo.jsRound(sun.azimuth)) % 360)° \(Geo.pointName(sun.azimuth))\(sun.altitude > 0 ? "" : ", below the horizon")")
        parts.append("Moon \(Int(Geo.jsRound(moonPosition.azimuth)) % 360)° \(Geo.pointName(moonPosition.azimuth))")
        if let b = spotBearing, let d = spotDistance { parts.append("Marked spot \(d), \(Int(Geo.jsRound(b)) % 360)° \(Geo.pointName(b))") }
        if lock, let t = lockText { parts.append("Locked \(t)") }
        return parts.joined(separator: ". ")
    }

    var spokenElevation: String {
        guard let m = snapshot.elevation else { return "Elevation unknown" }
        let ft = "\(Geo.group(m / Geo.foot)) feet", metres = "\(Geo.group(m)) metres"
        return "Elevation \(feet ? ft : metres), \(feet ? metres : ft)"
    }

    /// "46° NE".
    static func direction(_ bearing: Double) -> String {
        "\(Int(Geo.jsRound(bearing)) % 360)° \(Geo.point(bearing))"
    }

    /// "9,587 ft" as ("9,587", "ft"), so the unit can be drawn smaller on the number's baseline.
    static func split(_ text: String) -> (number: String, unit: String) {
        guard let space = text.lastIndex(of: " ") else { return (text, "") }
        return (String(text[..<space]), String(text[text.index(after: space)...]))
    }
}

/// The widget's colours. In full colour: white type in the app's steps of opacity, the sky header, pink
/// for north, the spot and the lock, amber for the sun. In the tinted and clear modes (the tinted Home
/// Screen, StandBy, a Mac desktop widget in the background) the system draws everything in one colour, so
/// the widget uses that colour in steps of opacity, and the marks read by their shapes.
struct WidgetInk {
    let tinted: Bool

    var primary: Color { tinted ? Color.primary : Color.white }
    /// Captions and second lines: white at 60%.
    var secondary: Color { tinted ? Color.primary.opacity(0.7) : Color.white.opacity(Palette.Op.caption) }
    /// A unit beside its number, the header's time: white at 70–75%.
    var sub: Color { tinted ? Color.primary.opacity(0.8) : Color.white.opacity(0.75) }
    var pink: Color { tinted ? Color.primary : Palette.widgetPink }
    var sun: Color { tinted ? Color.primary : SkyMarks.sun }
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsBackground
    let entry: BearingsEntry
    /// Set by the app's self-tests, which draw widgets outside WidgetKit (always in full colour).
    var family: WidgetFamily? = nil

    /// Tinted, accented or vibrant, or clear (StandBy): one colour, no opaque blocks.
    private var ink: WidgetInk {
        WidgetInk(tinted: renderingMode != .fullColor || (!showsBackground && family == nil))
    }

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let r = WidgetReadings(snapshot: snapshot, date: entry.date)
                switch family ?? environmentFamily {
                case .systemMedium: MediumWidget(r: r, ink: ink)
                case .systemLarge: LargeWidget(r: r, ink: ink)
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

// MARK: - The north-up dial

/// What the widgets' dial can show: true bearings only.
struct WidgetDialMarks {
    var sun: Sky.Position? = nil
    var moon: Sky.Position? = nil
    var moonPhase: Double = 0
    /// The true bearing to the marked spot.
    var spot: Double? = nil
    /// The locked bearing, true.
    var lock: Double? = nil
}

/// The app's dial, fixed north-up (DialView's language: a dark disc, white ticks, pink N), drawn as
/// vectors at the size it's given. Tick density follows the size (mock W2): 180 pt and more, 2° / 10° /
/// 30° ticks with numbers every 30°; 100–180 pt, 10° / 30° with the four letters; under 100 pt, 10° / 30°.
/// `half` draws the top half (W → N → E): a mark below it becomes a small glyph beside the arc's nearer
/// end with one small arrow under it pointing its true way; the sun and moon are left off there while
/// they are below the horizon. (The Lock Screen has no dial: it keeps the W1 elevation design.)
struct WidgetDial: View {
    /// How dense the ticks are for a diameter (points).
    enum Density: Equatable {
        /// 180 pt and more: 2° / 10° / 30° and numbers.
        case full
        /// 100–180 pt: 10° / 30° and letters.
        case medium
        /// Under 100 pt: 10° / 30°, N only.
        case small

        static func of(_ diameter: CGFloat) -> Density {
            diameter >= 180 ? .full : diameter >= 100 ? .medium : .small
        }
    }

    let diameter: CGFloat
    var half = false
    /// One colour (a tinted Home Screen, StandBy, a dimmed Mac desktop): everything white, marks by shape.
    var mono = false
    var numbers = false
    var marks = WidgetDialMarks()
    /// A dashed line from you to the spot's pin.
    var spotLine = false
    /// A pill with the spot's distance ("9.2 mi").
    var spotLabel: String? = nil

    /// Room drawn around the dial for the lock's notch and the edge marks, without taking layout space.
    private static let overhang: CGFloat = 18

    /// Whether a bearing is on the top half (W → N → E).
    static func inUpperHalf(_ bearing: Double) -> Bool {
        let d = Geo.normalize(bearing)
        return d <= 90 || d >= 270
    }

    /// The default tick step for a diameter.
    static func tickStep(_ diameter: CGFloat) -> Int { Density.of(diameter) == .full ? 2 : 10 }

    /// How far in from the rim's radius `r` the N/E/S/W letters' centres sit, and the letters' size.
    static func letterRing(radius r: CGFloat, density: Density) -> (distance: CGFloat, size: CGFloat) {
        let lenMajor: CGFloat = density == .full ? 11 : density == .medium ? 8 : 6
        let sizeN: CGFloat = density == .full ? 18 : density == .medium ? 14 : 11
        let sizeL: CGFloat = density == .full ? 15 : density == .medium ? 12 : 11
        let distance: CGFloat = r - 2.5 - lenMajor - 3 - sizeN * 0.5
        return (distance, sizeL)
    }

    /// How far from the middle the sun or moon is drawn, for a glyph reaching `reach` from its own centre.
    /// On a 100–180 pt dial it sits wholly inside the N/E/S/W letters with 3 pt to spare, so it never
    /// covers one when it is due east, south or west (review 2.3.0, 10).
    static func skyDistance(radius r: CGFloat, density: Density, reach: CGFloat) -> CGFloat {
        switch density {
        case .full: return r * 0.5
        case .small: return r * 0.44
        case .medium:
            let ring = letterRing(radius: r, density: density)
            let inner: CGFloat = ring.distance - ring.size * 0.55 - 3
            return max(inner - reach, reach + 4)
        }
    }

    /// A mark a half dial can't show on its arc.
    struct EdgeMark: Equatable {
        enum Kind: Equatable { case spot, sun, moon }
        let kind: Kind
        /// Its true bearing, 90–270°.
        let bearing: Double
        /// East of south: beside the arc's E end. Otherwise beside the W end.
        let right: Bool
        /// 0 beside the horizon; each further mark on the same side sits one step higher.
        let slot: Int
    }

    /// The edge marks a half dial draws: the marked spot, then the sun and the moon, each only when its
    /// bearing is off the arc; the sun and moon only while they are above the horizon (review 2.3.0, 9).
    static func edgeMarks(_ marks: WidgetDialMarks) -> [EdgeMark] {
        var found: [(EdgeMark.Kind, Double)] = []
        if let spot = marks.spot, !inUpperHalf(spot) { found.append((EdgeMark.Kind.spot, Geo.normalize(spot))) }
        if let sun = marks.sun, sun.altitude > 0, !inUpperHalf(sun.azimuth) { found.append((EdgeMark.Kind.sun, Geo.normalize(sun.azimuth))) }
        if let moon = marks.moon, moon.altitude > 0, !inUpperHalf(moon.azimuth) { found.append((EdgeMark.Kind.moon, Geo.normalize(moon.azimuth))) }
        var result: [EdgeMark] = []
        var rightCount = 0, leftCount = 0
        for (kind, bearing) in found {
            let right = bearing < 180
            let slot = right ? rightCount : leftCount
            if right { rightCount += 1 } else { leftCount += 1 }
            result.append(EdgeMark(kind: kind, bearing: bearing, right: right, slot: slot))
        }
        return result
    }

    /// An edge mark's glyph sits this far outside the rim, its centre this far above the horizon; its
    /// arrow's centre this far under the glyph's; nothing of either reaches further than `edgeReach` from
    /// its own centre; marks on one side are `edgePitch` apart.
    static let edgeOut: CGFloat = 8.5
    static let edgeRise: CGFloat = 5
    static let edgeArrowDrop: CGFloat = 12
    static let edgeReach: CGFloat = 5.6
    static let edgePitch: CGFloat = 24

    /// The glyph's centre for an edge mark, on a half dial centred at `c` (on its horizon) with rim radius `r`.
    static func edgePoint(right: Bool, slot: Int, centre c: CGPoint, radius r: CGFloat) -> CGPoint {
        let x: CGFloat = right ? c.x + r + edgeOut : c.x - r - edgeOut
        let y: CGFloat = c.y - edgeRise - CGFloat(slot) * edgePitch
        return CGPoint(x: x, y: y)
    }

    /// How far an edge mark stays from the side of a widget `width` wide whose half dial (of `diameter`,
    /// with no lock) is centred in it: 10.9 pt for the Small widget's 124 pt dial in 170.
    static func edgeClearance(diameter: CGFloat, in width: CGFloat) -> CGFloat {
        let r: CGFloat = diameter / 2 - 2
        return width / 2 - r - edgeOut - edgeReach
    }

    /// The rim's margin inside the frame: room for the lock's notch when there is one.
    private var margin: CGFloat { marks.lock != nil ? 5 : 2 }
    private var radius: CGFloat { diameter / 2 - margin }
    /// The height it takes in a layout: the diameter, or the top half and 2 pt.
    var height: CGFloat { half ? radius + margin + 2 : diameter }

    var body: some View {
        let o = Self.overhang
        Canvas { ctx, _ in
            draw(ctx, origin: CGPoint(x: o, y: o))
        }
        .frame(width: diameter + 2 * o, height: height + 2 * o)
        .padding(-o)
        .frame(width: diameter, height: height)
    }

    private func draw(_ ctx: GraphicsContext, origin: CGPoint) {
        let density = Density.of(diameter)
        let big = density == .full, mid = density == .medium
        let m = margin, r = radius
        let c = CGPoint(x: origin.x + diameter / 2, y: origin.y + (half ? r + m : diameter / 2))
        let white = Color.white
        let pink: Color = mono ? white : Palette.widgetPink
        let amber: Color = mono ? white : SkyMarks.sun

        func pt(_ bearing: Double, _ distance: CGFloat) -> CGPoint {
            let a = bearing * Double.pi / 180
            return CGPoint(x: c.x + CGFloat(sin(a)) * distance, y: c.y - CGFloat(cos(a)) * distance)
        }
        func shows(_ bearing: Double) -> Bool { !half || Self.inUpperHalf(bearing) }

        // The disc.
        var disc = Path()
        if half {
            disc.move(to: CGPoint(x: c.x - r, y: c.y))
            disc.addArc(center: c, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            disc.closeSubpath()
        } else {
            disc.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        ctx.fill(disc, with: .color(mono ? white.opacity(0.10) : Palette.widgetDisc))
        ctx.stroke(disc, with: .color(mono ? white.opacity(0.35) : Palette.widgetDiscStroke), lineWidth: 1)

        // The ticks.
        let stepDeg = Self.tickStep(diameter)
        let lenMajor: CGFloat = big ? 11 : mid ? 8 : 6
        let lenTen: CGFloat = big ? 7 : mid ? 4.5 : 3.5
        let lenMinor: CGFloat = big ? 3.5 : mid ? 4.5 : 3.5
        let r0: CGFloat = r - 2.5
        for deg in stride(from: 0, to: 360, by: stepDeg) {
            let b = Double(deg)
            if !shows(b) { continue }
            let major = deg % 30 == 0, ten = deg % 10 == 0
            let len: CGFloat = major ? lenMajor : ten ? lenTen : lenMinor
            let width: CGFloat = major ? (big ? 2 : 1.6) : ten ? (big ? 1.2 : 1) : 0.8
            let color: Color = deg == 0 ? pink : major ? white : ten ? white.opacity(big ? 0.6 : 0.55) : white.opacity(0.3)
            var tick = Path()
            tick.move(to: pt(b, r0))
            tick.addLine(to: pt(b, r0 - len))
            ctx.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }

        // N, the other letters and the numbers.
        let sizeN: CGFloat = big ? 18 : mid ? 14 : 11
        let sizeL: CGFloat = big ? 15 : mid ? 12 : 11
        let rl: CGFloat = Self.letterRing(radius: r, density: density).distance
        func label(_ text: String, _ bearing: Double, size: CGFloat, weight: Font.Weight, color: Color, at distance: CGFloat) {
            let t = Text(text).font(.system(size: size, weight: weight)).foregroundColor(color)
            ctx.draw(t, at: pt(bearing, distance), anchor: .center)
        }
        label("N", 0, size: sizeN, weight: .bold, color: pink, at: rl)
        let points: [(String, Double)] = [("E", 90), ("S", 180), ("W", 270)]
        for (letter, b) in points where shows(b) {
            label(letter, b, size: sizeL, weight: .semibold, color: white, at: rl + (sizeN - sizeL) * 0.3)
        }
        if numbers {
            for deg in stride(from: 30, to: 360, by: 30) where deg % 90 != 0 && shows(Double(deg)) {
                label("\(deg)", Double(deg), size: 11, weight: .medium, color: white.opacity(0.6), at: rl + 2)
            }
        }

        // The horizon of a half dial, short of the W and E.
        if half {
            let reach: CGFloat = rl - sizeL * 0.6
            var horizon = Path()
            horizon.move(to: CGPoint(x: c.x - reach, y: c.y))
            horizon.addLine(to: CGPoint(x: c.x + reach, y: c.y))
            ctx.stroke(horizon, with: .color(white.opacity(0.22)), lineWidth: 1)
        }

        // You, in the middle of a big dial.
        if !half && big {
            var cross = Path()
            cross.move(to: CGPoint(x: c.x, y: c.y - 28)); cross.addLine(to: CGPoint(x: c.x, y: c.y + 28))
            cross.move(to: CGPoint(x: c.x - 28, y: c.y)); cross.addLine(to: CGPoint(x: c.x + 28, y: c.y))
            ctx.stroke(cross, with: .color(white.opacity(0.07)), lineWidth: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 22, y: c.y - 22, width: 44, height: 44)), with: .color(white.opacity(0.12)), lineWidth: 1)
        }

        // The glyphs.
        func sunGlyph(_ g: GraphicsContext, at p: CGPoint, radius k: CGFloat) {
            SkyMarks.drawSun(g, at: p, radius: k, color: amber)
        }
        func moonGlyph(_ g: GraphicsContext, at p: CGPoint, radius k: CGFloat) {
            if mono {
                g.fill(Path(ellipseIn: CGRect(x: p.x - k, y: p.y - k, width: 2 * k, height: 2 * k)), with: .color(white.opacity(0.25)))
                g.fill(SkyMarks.moonLit(center: p, radius: k, phase: marks.moonPhase), with: .color(white))
            } else {
                SkyMarks.drawMoon(g, at: p, radius: k, phase: marks.moonPhase)
            }
        }
        func pinGlyph(_ g: GraphicsContext, bearing: Double, head: CGFloat, tip: CGFloat, size hs: CGFloat) {
            var p = g
            p.translateBy(x: c.x, y: c.y)
            p.rotate(by: .degrees(bearing))
            let pin = Self.pinPath(head: head, tip: tip, size: hs)
            p.fill(pin, with: .color(pink))
            p.stroke(pin, with: .color(mono ? Color.black.opacity(0.55) : Color.black), style: StrokeStyle(lineWidth: 1.2, lineJoin: .round))
            let dot = hs * 0.38
            p.fill(Path(ellipseIn: CGRect(x: -dot, y: -head - dot, width: 2 * dot, height: 2 * dot)),
                   with: .color(mono ? Color.black.opacity(0.6) : white))
        }

        // One small filled arrow, centred at `a`, pointing along a bearing.
        func edgeArrow(at a: CGPoint, bearing: Double, color: Color) {
            let t = bearing * Double.pi / 180
            let dx = CGFloat(sin(t)), dy = CGFloat(-cos(t))
            let px = -dy, py = dx
            let back = CGPoint(x: a.x - dx * 3.2, y: a.y - dy * 3.2)
            var arrow = Path()
            arrow.move(to: CGPoint(x: a.x + dx * 3.8, y: a.y + dy * 3.8))
            arrow.addLine(to: CGPoint(x: back.x + px * 3.2, y: back.y + py * 3.2))
            arrow.addLine(to: CGPoint(x: back.x - px * 3.2, y: back.y - py * 3.2))
            arrow.closeSubpath()
            ctx.fill(arrow, with: .color(color))
        }

        let sunRadius: CGFloat = big ? 5 : mid ? 4 : 3
        let moonRadius: CGFloat = big ? 6.5 : mid ? 5.2 : 4
        // The sun's rays reach twice its radius.
        let sunDistance: CGFloat = Self.skyDistance(radius: r, density: density, reach: sunRadius * 2)
        let moonDistance: CGFloat = Self.skyDistance(radius: r, density: density, reach: moonRadius)
        // As on the app's dial: faint while below the horizon.
        if let moon = marks.moon, shows(moon.azimuth) {
            var g = ctx
            g.opacity = moon.altitude > 0 ? 1 : 0.35
            moonGlyph(g, at: pt(moon.azimuth, moonDistance), radius: moonRadius)
        }
        if let sun = marks.sun, shows(sun.azimuth) {
            var g = ctx
            g.opacity = sun.altitude > 0 ? 1 : 0.35
            sunGlyph(g, at: pt(sun.azimuth, sunDistance), radius: sunRadius)
        }

        // Off-arc marks on a half dial: a small glyph beside the nearer end of the arc (east for 90–180°,
        // west for 180–270°), clear of the rim and of the widget's edge, and one small arrow under it
        // pointing its true way. A second mark on the same side sits above the first.
        if half {
            for mark in Self.edgeMarks(marks) {
                let p = Self.edgePoint(right: mark.right, slot: mark.slot, centre: c, radius: r)
                let a = CGPoint(x: p.x, y: p.y + Self.edgeArrowDrop)
                switch mark.kind {
                case .sun:
                    sunGlyph(ctx, at: p, radius: 2.6)
                    edgeArrow(at: a, bearing: mark.bearing, color: amber)
                case .moon:
                    moonGlyph(ctx, at: p, radius: 4.2)
                    edgeArrow(at: a, bearing: mark.bearing, color: mono ? white : Palette.cream)
                case .spot:
                    var g = ctx
                    g.translateBy(x: p.x, y: p.y + 4.2)
                    g.fill(Self.pinPath(head: 5.6, tip: 0, size: 3.2), with: .color(pink))
                    edgeArrow(at: a, bearing: mark.bearing, color: pink)
                }
            }
        }

        // The locked bearing: a short pink arc on the rim and a notch outside it.
        if let lock = marks.lock, shows(lock) {
            var arc = Path()
            arc.addArc(center: c, radius: r, startAngle: .degrees(lock - 7 - 90), endAngle: .degrees(lock + 7 - 90), clockwise: false)
            ctx.stroke(arc, with: .color(pink), style: StrokeStyle(lineWidth: big ? 3 : 2.4, lineCap: .round))
            let n: CGFloat = big ? 6 : 5
            var g = ctx
            g.translateBy(x: c.x, y: c.y)
            g.rotate(by: .degrees(lock))
            var notch = Path()
            notch.move(to: CGPoint(x: 0, y: -r + n * 0.9))
            notch.addLine(to: CGPoint(x: n, y: -r - m + 0.5))
            notch.addLine(to: CGPoint(x: -n, y: -r - m + 0.5))
            notch.closeSubpath()
            g.fill(notch, with: .color(pink))
            if !mono { g.stroke(notch, with: .color(.black), lineWidth: 1) }
        }

        // The marked spot: a pink teardrop on the rim, its point toward you, and a dashed line from you.
        if let spot = marks.spot {
            let hs: CGFloat = big ? 7 : mid ? 5.6 : 4.6
            let head = r0 - hs - 0.5, tip = head - hs * 2.1
            if shows(spot) {
                if spotLine {
                    var line = Path()
                    line.move(to: pt(spot, big ? 6 : 4))
                    line.addLine(to: pt(spot, tip - 1))
                    let dash: [CGFloat] = big ? [3, 3] : [2.5, 2.5]
                    ctx.stroke(line, with: .color(pink.opacity(0.75)), style: StrokeStyle(lineWidth: big ? 1.6 : 1.3, lineCap: .round, dash: dash))
                }
                pinGlyph(ctx, bearing: spot, head: head, tip: tip, size: hs)
            }
        }

        // You, in the middle.
        let you: CGFloat = big ? 3 : 2.4
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - you, y: c.y - you, width: 2 * you, height: 2 * you)), with: .color(white))

        // The spot's distance in a pill: above the middle on a half dial, beside the line on a full one.
        if let text = spotLabel, let spot = marks.spot {
            let centre: CGPoint
            if half {
                centre = CGPoint(x: c.x, y: c.y - r * 0.38)
            } else {
                let a = spot * Double.pi / 180
                let along = pt(spot, r * 0.4)
                centre = CGPoint(x: along.x + CGFloat(cos(a)) * 18, y: along.y + CGFloat(sin(a)) * 18)
            }
            let resolved = ctx.resolve(Text(text).font(.system(size: 11, weight: .semibold)).foregroundColor(white))
            let size = resolved.measure(in: CGSize(width: 200, height: 40))
            let w: CGFloat = size.width + 12, h: CGFloat = 16
            let pill = Path(roundedRect: CGRect(x: centre.x - w / 2, y: centre.y - h / 2, width: w, height: h), cornerRadius: h / 2)
            ctx.fill(pill, with: .color(Color.black.opacity(mono ? 0.4 : 0.72)))
            ctx.stroke(pill, with: .color(pink.opacity(0.55)), lineWidth: 1)
            ctx.draw(resolved, at: centre, anchor: .center)
        }
    }

    /// A teardrop pointing down the y axis toward the origin: its head's centre `head` above the origin,
    /// its point `tip` above it, `size` the head's radius.
    static func pinPath(head: CGFloat, tip: CGFloat, size hs: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -tip))
        p.addCurve(to: CGPoint(x: -hs, y: -head),
                   control1: CGPoint(x: -hs * 0.5, y: -head + hs * 1.2),
                   control2: CGPoint(x: -hs, y: -head + hs * 0.7))
        p.addArc(center: CGPoint(x: 0, y: -head), radius: hs, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        p.addCurve(to: CGPoint(x: 0, y: -tip),
                   control1: CGPoint(x: hs, y: -head + hs * 0.7),
                   control2: CGPoint(x: hs * 0.5, y: -head + hs * 1.2))
        p.closeSubpath()
        return p
    }
}

// MARK: - Pieces shared by the Home Screen and desktop widgets

/// The marked spot's pin beside text: a pink teardrop with a white dot.
private struct PinGlyph: View {
    let ink: WidgetInk
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 14
            var pin = Path()
            pin.move(to: CGPoint(x: 7 * k, y: 15.5 * k))
            pin.addCurve(to: CGPoint(x: 1.5 * k, y: 6.2 * k), control1: CGPoint(x: 3 * k, y: 10.8 * k), control2: CGPoint(x: 1.5 * k, y: 8.6 * k))
            pin.addArc(center: CGPoint(x: 7 * k, y: 6.2 * k), radius: 5.5 * k, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            pin.addCurve(to: CGPoint(x: 7 * k, y: 15.5 * k), control1: CGPoint(x: 12.5 * k, y: 8.6 * k), control2: CGPoint(x: 11 * k, y: 10.8 * k))
            pin.closeSubpath()
            ctx.fill(pin, with: .color(ink.pink))
            if !ink.tinted {
                ctx.fill(Path(ellipseIn: CGRect(x: 5 * k, y: 4.2 * k, width: 4 * k, height: 4 * k)), with: .color(.white))
            }
        }
        .frame(width: size, height: size * 16 / 14)
        .accessibilityHidden(true)
    }
}

/// The locked bearing beside text: the dial's pink arc and notch.
private struct LockGlyph: View {
    let ink: WidgetInk
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, s in
            let k = s.width / 14
            var arc = Path()
            arc.addArc(center: CGPoint(x: 7 * k, y: 7 * k), radius: 6 * k, startAngle: .degrees(228), endAngle: .degrees(312), clockwise: false)
            ctx.stroke(arc, with: .color(ink.pink), style: StrokeStyle(lineWidth: 2.4 * k, lineCap: .round))
            var notch = Path()
            notch.move(to: CGPoint(x: 7 * k, y: 11 * k))
            notch.addLine(to: CGPoint(x: 11 * k, y: 4 * k))
            notch.addLine(to: CGPoint(x: 3 * k, y: 4 * k))
            notch.closeSubpath()
            ctx.fill(notch, with: .color(ink.pink))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
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

/// The app's slim location header: the sky for the sun's altitude behind the place (15 semibold) and the
/// time of the reading ("as of 9:41 AM", 12, white at 75%), 40 high. One colour at 14% in the tinted modes.
private struct WidgetHeader: View {
    let r: WidgetReadings
    let ink: WidgetInk
    /// Small: the short place and just the time.
    var short = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Palette.widgetInnerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text(short ? r.shortPlace : r.place)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ink.primary)
            Text(short ? r.asOfLine : r.dateLine)
                .font(.system(size: 12))
                .foregroundStyle(ink.sub)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Palette.widgetHeaderHeight)
        .background {
            if ink.tinted {
                shape.fill(Color.white.opacity(0.14))
            } else {
                shape.fill(SkyTone.gradient(altitude: r.sun.altitude))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A tile's caption: 11 semibold capitals, tracking 0.6, white at 60% (the app's tile caption).
private func captionText(_ text: String) -> Text {
    Text(text.uppercased())
        .font(.system(size: Look.tileCaptionSize, weight: .semibold))
        .tracking(Look.tileCaptionTracking)
}

/// The app's frosted tile: the caption at the top, the value at the foot, 12 across and 5 down.
private struct WidgetTile<Caption: View, Value: View>: View {
    let ink: WidgetInk
    let caption: Caption
    let value: Value

    init(ink: WidgetInk, @ViewBuilder caption: () -> Caption, @ViewBuilder value: () -> Value) {
        self.ink = ink
        self.caption = caption()
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption
                .foregroundStyle(ink.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            value
        }
        .padding(.horizontal, 12)
        // 5 down (the mock's 6 less SF's taller line box), so Medium's 49 pt tiles hold a caption and a 22 pt value.
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .frostedTile(radius: Palette.widgetInnerRadius)
    }
}

/// "↑ 6:36 AM" in the sun's amber.
private struct WidgetSunTime: View {
    let ink: WidgetInk
    let up: Bool
    let time: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: up ? "arrow.up" : "arrow.down")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ink.sun)
            Text(time)
                .font(.system(size: Look.compactValueSize, weight: .medium))
                .foregroundStyle(ink.primary)
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// "9,587 ft" large with "2,922 m" beside it (Medium) or under it (Large).
private struct ElevationValue: View {
    let r: WidgetReadings
    let ink: WidgetInk
    var size: CGFloat = 22
    var stacked = false

    var body: some View {
        let big = Text(r.elevation?.big ?? "—")
            .font(.system(size: size, weight: .medium))
            .tracking(-0.3)
        let small = Text(r.elevation?.small ?? "Unknown")
            .font(.system(size: Look.tileSecondarySize))
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 0) {
                    big.foregroundStyle(ink.primary)
                    small.foregroundStyle(ink.secondary)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    big.foregroundStyle(ink.primary)
                    small.foregroundStyle(ink.secondary)
                }
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(r.spokenElevation)
    }
}

/// Sunrise and sunset side by side or stacked, or "Sun up all day".
private struct SunTimes: View {
    let r: WidgetReadings
    let ink: WidgetInk
    var stacked = false

    var body: some View {
        Group {
            if let rise = r.sunrise, let down = r.sunset {
                if stacked {
                    VStack(alignment: .leading, spacing: 0) {
                        WidgetSunTime(ink: ink, up: true, time: rise)
                        WidgetSunTime(ink: ink, up: false, time: down)
                    }
                } else {
                    HStack(spacing: 12) {
                        WidgetSunTime(ink: ink, up: true, time: rise)
                        WidgetSunTime(ink: ink, up: false, time: down)
                    }
                }
            } else {
                Text(r.polarText)
                    .font(.system(size: Look.compactValueSize, weight: .medium))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(r.sunrise.map { "Sunrise \($0), sunset \(r.sunset ?? "")" } ?? r.polarText)
    }
}

// MARK: - Home Screen and desktop

/// Small (170 × 170): the header, the top half of the dial (W → N → E, 124 wide) with the spot's pin and
/// distance, the sun and moon as edge marks when they're up but off the arc, and the elevation at 30 pt
/// under it. No locked bearing at this size.
private struct SmallWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk

    var body: some View {
        var marks = r.marks
        marks.lock = nil
        let parts = WidgetReadings.split(r.elevation?.big ?? "—")
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                WidgetHeader(r: r, ink: ink, short: true)
                Spacer(minLength: 0)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(parts.number)
                        .font(.system(size: 30, weight: .medium))
                        .tracking(-0.6)
                        .foregroundStyle(ink.primary)
                        .widgetAccentable()
                    if !parts.unit.isEmpty {
                        Text(parts.unit)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(ink.sub)
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.spokenElevation)
            }
            WidgetDial(diameter: 124, half: true, mono: ink.tinted, marks: marks, spotLine: true, spotLabel: r.spotDistance)
                .padding(.top, Palette.widgetHeaderHeight + Palette.widgetInset)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(r.spokenDial(lock: false))
        }
        .padding(Palette.widgetInset)
    }
}

/// Medium (364 × 170): a 120 pt full dial on the left with every mark and the spot's readout under it;
/// the header over the right column, then the Elevation and Sun tiles (the moon's phase in the caption).
private struct MediumWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk

    var body: some View {
        HStack(alignment: .top, spacing: Palette.widgetInset) {
            VStack(spacing: 5) {
                WidgetDial(diameter: 120, mono: ink.tinted, marks: r.marks, spotLine: true)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(r.spokenDial())
                if let spot = r.spotText {
                    HStack(spacing: 5) {
                        PinGlyph(ink: ink, size: 11)
                        Text(spot)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ink.primary.opacity(0.9))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .accessibilityHidden(true)
                } else if let lock = r.lockText {
                    HStack(spacing: 5) {
                        LockGlyph(ink: ink, size: 11)
                        Text("Locked \(lock)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ink.primary.opacity(0.9))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    .accessibilityHidden(true)
                }
            }
            .frame(width: 128)
            .frame(maxHeight: .infinity)
            VStack(spacing: Palette.widgetInset) {
                WidgetHeader(r: r, ink: ink)
                WidgetTile(ink: ink) {
                    captionText("Elevation")
                } value: {
                    ElevationValue(r: r, ink: ink, size: 22)
                }
                WidgetTile(ink: ink) {
                    HStack(spacing: 4) {
                        captionText("Sun ·")
                        MoonMark(phase: r.moon.phase, ink: ink, size: 11)
                        captionText(r.moonPercent)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sun. Moon \(r.moonText)")
                } value: {
                    SunTimes(r: r, ink: ink)
                }
            }
        }
        .padding(Palette.widgetInset)
    }
}

/// Large (364 × 382): the header; a 212 pt dial with the app's full scale and every mark, Elevation, Sun
/// and Moon stacked beside it; Position and the marked spot (with the lock) full width below. Without a
/// spot or a lock that row drops out and, at the full 364 × 382, the freed 50 pt goes to the dial (228 pt,
/// the tiles beside it 112 wide) and to Position, which becomes a tile of the usual kind, 60 high (review
/// 2.3.0, 37). A smaller large widget keeps the 212 pt dial and the one-line Position.
private struct LargeWidget: View {
    let r: WidgetReadings
    let ink: WidgetInk

    /// The dial's diameter with the spot or lock row under it, and without.
    static let dialWithRow: CGFloat = 212
    static let dialAlone: CGFloat = 228

    private var hasRow: Bool { r.spotText != nil || r.lockText != nil }

    /// Whether a widget of this size, with no spot or lock row, has room for the bigger dial: 112 pt left
    /// for the tiles beside it, and its 228 pt between the header and the 60 pt Position tile.
    static func roomy(_ size: CGSize, hasRow: Bool) -> Bool {
        !hasRow && size.width >= 363.5 && size.height >= 360
    }

    var body: some View {
        GeometryReader { geo in
            content(roomy: Self.roomy(geo.size, hasRow: hasRow))
        }
    }

    private func content(roomy: Bool) -> some View {
        let diameter: CGFloat = roomy ? Self.dialAlone : Self.dialWithRow
        return VStack(spacing: Palette.widgetInset) {
            WidgetHeader(r: r, ink: ink)
            HStack(alignment: .center, spacing: Palette.widgetInset) {
                WidgetDial(diameter: diameter, mono: ink.tinted, numbers: true, marks: r.marks, spotLine: true, spotLabel: r.spotDistance)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(r.spokenDial())
                VStack(spacing: Palette.widgetInset) {
                    WidgetTile(ink: ink) {
                        captionText("Elevation")
                    } value: {
                        ElevationValue(r: r, ink: ink, size: 20, stacked: true)
                    }
                    WidgetTile(ink: ink) {
                        captionText("Sun · \(r.sunDirection)")
                            .minimumScaleFactor(0.85)
                    } value: {
                        SunTimes(r: r, ink: ink, stacked: true)
                    }
                    WidgetTile(ink: ink) {
                        captionText("Moon")
                    } value: {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 6) {
                                MoonMark(phase: r.moon.phase, ink: ink, size: 15)
                                Text(r.moonPercent)
                                    .font(.system(size: Look.tileValueSize, weight: .medium))
                                    .foregroundStyle(ink.primary)
                            }
                            Text(r.moonName)
                                .font(.system(size: Look.tileSecondarySize))
                                .foregroundStyle(ink.secondary)
                        }
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Moon, \(r.moonText)")
                    }
                }
            }
            .frame(maxHeight: .infinity)
            if hasRow {
                position
                spotRow
            } else if roomy {
                positionTile
            } else {
                position
            }
        }
        .padding(Palette.widgetInset)
    }

    /// Position as a tile, caption over value, when there is no spot or lock row under it.
    private var positionTile: some View {
        WidgetTile(ink: ink) {
            captionText("Position")
        } value: {
            Text(r.coordinates.joined(separator: "  "))
                .font(.system(size: Look.tileValueSize, weight: .medium))
                .foregroundStyle(ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(height: 60)
        .accessibilityElement(children: .combine)
    }

    private var position: some View {
        HStack(spacing: 8) {
            captionText("Position")
                .foregroundStyle(ink.secondary)
                .fixedSize()
            Spacer(minLength: 4)
            Text(r.coordinates.joined(separator: "  "))
                .font(.system(size: Look.compactValueSize, weight: .medium))
                .foregroundStyle(ink.primary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .frostedTile(radius: Palette.widgetInnerRadius)
        .accessibilityElement(children: .combine)
    }

    /// "(pin) Marked spot … (lock) 240°  9.2 mi · 46° NE", or the lock on its own.
    private var spotRow: some View {
        HStack(spacing: 8) {
            if let spot = r.spotText {
                PinGlyph(ink: ink, size: 14)
                Text("Marked spot")
                    .font(.system(size: Look.compactValueSize))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                    .layoutPriority(-1)
                Spacer(minLength: 4)
                if let lock = r.lockText {
                    HStack(spacing: 4) {
                        LockGlyph(ink: ink, size: 14)
                        Text(lock)
                            .font(.system(size: Look.tileSecondarySize))
                            .foregroundStyle(ink.sub)
                    }
                    .fixedSize()
                }
                Text(spot)
                    .font(.system(size: Look.compactValueSize, weight: .semibold))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else if let lock = r.lockText {
                LockGlyph(ink: ink, size: 14)
                Text("Locked bearing")
                    .font(.system(size: Look.compactValueSize))
                    .foregroundStyle(ink.primary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(lock)
                    .font(.system(size: Look.compactValueSize, weight: .semibold))
                    .foregroundStyle(ink.primary)
            }
        }
        .monospacedDigit()
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .frostedTile(radius: Palette.widgetInnerRadius)
        .accessibilityElement(children: .combine)
    }
}

/// Before the app has found you.
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
                    .foregroundStyle(ink.secondary)
                    .accessibilityHidden(true)
                Text("Open Bearings to find where you are.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ink.primary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

#if os(iOS)
// MARK: - Lock Screen

// The W1 elevation design (mock W1, "iPhone · Lock Screen"): no dial, since a compass needs more room and
// colour than the Lock Screen gives. iOS draws these in one tint (vibrant), so they carry no colours of
// their own: the hierarchy is weight and opacity only (100 / 75 / 65%).

/// One line beside the date: "⛰ 9,587 ft · Maroon Bells". The place comes last, so it's what truncates.
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

/// A 270° gauge on the accessory backdrop, filled 0 → 14,000 ft (the same fill in metres), with "9.6k" in
/// the middle and the unit in the ring's gap.
private struct CircularAccessory: View {
    let r: WidgetReadings

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            ElevationRing(fraction: r.gaugeFraction)
            Text(r.compactElevation?.number ?? "—")
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.3)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 46)
                .offset(y: -2)
                .widgetAccentable()
            Text(r.compactElevation?.unit ?? "")
                .font(.system(size: 11, weight: .semibold))
                .opacity(0.75)
                .lineLimit(1)
                .offset(y: 20.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(r.spokenElevation)
    }
}

/// The circular widget's ring, drawn to its frame (76 pt in the mock): a 270° track at 28% opening at the
/// bottom, the fill to the elevation in full, and a dot at its end.
private struct ElevationRing: View {
    /// 0…1 along the ring; nil (no elevation) draws the track alone.
    let fraction: Double?

    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 76
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = 31 * k, line = 6 * k
            // 135° is the lower left; the ring runs clockwise over the top to the lower right (405°).
            func arc(to end: Double) -> Path {
                var p = Path()
                p.addArc(center: c, radius: radius, startAngle: .degrees(135), endAngle: .degrees(135 + 270 * end), clockwise: false)
                return p
            }
            let style = StrokeStyle(lineWidth: line, lineCap: .round)
            ctx.stroke(arc(to: 1), with: .color(.white.opacity(0.28)), style: style)
            guard let f = fraction else { return }
            if f > 0 { ctx.stroke(arc(to: f), with: .color(.white), style: style) }
            let a = (135 + 270 * f) * Double.pi / 180
            let end = CGPoint(x: c.x + radius * CGFloat(cos(a)), y: c.y + radius * CGFloat(sin(a)))
            let d = 4.6 * k
            let dot = Path(ellipseIn: CGRect(x: end.x - d, y: end.y - d, width: 2 * d, height: 2 * d))
            ctx.fill(dot, with: .color(.white))
            ctx.stroke(dot, with: .color(.black.opacity(0.35)), lineWidth: 1.5 * k)
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

/// The place with the mountain glyph (15 semibold), the elevation (20 bold) with the other unit at 65%
/// beside it, and the coordinates on one line (12, at 75%).
private struct RectangularAccessory: View {
    let r: WidgetReadings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "mountain.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(r.shortPlace)
                    .font(.system(size: 15, weight: .semibold))
            }
            .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(r.elevation?.big ?? "—")
                    .font(.system(size: 20, weight: .bold))
                    .widgetAccentable()
                Text(r.elevation?.small ?? "")
                    .font(.system(size: 15, weight: .medium))
                    .opacity(0.65)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(r.lockCoordinates)
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
