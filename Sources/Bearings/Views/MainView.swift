import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Bearings' one screen, top to bottom: where you are and the time, the dial with the sun, moon and a
/// marked spot, the heading, latitude and longitude, elevation, the sun's day, and a map filling the
/// rest. The same view on Mac, iPhone and iPad; it fits one iPhone screen without scrolling (the dial
/// gives way first). It wears Two Degrees' look (docs/LOOK.md): black, a large title, a sky card, frosted
/// tiles with uppercase captions, and white highlights.
struct MainView: View {
    @EnvironmentObject private var nav: Navigator
    /// "Bearings 0.2.0 is available" on the Mac (nil elsewhere).
    var update: (version: String, url: URL)?
    @State private var toast: String?
    @State private var showAbout = false
    @Environment(\.openURL) private var openURL
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lastAnnouncement = Date.distantPast
    #endif

    /// Night mode's red: multiplied over everything, so whites turn red and nothing stays blue or green.
    static let nightTint = Color(red: 1, green: 0.18, blue: 0.12)

    // The grid (DESIGN.md, docs/LOOK.md): margins 16, gaps between blocks 12, tiles 8 apart.
    private static let margin: CGFloat = Look.margin
    private static let gap: CGFloat = Look.gap
    private static let tileGap: CGFloat = Look.tileGap
    private static let tileHeight: CGFloat = 84
    private static let pillHeight: CGFloat = 46
    private static let mapMinimum: CGFloat = 120

    /// The footer under the map: on the Mac and a wide iPad; on a phone it's in About.
    private var showsFooter: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    /// The system's Text Size, as a multiplier on the header and tiles: 1 at the default size, up to 1.3.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    /// Text Size alone, capped at 1.3: decides when the subline may take a second line, so an iPad at the
    /// default size (whose k is 1.15) keeps one.
    private var textK: CGFloat { min(max(textScale, 1), 1.3) }

    /// Whether the subline under the heading may wrap to a second line (at a larger Text Size).
    private var sublineWraps: Bool { textK > 1.1 }

    /// Keeps a reading's words and units together ("21.29 inHg", "turn 12° right") and lets a line break
    /// only after a " · ", never before it, so a dot never starts a line. A long name with a comma
    /// ("Degrees, Decimal Minutes") may still break after its comma rather than be cut off.
    static func keepTogether(_ text: String) -> String {
        text.components(separatedBy: " · ")
            .map { part in
                part.components(separatedBy: ", ")
                    .map { $0.replacingOccurrences(of: " ", with: "\u{00A0}") }
                    .joined(separator: ", ")
            }
            .joined(separator: "\u{00A0}· ")
    }

    var body: some View {
        GeometryReader { geo in
            let dial = dialSide(for: geo.size)
            // The readout keeps its proportion to the dial, so a smaller dial isn't overpowered.
            let big = min(readoutSize(for: geo.size), max(40, (dial * 0.22).rounded()))
            let wide: CGFloat = Self.isWide(geo.size) ? 1.15 : 1
            let k: CGFloat = wide * textK
            let compact = isCompact(geo.size)
            VStack(spacing: Self.gap) {
                // The large title, 4 above the sky card (none on a short screen: the menu moves into the card).
                VStack(spacing: 4) {
                    if !compact { titleRow(wide: wide) }
                    if let update { updateBanner(update) }
                    skyCard(k: k, compact: compact)
                }
                compass(side: dial, big: big, k: k)
                if nav.spot != nil, nav.fix != nil { spotPill(k: k) }
                tiles
                MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                           speed: nav.speed.map { Geo.speedText($0, feet: nav.feet) }, dimmed: nav.nightMode)
                    .frame(minHeight: mapMinimum(for: geo.size), maxHeight: .infinity)
                if showsFooter { footer }
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .environment(\.uiScale, k)
            .environment(\.uiWide, wide)
            .frame(maxWidth: Self.isWide(geo.size) ? 560 : 460)
            .frame(maxWidth: .infinity)
        }
        .background(Palette.screen.ignoresSafeArea())
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) { toastView }
        // No accent colour inside the app: the menu's checks and the alert's buttons are white.
        .tint(.white)
        .environment(\.colorScheme, .dark)
        .colorMultiply(nav.nightMode ? Self.nightTint : .white)
        #if os(iOS)
        .onChange(of: nav.heading.map { Int($0 / 15) }) { announceHeading() }
        #endif
        .alert("Bearings", isPresented: $showAbout) {
            Button("Source Code") { openURL(Brand.repository) }
            Button("Done", role: .cancel) {}
        } message: {
            Text("\(Brand.tagline)\nFree, open source, no ads, no tracking.\n\nMade by \(Brand.author) · bradcowdrey.com\n\nGround elevation: Open-Meteo (CC BY 4.0), Copernicus DEM GLO-90 © DLR/ESA. Place names: GeoNames (CC BY 4.0). Sun and moon after SunCalc. Map: Apple Maps.\nVersion \(Self.version)")
        }
    }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }

    /// As wide as fits, at most 36% of the height and 360, and smaller still when the rest of the column
    /// needs the room (an iPhone SE).
    private func dialSide(for size: CGSize) -> CGFloat {
        let room = size.height - columnHeight(for: size, compact: isCompact(size))
        // An iPad or a wide Mac window gets a bigger dial in a wider column.
        let cap: CGFloat = Self.isWide(size) ? 420 : 360
        return max(140, min(size.width - 2 * Self.margin, size.height * 0.36, cap, room))
    }

    /// The map gives up a little height before the dial does when a marked spot needs the room.
    private func mapMinimum(for size: CGSize) -> CGFloat {
        let base = Self.mapMinimum * (size.height < 700 ? 0.8 : 1)
        return nav.spot != nil && nav.fix != nil ? base - 20 : base
    }

    private static func isWide(_ size: CGSize) -> Bool { size.width >= 700 && size.height >= 900 }

    /// Everything in the column but the dial.
    private func columnHeight(for size: CGSize, compact: Bool) -> CGFloat {
        let k: CGFloat = (Self.isWide(size) ? 1.15 : 1) * textK
        // The heading, then the subline, which grows with Text Size and may take a second line.
        let readout = readoutSize(for: size) * 1.2 + 4 + 18 * k + (sublineWraps ? 18 * k : 0) + 4
        // The title row (none when compact) and the 4 under it, then the sky card.
        let title: CGFloat = compact ? 0 : Look.titleRow * (Self.isWide(size) ? 1.15 : 1) + 4
        var rest = title + Self.skyHeight(k: k, compact: compact) + readout + 2 * Self.tileHeight * k + Self.tileGap + mapMinimum(for: size)
        var gaps = 4
        if nav.spot != nil && nav.fix != nil { rest += Self.pillHeight; gaps += 1 }
        if update != nil { rest += 44 + 4 }
        if showsFooter { rest += 16; gaps += 1 }
        rest += CGFloat(gaps) * Self.gap + 8   // text runs a little taller than its point size
        return rest
    }

    /// Under 700 high (an iPhone SE), or when the title row would leave the dial under 140 (a large Text
    /// Size, the Mac's smallest window): no title row, and the ⋯ menu sits in the sky card.
    private func isCompact(_ size: CGSize) -> Bool {
        size.height < Look.compactHeight || size.height - columnHeight(for: size, compact: false) < 140
    }

    /// The sky card's height: 28 + 44 × k (24 + 44 × k on a short screen, never under 68 so the menu
    /// keeps its 44 target).
    private static func skyHeight(k: CGFloat, compact: Bool) -> CGFloat {
        compact ? max(68, 24 + 44 * k) : 28 + 44 * k
    }

    private func readoutSize(for size: CGSize) -> CGFloat { size.height < 700 ? 46 : Self.isWide(size) ? 64 : 56 }

    // MARK: Title and sky card

    /// "Bearings", large, with the ⋯ menu at the right (as Two Degrees' and Meridian's lists).
    private func titleRow(wide: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(Brand.appName)
                .font(.system(size: Look.titleSize * wide, weight: .bold))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            menu
        }
        .frame(height: Look.titleRow * wide)
    }

    /// Where you are and the time, on the sky for the sun's altitude here (Two Degrees' city card).
    private func skyCard(k: CGFloat, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(nav.placeTitle)
                    .font(.system(size: 20 * k, weight: .semibold))
                    .tracking(-0.3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 6) {
                    Text(dateLine)
                        .font(.system(size: 14 * k, weight: .medium))
                        .foregroundStyle(Color.white.opacity(Palette.Op.body))
                        .monospacedDigit()
                        .lineLimit(1)
                    if nav.sample {
                        Text("Sample")
                            // 11 is the smallest text size; it grows with the date beside it.
                            .font(.system(size: 11 * k, weight: .semibold))
                            .foregroundStyle(Color.black)
                            .padding(.horizontal, 6).padding(.vertical, 1)
                            .background(Capsule().fill(Palette.notice))
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if compact {
                menu
            } else {
                Image(systemName: SkyTone.symbol(for: nav.sunPosition))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.white.opacity(Palette.Op.body))
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white)
        .padding(compact ? 12 : Look.skyPadding)
        // Grows with Text Size as its type does (and as dialSide budgets it), so the date keeps its
        // distance from the dial.
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: Self.skyHeight(k: k, compact: compact), alignment: .top)
        .skyCard(altitude: nav.sunPosition?.altitude)
    }

    /// "Sat, Nov 1 · 9:41 AM", in the device's 12- or 24-hour style.
    private var dateLine: String {
        let day = nav.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(nav.now.formatted(date: .omitted, time: .shortened))"
    }

    private var menu: some View {
        Menu {
            Picker("Coordinates", selection: $nav.format) {
                ForEach(Geo.Format.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.inline)
            Picker("Units", selection: $nav.feet) {
                Text("Feet First").tag(true)
                Text("Metres First").tag(false)
            }
            .pickerStyle(.inline)
            #if os(iOS)
            Picker("North", selection: $nav.preferTrueNorth) {
                Text("True North").tag(true)
                Text("Magnetic North").tag(false)
            }
            .pickerStyle(.inline)
            #endif
            Section("Map") {
                Toggle("Follow Heading", isOn: $nav.followHeading)
                Picker("Map Style", selection: $nav.satellite) {
                    Text("Standard").tag(false)
                    Text("Satellite").tag(true)
                }
                .pickerStyle(.menu)
            }
            Toggle("Night Mode", isOn: $nav.nightMode)
            Divider()
            if nav.spot == nil {
                Button("Mark This Spot", systemImage: "mappin.and.ellipse") { nav.markSpot() }
                    .disabled(nav.fix == nil)
            } else {
                Button("Clear Marked Spot", systemImage: "mappin.slash") { nav.clearSpot() }
            }
            Button(nav.lock == nil ? "Lock This Bearing" : "Clear Locked Bearing", systemImage: "scope") { nav.toggleLock() }
                .disabled(nav.heading == nil)
            Divider()
            Button("Copy Coordinates", systemImage: "doc.on.doc") { copyCoordinates() }
                .disabled(nav.fix == nil)
            if let text = nav.shareLocationText {
                ShareLink(item: text) { Label("Share My Location…", systemImage: "location") }
            }
            ShareLink(item: Brand.productPage, message: Text(Brand.shareMessage)) {
                Label("Share Bearings…", systemImage: "square.and.arrow.up")
            }
            Divider()
            Link(destination: Brand.legal) { Label("Terms & Privacy", systemImage: "doc.text") }
            Button("About Bearings", systemImage: "info.circle") { showAbout = true }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Settings and more")
    }

    private func updateBanner(_ update: (version: String, url: URL)) -> some View {
        HStack {
            Text("Bearings \(update.version) is available.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            Button("Download") { openURL(update.url) }
                .buttonStyle(LookButtonStyle())
        }
        .padding(.leading, 12).padding(.trailing, 6)
        .frame(height: 44)
        .frostedTile()
    }

    // MARK: Compass

    private func compass(side: CGFloat, big: CGFloat, k: CGFloat) -> some View {
        VStack(spacing: 4) {
            Button { nav.toggleLock() } label: {
                DialView(rotation: nav.cardRotation, heading: nav.heading, lock: nav.lock, tilt: nav.tilt,
                         sun: nav.sunPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                         moon: nav.moonPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                         moonPhase: nav.moonPhase.phase,
                         spot: nav.spotBearing.map { nav.cardAngle($0) })
                    .frame(width: side, height: side)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(dialLabel)
            .accessibilityHint(nav.heading == nil ? "" : (nav.lock == nil ? "Locks this bearing" : "Clears the locked bearing"))

            if nav.compass == .unavailable && nav.heading == nil {
                // No compass: say so where the heading would be, in the readout's own space, so nothing
                // overlaps the dial and the column keeps its rhythm.
                Text(Self.noCompassText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: 300)
                    .frame(height: big * 1.2 + 4 + 18 * k)
            } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(nav.heading.map { "\(Int($0.rounded()) % 360)°" } ?? "–°")
                    .font(.system(size: big, weight: .light))
                    .foregroundStyle(nav.heading == nil ? Color.white.opacity(Palette.Op.faint) : .white)
                    .tracking(-2)
                Text(nav.heading.map { Geo.point($0) } ?? "")
                    .font(.system(size: big / 2, weight: .medium))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .frame(minWidth: big, alignment: .leading)
            }
            .monospacedDigit()
            .lineLimit(1)
            .accessibilityHidden(true)

            // Grows with Text Size like the header and tiles; at a larger size it may wrap, but only
            // after a dot (keepTogether).
            subline
                .font(.system(size: 13 * k))
                .lineLimit(sublineWraps ? 2 : 1)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 18 * k)
            }
        }
    }

    private var dialLabel: String {
        guard let h = nav.heading else { return "Compass" }
        return "Heading \(Int(h.rounded()) % 360) degrees, \(Geo.pointName(h).lowercased())"
    }

    #if os(iOS)
    /// VoiceOver hears the heading as it changes, but no more than every few seconds.
    private func announceHeading() {
        guard UIAccessibility.isVoiceOverRunning, let h = nav.heading, Date().timeIntervalSince(lastAnnouncement) > 4 else { return }
        lastAnnouncement = Date()
        UIAccessibility.post(notification: .announcement, argument: "\(Int(h.rounded()) % 360) degrees, \(Geo.pointName(h).lowercased())")
    }
    #endif

    #if os(macOS)
    static let noCompassText = "Macs don’t have a compass. Your coordinates, elevation and map work here."
    #else
    static let noCompassText = "No compass on this device. Your coordinates, elevation and map still work."
    #endif

    /// "True north · 8° E · ±8°", or a warning in its place; then the locked bearing.
    private var subline: Text {
        guard nav.compass == .live, nav.heading != nil else { return Text(" ") }
        // A non-breaking space before the dot, so a wrapped line never starts with one.
        let dot = Text("\u{00A0}· ").foregroundColor(Color.white.opacity(Palette.Op.faint))
        let quiet = Color.white.opacity(Palette.Op.caption)
        var t: Text
        if let warning = nav.compassWarning {
            t = Text(warning).fontWeight(.semibold).foregroundColor(Palette.notice)
        } else {
            t = Text(Self.keepTogether(nav.northLabel)).foregroundColor(quiet)
            if let acc = nav.headingAccuracy {
                t = t + dot + Text("±\(Int(acc.rounded()))°").foregroundColor(quiet)
            }
        }
        if let lock = nav.lockText {
            // The locked bearing is the line's highlight: white, as every highlight inside the app.
            t = t + dot + Text(Self.keepTogether(lock)).fontWeight(.semibold).foregroundColor(.white)
        }
        return t
    }

    // MARK: Marked spot

    private func spotPill(k: CGFloat) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin")
                .font(.system(size: 14 * k, weight: .semibold))
                .foregroundStyle(.white)
            (Text("Marked spot").fontWeight(.semibold).foregroundColor(.white)
             + Text(nav.spotText.map { "\u{00A0}· " + Self.keepTogether($0) } ?? "").foregroundColor(Color.white.opacity(Palette.Op.sub)))
                .font(.system(size: 14 * k))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            Button { nav.clearSpot() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .frame(width: 44)
                    .frame(minHeight: Self.pillHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear Marked Spot")
        }
        .padding(.leading, 14)
        // At least 46, so the ✕ keeps a full target; taller only if its type needs it.
        .frame(minHeight: Self.pillHeight)
        .background(Capsule().fill(Palette.tileFill))
        .overlay(Capsule().strokeBorder(Palette.tileStroke, lineWidth: Look.stroke))
        .accessibilityElement(children: .contain)
    }

    // MARK: Tiles: latitude, longitude, elevation, sun

    @ViewBuilder
    private var tiles: some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                VStack(spacing: Self.tileGap) {
                    coordinates(stale: stale, now: context.date)
                    HStack(spacing: Self.tileGap) {
                        elevationTile(stale: stale)
                        sunTile
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                // Tiles fill their row's height (Tile), so both in a row match when one wraps; fixed
                // here, the rows take only the height they need and the map keeps the rest.
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "±16 ft · Just now"
    private func fixDetail(now: Date) -> String {
        guard let fix = nav.fix else { return nav.locating ? "Finding you…" : " " }
        let accuracy = Geo.accuracy(fix.accuracy, feet: nav.feet)
        if nav.sample { return "\(accuracy) · Sample" }
        let s = max(0, Int(now.timeIntervalSince(fix.time)))
        let age: String
        if s < 10 { age = "Just now" } else if s < 60 { age = "\(s) s ago" } else if s < 3600 { age = "\(s / 60) min ago" } else { age = "\(s / 3600) hr ago" }
        return "\(accuracy) · \(age)"
    }

    @ViewBuilder
    private func coordinates(stale: Bool, now: Date) -> some View {
        let formatted = nav.fix.map { Geo.format(nav.format, lat: $0.latitude, lon: $0.longitude) }
        switch formatted {
        case let .some(.single(text)):
            coordinateTile(Tile(title: nav.format.name, symbol: "square.grid.3x3", value: text, detail: fixDetail(now: now), stale: stale,
                                spoken: "\(nav.format.name), \(text)"))
        case let .some(.pair(lat, lon)):
            HStack(spacing: Self.tileGap) {
                coordinateTile(Tile(title: "Latitude", symbol: Tile.latitudeSymbol, value: lat, detail: fixDetail(now: now), stale: stale, spoken: "Latitude, \(lat)"))
                coordinateTile(Tile(title: "Longitude", symbol: Tile.longitudeSymbol, value: lon, detail: nav.format.name, stale: stale, spoken: "Longitude, \(lon)"))
            }
            .fixedSize(horizontal: false, vertical: true)
        case .none:
            HStack(spacing: Self.tileGap) {
                Tile(title: "Latitude", symbol: Tile.latitudeSymbol, value: "—", detail: nav.locating ? "Finding you…" : " ", stale: false)
                Tile(title: "Longitude", symbol: Tile.longitudeSymbol, value: "—", detail: " ", stale: false)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Tap to change the format, long-press to copy (right-click on a Mac).
    private func coordinateTile(_ tile: Tile) -> some View {
        tile
            .onTapGesture { nav.cycleFormat() }
            .onLongPressGesture { copyCoordinates() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Changes the coordinate format")
            .accessibilityAction(named: "Copy Coordinates") { copyCoordinates() }
            #if os(macOS)
            .contextMenu { Button("Copy Coordinates") { copyCoordinates() } }
            #endif
    }

    private func elevationTile(stale: Bool) -> some View {
        let barometer = nav.pressure.map { " · \(Geo.pressureText($0, feet: nav.feet))" } ?? ""
        switch nav.elevation {
        case let .value(metres, fromGPS, source):
            let e = Geo.elevation(metres)
            let feetWords = "\(Geo.group(metres / Geo.foot)) feet", metreWords = "\(Geo.group(metres)) metres"
            return Tile(title: "Elevation", symbol: Tile.elevationSymbol, value: nav.feet ? e.ft : e.m, secondary: nav.feet ? e.m : e.ft,
                        detail: source + barometer, stale: stale,
                        spoken: "Elevation, \(nav.feet ? feetWords : metreWords), \(nav.feet ? metreWords : feetWords), from \(fromGPS ? "GPS" : "terrain data")")
        case let .pending(text):
            return Tile(title: "Elevation", symbol: Tile.elevationSymbol, value: "—", detail: text + barometer, stale: false)
        }
    }

    /// "6:36" on a 12-hour clock (sunrise is the morning one), "06:36" on a 24-hour one: the system's own
    /// short time without AM or PM, so both times fit the tile.
    static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        var text = f.string(from: date)
        for symbol in [f.amSymbol, f.pmSymbol].compactMap({ $0 }) where !symbol.isEmpty {
            text = text.replacingOccurrences(of: symbol, with: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{202F}\u{00A0}")))
    }

    private var sunTile: some View {
        let value: String
        if let times = nav.sunTimes {
            if let rise = times.sunriseDate, let down = times.sunsetDate {
                value = "\(Self.shortTime(rise)) – \(Self.shortTime(down))"
            } else {
                value = times.polar == .day ? "Sun up all day" : "Sun down all day"
            }
        } else {
            value = "—"
        }
        let phase = nav.moonPhase
        let moon = "\(phase.name) · \(Int(Geo.jsRound(phase.fraction * 100)))%"
        return Tile(title: "Sun", symbol: "sun.max.fill", value: value, detail: moon, stale: false, moonPhase: phase.phase,
                    spoken: "Sun, \(value.replacingOccurrences(of: " – ", with: " to ")). Moon, \(moon.replacingOccurrences(of: " · ", with: ", ")) lit",
                    detailWraps: false)
    }

    private var askForLocation: some View {
        HStack(spacing: 12) {
            Text(nav.access == .denied
                 ? "Location is off for Bearings. Turn it on in Settings to see your coordinates, elevation and map."
                 : "Allow your location to see your latitude, longitude, elevation and map. It stays on this device.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(Palette.Op.body))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(nav.access == .denied ? "Settings" : "Use My Location") {
                if nav.access == .denied { openLocationSettings() } else { nav.start() }
            }
            .buttonStyle(LookButtonStyle())
            // The row is at least 44 high around the capsule (LOOK.md's compact button).
            .frame(minHeight: 44)
        }
        .padding(Look.padding)
        .frame(minHeight: 2 * Self.tileHeight + Self.tileGap)
        .frostedTile()
    }

    private func openLocationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") { openURL(url) }
        #endif
    }

    // MARK: Footer, copy, toast

    private var footer: some View {
        HStack {
            // The sky card's Sample badge already says when it's the sample place.
            Spacer()
            Link("Made by Bradley Cowdrey · bradcowdrey.com ↗", destination: Brand.website)
                .foregroundStyle(Color.white.opacity(Palette.Op.caption))
        }
        .font(.system(size: 12))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .frame(height: 16)
    }

    private func copyCoordinates() {
        guard let text = nav.copyText else { return }
        #if os(iOS)
        UIPasteboard.general.string = text
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
        show("Coordinates copied")
    }

    private func show(_ text: String) {
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeIn(duration: 0.2)) { if toast == text { toast = nil } }
        }
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(Capsule().fill(Color.white))
                .padding(.bottom, 28)
                .transition(.opacity)
        }
    }
}

/// How much larger the column's type is: the system's Text Size (up to 1.3) times the wider iPad and Mac
/// column (1.15). 1 on a phone at the default size.
private struct UIScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
/// The wider iPad and Mac column alone (1.15, or 1 on a phone), for spacing that shouldn't grow with
/// Text Size.
private struct UIWideKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues {
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
    var uiWide: CGFloat {
        get { self[UIWideKey.self] }
        set { self[UIWideKey.self] = newValue }
    }
}

/// One frosted tile, as Two Degrees': a small uppercase caption with its symbol, a value (with an optional
/// second unit), and a detail line, read by VoiceOver as one sentence.
struct Tile: View {
    static let latitudeSymbol = "arrow.up.and.down"
    static let longitudeSymbol = "arrow.left.and.right"
    static let elevationSymbol = "mountain.2.fill"

    /// In normal case ("Latitude"): shown in capitals, spoken as written.
    var title: String
    /// The caption's SF Symbol.
    var symbol: String
    var value: String
    var secondary: String? = nil
    var detail: String
    var stale: Bool
    /// The moon's phase, drawn before the detail (the Sun tile).
    var moonPhase: Double? = nil
    /// What VoiceOver says; the tile's text when nil.
    var spoken: String? = nil
    /// Whether the detail may wrap at a larger Text Size (the moon's line reads better shrunk on one line).
    var detailWraps: Bool = true
    @Environment(\.uiScale) private var k
    @Environment(\.uiWide) private var wide

    var body: some View {
        VStack(alignment: .leading, spacing: 2 * k) {
            CardCaption(title, symbol, size: Look.captionSize * k)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: Look.valueSize * k, weight: .medium))
                    .foregroundStyle(stale ? Color.white.opacity(Palette.Op.caption) : .white)
                if let secondary {
                    Text(secondary)
                        .font(.system(size: 14 * k, weight: .medium))
                        .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            HStack(spacing: 5) {
                if let moonPhase { MoonGlyph(phase: moonPhase, size: 12 * k) }
                // Numbers stay with their units, and a wrap comes only after a dot.
                Text(MainView.keepTogether(detail))
                    .font(.system(size: 12 * k))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    // At a larger Text Size the detail wraps rather than being cut off.
                    .lineLimit(k > 1.1 && detailWraps ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: detailWraps)
                    .minimumScaleFactor(detailWraps ? 0.85 : 0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        // The spec's 14 × 12 at every Text Size (only the wider iPad and Mac column scales it), so a
        // larger size doesn't take room from the text.
        .padding(.horizontal, 14 * wide).padding(.vertical, 12 * wide)
        // Fills the row's height, so two tiles side by side match when one wraps (rows are fixed in tiles).
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frostedTile()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken ?? "\(title), \(value)\(secondary.map { ", \($0)" } ?? ""), \(detail)")
    }
}
