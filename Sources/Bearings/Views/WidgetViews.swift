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
    var moonText: String { "\(moon.name) · \(Int(Geo.jsRound(moon.fraction * 100)))%" }

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
}

struct WidgetView: View {
    @Environment(\.widgetFamily) private var environmentFamily
    let entry: BearingsEntry
    /// Set by the app's self-tests, which draw widgets outside WidgetKit.
    var family: WidgetFamily? = nil

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                let r = WidgetReadings(snapshot: snapshot, date: entry.date)
                switch family ?? environmentFamily {
                case .systemMedium: MediumWidget(r: r)
                case .systemLarge: LargeWidget(r: r, map: entry.map)
                #if os(iOS)
                case .accessoryInline: InlineAccessory(r: r)
                case .accessoryCircular: CircularAccessory(r: r)
                case .accessoryRectangular: RectangularAccessory(r: r)
                #endif
                default: SmallWidget(r: r)
                }
            } else {
                EmptyWidget(family: family ?? environmentFamily)
            }
        }
        .environment(\.colorScheme, .dark)
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }
}

// MARK: - Home Screen and desktop

/// The place, the elevation large with the other unit under it, the coordinates, and the time.
private struct WhereBlock: View {
    let r: WidgetReadings
    var big: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(r.place)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.cream)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(r.elevation?.big ?? "—")
                    .font(.system(size: big, weight: .semibold))
                    .tracking(-big * 0.03)
                    .foregroundStyle(.white)
                    .widgetAccentable()
                Text(r.elevation?.small ?? "Elevation unknown")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Palette.textMuted)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(r.spokenElevation)
            Spacer(minLength: 4)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(r.coordinates, id: \.self) { line in
                    Text(line)
                }
                Text(r.asOf).foregroundStyle(Palette.textFaint)
            }
            .font(.system(size: 11, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// Sunrise and sunset, the moon, and a rose with the sun's direction.
private struct SkyBlock: View {
    let r: WidgetReadings

    var body: some View {
        let sun = r.sun
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                SunRose(sun: sun, size: 54)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Sun")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.textMuted)
                    Text("\(Int(Geo.jsRound(sun.azimuth)) % 360)° \(Geo.point(sun.azimuth))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(sun.altitude > 0 ? "\(Int(Geo.jsRound(sun.altitude)))° up" : "Below the horizon")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textMuted)
                }
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 4) {
                if let rise = r.sunrise, let down = r.sunset {
                    HStack(spacing: 5) {
                        Image(systemName: "sunrise.fill").foregroundStyle(SkyMarks.sun)
                        Text(rise)
                        Image(systemName: "sunset.fill").foregroundStyle(SkyMarks.sun).padding(.leading, 4)
                        Text(down)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sunrise \(rise), sunset \(down)")
                } else {
                    Text(r.polarText)
                }
                HStack(spacing: 5) {
                    MoonGlyph(phase: r.moon.phase, size: 12)
                    Text(r.moonText)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Moon, \(r.moon.name), \(Int(Geo.jsRound(r.moon.fraction * 100))) percent lit")
            }
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct SmallWidget: View {
    let r: WidgetReadings
    var body: some View { WhereBlock(r: r, big: 32) }
}

private struct MediumWidget: View {
    let r: WidgetReadings

    var body: some View {
        HStack(spacing: 14) {
            WhereBlock(r: r, big: 30)
            Rectangle().fill(Palette.border).frame(width: 0.5)
            SkyBlock(r: r)
        }
    }
}

/// A map of where you are on top, then the medium widget's two halves, and the marked spot.
private struct LargeWidget: View {
    let r: WidgetReadings
    let map: PlatformImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let map {
                    mapImage(map)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Palette.tile
                    Image(systemName: "map")
                        .font(.system(size: 22))
                        .foregroundStyle(Palette.textFaint)
                }
                // The snapshot is centred on you.
                Circle().fill(Palette.accent).frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2.5))
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 132)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityHidden(true)
            HStack(spacing: 14) {
                WhereBlock(r: r, big: 30)
                Rectangle().fill(Palette.border).frame(width: 0.5)
                SkyBlock(r: r)
            }
            if let spot = r.spotText {
                HStack(spacing: 6) {
                    Image(systemName: "mappin").foregroundStyle(Palette.accent)
                    Text("Marked spot").fontWeight(.semibold).foregroundStyle(.white)
                    Text("· \(spot)").foregroundStyle(Palette.textSecondary)
                }
                .font(.system(size: 12))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func mapImage(_ image: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }
}

/// Before the app has found you.
private struct EmptyWidget: View {
    let family: WidgetFamily

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
            VStack(alignment: .leading, spacing: 8) {
                AppMark(size: 28)
                Spacer(minLength: 0)
                Text("Open Bearings to find where you are.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.cream)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

#if os(iOS)
// MARK: - Lock Screen

// The Lock Screen draws these in one tint, so they carry no colours of their own.

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
                    .font(.system(size: 18, weight: .semibold))
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
            Text(r.place)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(r.elevation?.big ?? "—")
                    .font(.system(size: 19, weight: .semibold))
                    .widgetAccentable()
                Text(r.elevation?.small ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .opacity(0.75)
            }
            .monospacedDigit()
            Text(r.coordinates.joined(separator: " "))
                .font(.system(size: 11, weight: .medium))
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
