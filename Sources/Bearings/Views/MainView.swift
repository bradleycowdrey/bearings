import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Bearings' one screen (docs/LAYOUTS.md). The **head** never scrolls: the sky, the dial, the readout, the
/// subline and, when a spot is marked, the spot line. Under it, **Details** scrolls: a summary strip, the
/// map, the 2 × 2 tiles and (Mac and iPad) the footer. The dial is sized first, as a share of the screen's
/// height set by the Layout setting (LayoutPlan); wide windows put Details in a column beside the dial. The
/// same view on Mac, iPhone and iPad, in Two Degrees' look (docs/LOOK.md): black, a large title, a sky
/// card, frosted tiles with uppercase captions, and white highlights.
struct MainView: View {
    @EnvironmentObject private var nav: Navigator
    /// "Bearings 0.2.0 is available" on the Mac (nil elsewhere).
    var update: (version: String, url: URL)?
    @State private var toast: String?
    @State private var showAbout = false
    /// Details has more below its bottom edge (the fade shows).
    @State private var moreBelow = false
    @Environment(\.openURL) private var openURL
    /// Details as a plain clipped stack, for ImageRenderer (the Mac self-test), which can't draw a ScrollView.
    @Environment(\.flatDetails) private var flatDetails
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var lastAnnouncement = Date.distantPast
    #endif

    /// Night mode's red: multiplied over everything, so whites turn red and nothing stays blue or green.
    static let nightTint = Color(red: 1, green: 0.18, blue: 0.12)

    // The grid (DESIGN.md, docs/LOOK.md): margins 16, tiles 8 apart; the gaps between blocks come from the plan.
    private static let margin: CGFloat = Look.margin
    private static let tileGap: CGFloat = Look.tileGap
    private static let tileHeight: CGFloat = 84
    /// Scroll targets inside Details.
    private static let topID = "details.top"
    private static let tilesID = "details.tiles"
    private static let detailsSpace = "details"

    /// The footer under the tiles: on the Mac and a wide iPad; on a phone it's in About.
    private var showsFooter: Bool {
        #if os(iOS)
        sizeClass == .regular
        #else
        true
        #endif
    }

    /// The system's Text Size, as a multiplier on the header and tiles: 1 at the default size, up to 1.3.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    /// Text Size alone, capped at 1.3 (the planner's `k`).
    private var textK: CGFloat { min(max(textScale, 1), LayoutPlan.maxK) }

    /// A marked spot with a fix: the spot line shows under the readout.
    private var hasSpotLine: Bool { nav.spot != nil && nav.fix != nil }

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
            let plan = makePlan(for: geo)
            Group {
                if plan.twoPane {
                    twoPanes(plan)
                } else {
                    singleColumn(plan)
                }
            }
            .environment(\.uiScale, plan.k)
            .environment(\.uiWide, plan.wide)
            // Choosing a layout animates it (a 0.35 s spring); with Reduce Motion it just changes.
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: nav.layout)
        }
        .background(Palette.screen.ignoresSafeArea())
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) { toastView }
        // No accent colour inside the app: the menu's checks and the alert's buttons are white.
        .tint(.white)
        .environment(\.colorScheme, .dark)
        // Night mode covers the whole stack: the head, the sky bar and Details.
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

    // MARK: The plan

    /// The planner's answer for this window: H is the full height (safe area included, what a screenshot
    /// shows), S the safe height inside which everything is laid out.
    private func makePlan(for geo: GeometryProxy) -> LayoutPlan {
        let w = geo.size.width, s = geo.size.height
        let h = s + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
        #if os(iOS)
        // An iPhone on its side (every iPhone is vertically compact in landscape).
        let landscapePhone = verticalSizeClass == .compact && w > s
        #else
        let landscapePhone = false
        #endif
        return LayoutPlan.plan(w: w, h: h, s: s, layout: nav.layout, k: textK,
                               accessibilityText: typeSize.isAccessibilitySize, hasSpot: hasSpotLine,
                               hasUpdateBanner: update != nil, showsFooter: showsFooter,
                               isLandscapePhone: landscapePhone)
    }

    /// One column, C = min(W, 760) wide: the head, then Details filling the height left. When even the
    /// dial at its floor leaves too little (an accessibility Text Size on a small phone), both scroll as one.
    @ViewBuilder
    private func singleColumn(_ plan: LayoutPlan) -> some View {
        Group {
            if plan.scrollsWhole && !flatDetails {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: plan.gap) {
                            head(plan)
                                .id(Self.topID)
                            detailsContent(plan, viewport: plan.detailsViewport) { scrollToTiles(proxy) }
                        }
                        .padding(.top, LayoutPlan.top)
                        .padding(.bottom, LayoutPlan.bottom)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicatorsFlash(onAppear: true)
                    .onChange(of: nav.layout) { proxy.scrollTo(Self.topID, anchor: .top) }
                }
            } else {
                VStack(spacing: 0) {
                    head(plan)
                        .padding(.top, LayoutPlan.top)
                        .padding(.bottom, plan.gap)
                    detailsArea(plan)
                        .padding(.bottom, LayoutPlan.bottom)
                }
            }
        }
        .frame(maxWidth: plan.columnWidth)
        .frame(maxWidth: .infinity)
    }

    /// Wide windows and phones on their side: the head centred in a leading pane, and the title row with
    /// Details in a trailing column (clamp(W × c, 300, 440) wide, narrower for the larger layouts).
    private func twoPanes(_ plan: LayoutPlan) -> some View {
        HStack(spacing: 0) {
            Group {
                if plan.scrollsWhole && !flatDetails {
                    ScrollView {
                        head(plan)
                            .padding(.top, LayoutPlan.top)
                            .padding(.bottom, LayoutPlan.bottom)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                } else {
                    head(plan)
                        .padding(.top, LayoutPlan.top)
                        .padding(.bottom, LayoutPlan.bottom)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: LayoutPlan.titleSpace) {
                titleRow(plan)
                    .padding(.horizontal, Self.margin)
                if let update {
                    updateBanner(update)
                        .padding(.horizontal, Self.margin)
                }
                detailsArea(plan)
            }
            .padding(.top, LayoutPlan.top)
            .padding(.bottom, LayoutPlan.bottom)
            .frame(width: plan.trailingWidth)
        }
    }

    // MARK: The head

    /// The sky (with the title row above it in a single column, when it fits), the dial, the readout and
    /// subline, and the spot line. Nothing that changes what the dial shows ever leaves the head.
    private func head(_ plan: LayoutPlan) -> some View {
        VStack(spacing: plan.gap) {
            VStack(spacing: LayoutPlan.titleSpace) {
                if !plan.twoPane && plan.header == .titleRowAndCard { titleRow(plan) }
                if !plan.twoPane, let update { updateBanner(update) }
                if plan.header == .bar {
                    skyBar(plan)
                } else {
                    skyCard(plan)
                }
            }
            .padding(.horizontal, Self.margin)
            compass(plan)
            if hasSpotLine {
                spotLine(plan)
                    .padding(.horizontal, Self.margin)
            }
        }
    }

    // MARK: Title and sky

    /// "Bearings", large, with the ⋯ menu at the right (as Two Degrees' and Meridian's lists).
    private func titleRow(_ plan: LayoutPlan) -> some View {
        HStack(spacing: 12) {
            Text(Brand.appName)
                .font(.system(size: Look.titleSize * plan.wide, weight: .bold))
                .tracking(0.4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            menu
        }
        .frame(height: LayoutPlan.titleHeight(wide: plan.wide))
    }

    /// Where you are and the time, on the sky for the sun's altitude here (Two Degrees' city card). With no
    /// title row, the ⋯ menu takes the corner symbol's place.
    private func skyCard(_ plan: LayoutPlan) -> some View {
        let k = plan.k, compact = plan.menuInSky
        return HStack(alignment: .top, spacing: 12) {
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
                    if nav.sample { sampleBadge(k: k) }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if compact {
                menu
            } else {
                skySymbol
            }
        }
        .foregroundStyle(.white)
        .padding(compact ? 12 : Look.skyPadding)
        // Grows with Text Size as its type does (and as the planner budgets it).
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: LayoutPlan.skyCardHeight(k: k, compact: compact), alignment: .top)
        .skyCard(altitude: nav.sunPosition?.altitude)
    }

    /// Extra Large (or a squeezed window): one line on the same sky, "Crested Butte · Sat, Nov 7 · 4:12 PM",
    /// the sun or moon symbol, and the ⋯ menu at the end in its 44 × 44 target. The place truncates first.
    private func skyBar(_ plan: LayoutPlan) -> some View {
        let k = plan.k
        return HStack(spacing: 8) {
            HStack(spacing: 0) {
                Text(nav.placeTitle)
                    .font(.system(size: 15 * k, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(0)
                Text("\u{00A0}· \(dateLine)")
                    .font(.system(size: 15 * k))
                    .foregroundStyle(Color.white.opacity(Palette.Op.body))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                    .layoutPriority(1)
                if nav.sample {
                    sampleBadge(k: k)
                        .padding(.leading, 6)
                        .fixedSize()
                        .layoutPriority(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            skySymbol
            if plan.menuInSky { menu }
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, plan.menuInSky ? 0 : 14)
        .frame(maxWidth: .infinity)
        .frame(height: LayoutPlan.skyBarHeight(k: k))
        .skyCard(altitude: nav.sunPosition?.altitude)
    }

    /// The sun, sunrise or sunset, or moon symbol in the sky's corner (decorative).
    private var skySymbol: some View {
        Image(systemName: SkyTone.symbol(for: nav.sunPosition))
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Color.white.opacity(Palette.Op.body))
            .accessibilityHidden(true)
    }

    /// 11 is the smallest text size; it grows with the date beside it.
    private func sampleBadge(k: CGFloat) -> some View {
        Text("Sample")
            .font(.system(size: 11 * k, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(Palette.notice))
    }

    /// "Sat, Nov 1 · 9:41 AM", in the device's 12- or 24-hour style.
    private var dateLine: String {
        let day = nav.now.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        return "\(day) · \(nav.now.formatted(date: .omitted, time: .shortened))"
    }

    /// The ⋯ menu; for ImageRenderer (`flatDetails`, the Mac self-test), which can't draw a menu, its symbol alone.
    @ViewBuilder
    private var menu: some View {
        if flatDetails {
            menuSymbol
                .accessibilityLabel("Settings and more")
        } else {
            settingsMenu
        }
    }

    private var menuSymbol: some View {
        Image(systemName: "ellipsis.circle")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private var settingsMenu: some View {
        Menu {
            // The first group: how large the compass is (a submenu showing the current choice).
            Picker("Layout", selection: $nav.layout) {
                ForEach(Layout.allCases) { Text($0.name).tag($0) }
            }
            .pickerStyle(.menu)
            Divider()
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
                Button("Open in Maps", systemImage: "map") {
                    if let fix = nav.fix { openURL(Navigator.mapsURL(fix)) }
                }
                .disabled(nav.fix == nil)
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
            menuSymbol
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
        .frame(height: LayoutPlan.banner)
        .frostedTile()
    }

    // MARK: Compass

    private func compass(_ plan: LayoutPlan) -> some View {
        let big = plan.headingSize, k = plan.k
        let readoutHeight = LayoutPlan.readoutHeight(headingSize: big)
        let sublineHeight = LayoutPlan.sublineHeight(k: k, wraps: false)
        return VStack(spacing: 4) {
            dial(side: plan.dial)

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
                    .frame(height: readoutHeight + 4 + sublineHeight)
                    .padding(.horizontal, Self.margin)
            } else {
                // The readout and the subline are read as one element, after the dial.
                VStack(spacing: 4) {
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
                    .frame(height: readoutHeight)

                    // Grows with Text Size like the header and tiles; at a larger size it may wrap, but only
                    // after a dot (keepTogether).
                    subline
                        .font(.system(size: 13 * k))
                        .lineLimit(plan.sublineWraps ? 2 : 1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: sublineHeight)
                        .padding(.horizontal, Self.margin)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The dial: tap to lock or unlock the bearing; pinch to step the layout; VoiceOver reads it as one
    /// element with its custom actions.
    private func dial(side: CGFloat) -> some View {
        Button { nav.toggleLock() } label: {
            DialView(rotation: nav.cardRotation, heading: nav.heading, lock: nav.lock, tilt: nav.tilt,
                     sun: nav.sunPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                     moon: nav.moonPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                     moonPhase: nav.moonPhase.phase,
                     spot: nav.spotBearing.map { nav.cardAngle($0) })
                .frame(width: side, height: side)
        }
        .buttonStyle(.plain)
        // A pinch steps one layout (only a shortcut: the setting is in the ⋯ menu).
        .simultaneousGesture(MagnifyGesture().onEnded { pinch($0.magnification) })
        .accessibilityLabel("Compass")
        .accessibilityValue(dialValue)
        .accessibilityHint(nav.heading == nil ? "" : (nav.lock == nil ? "Locks this bearing" : "Clears the locked bearing"))
        .accessibilityActions {
            if nav.heading != nil {
                Button(nav.lock == nil ? "Lock Bearing" : "Unlock Bearing") { nav.toggleLock() }
            }
            if nav.layout.larger != nil {
                Button("Larger Compass") { stepLayout(larger: true) }
            }
            if nav.layout.smaller != nil {
                Button("Smaller Compass") { stepLayout(larger: false) }
            }
        }
    }

    /// Scale over 1.12 is one layout larger, under 0.89 one smaller.
    private func pinch(_ scale: CGFloat) {
        if scale > 1.12 { stepLayout(larger: true) } else if scale < 0.89 { stepLayout(larger: false) }
    }

    private func stepLayout(larger: Bool) {
        guard nav.stepLayout(larger: larger) else { return }
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
        show("Layout: \(nav.layout.name)")
    }

    /// "Heading 228 degrees, southwest. True north. Sun 245 degrees, up. Moon 110 degrees, down. Marked
    /// spot 0.4 miles at 245 degrees. Locked 240, turn 12 right." (Only the parts that apply.)
    private var dialValue: String {
        var parts: [String] = []
        if let h = nav.heading {
            parts.append("Heading \(Int(h.rounded()) % 360) degrees, \(Geo.pointName(h).lowercased())")
            parts.append(nav.usingTrueNorth ? "True north" : "Magnetic north")
        } else if nav.compass == .unavailable {
            parts.append("No compass")
        }
        if let sun = nav.sunPosition {
            parts.append("Sun \(Int(Geo.jsRound(nav.cardAngle(sun.azimuth))) % 360) degrees, \(sun.altitude > 0 ? "up" : "down")")
        }
        if let moon = nav.moonPosition {
            parts.append("Moon \(Int(Geo.jsRound(nav.cardAngle(moon.azimuth))) % 360) degrees, \(moon.altitude > 0 ? "up" : "down")")
        }
        if let d = nav.spotDistance, let b = nav.spotBearing {
            parts.append("Marked spot \(Self.spoken(Geo.distanceText(d, feet: nav.feet))) at \(Int(Geo.jsRound(nav.cardAngle(b))) % 360) degrees")
        }
        if let lock = nav.lockText {
            parts.append(lock.replacingOccurrences(of: "°", with: "").replacingOccurrences(of: " · ", with: ", "))
        } else if let lock = nav.lock {
            parts.append("Locked \(Int(lock.rounded()) % 360)")
        }
        return parts.isEmpty ? "" : parts.joined(separator: ". ") + "."
    }

    /// Units as words, for VoiceOver: "0.4 mi" → "0.4 miles", "1,013 hPa" → "1,013 hectopascals".
    static func spoken(_ text: String) -> String {
        let words = ["mi": "miles", "km": "kilometres", "ft": "feet", "m": "metres", "hPa": "hectopascals", "inHg": "inches of mercury"]
        return text.split(separator: " ").map { words[String($0)] ?? String($0) }.joined(separator: " ")
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

    /// One line, 28 high: "Marked spot · 0.4 mi · 245° SW". The line opens a small menu (Lock to Spot, Clear
    /// Marked Spot); the ✕ clears it, with a 44 × 44 target that reaches into the gaps around the line.
    private func spotLine(_ plan: LayoutPlan) -> some View {
        let k = plan.k, height = LayoutPlan.spotHeight(k: k)
        let details = nav.spotText ?? ""
        // "0.4 miles, 245 degrees southwest" (the point in words, as the dial's value says it).
        let spokenDetails: String
        if let d = nav.spotDistance, let b = nav.spotBearing {
            let shown = nav.cardAngle(b)
            spokenDetails = "\(Self.spoken(Geo.distanceText(d, feet: nav.feet))), \(Int(Geo.jsRound(shown)) % 360) degrees \(Geo.pointName(shown).lowercased())"
        } else {
            spokenDetails = Self.spoken(details.replacingOccurrences(of: " · ", with: ", ").replacingOccurrences(of: "°", with: " degrees"))
        }
        return HStack(spacing: 0) {
            // Balances the ✕, so the line stays centred under the readout.
            Color.clear.frame(width: 44, height: 1).accessibilityHidden(true)
            // ImageRenderer can't draw a menu (the Mac self-test): the line alone there.
            if flatDetails {
                spotLineLabel(details: details, k: k, height: height)
            } else {
                Menu {
                    Button("Lock to Spot", systemImage: "scope") { nav.lockToSpot() }
                    Button("Clear Marked Spot", systemImage: "mappin.slash") { nav.clearSpot() }
                } label: {
                    spotLineLabel(details: details, k: k, height: height)
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
                .menuIndicator(.hidden)
                .accessibilityLabel("Marked spot, \(spokenDetails)")
                .accessibilityActions {
                    Button("Lock to Spot") { nav.lockToSpot() }
                    Button("Clear") { nav.clearSpot() }
                }
            }
            Button { nav.clearSpot() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Laid out in the line's height; its 44 target spills into the gaps above and below.
            .frame(width: 44, height: height)
            .accessibilityLabel("Clear Marked Spot")
        }
        .frame(height: height)
    }

    /// "📍 Marked spot · 0.4 mi · 245° SW", centred in the line.
    private func spotLineLabel(details: String, k: CGFloat, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin")
                .font(.system(size: 15 * k, weight: .semibold))
            (Text("Marked spot") + Text(details.isEmpty ? "" : "\u{00A0}· " + Self.keepTogether(details)))
                .font(.system(size: 15 * k, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: height)
        .contentShape(Rectangle())
    }

    // MARK: Details

    /// The scrolling area under the head (or in the trailing column): it fills the height left. A fade at
    /// the bottom while more is below, the scroll bar flashes once, nothing bounces when it all fits, and
    /// changing the layout scrolls back to the top. For ImageRenderer (`flatDetails`), a plain stack clipped
    /// to the same height.
    private func detailsArea(_ plan: LayoutPlan) -> some View {
        GeometryReader { area in
            let viewport = area.size.height
            if flatDetails {
                detailsContent(plan, viewport: viewport) {}
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: area.size.width, height: viewport, alignment: .top)
                    .clipped()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        detailsContent(plan, viewport: viewport) { scrollToTiles(proxy) }
                            .background(GeometryReader { content in
                                Color.clear.preference(key: DetailsBottomKey.self,
                                                       value: content.frame(in: .named(Self.detailsSpace)).maxY)
                            })
                    }
                    .coordinateSpace(.named(Self.detailsSpace))
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollIndicatorsFlash(onAppear: true)
                    .onPreferenceChange(DetailsBottomKey.self) { bottom in moreBelow = bottom > viewport + 1 }
                    .overlay(alignment: .bottom) {
                        if moreBelow {
                            LinearGradient(colors: [Palette.screen.opacity(0), Palette.screen], startPoint: .top, endPoint: .bottom)
                                .frame(height: 16)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    .onChange(of: nav.layout) { proxy.scrollTo(Self.topID, anchor: .top) }
                }
            }
        }
    }

    private func scrollToTiles(_ proxy: ScrollViewProxy) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { proxy.scrollTo(Self.tilesID, anchor: .top) }
    }

    /// Top to bottom: the summary strip, the map card, "DETAILS" and the 2 × 2 tiles, and the footer.
    /// Small's map fills what's left of the first screen (at least 96); Medium's starts right after the strip,
    /// its top peeking; Large's and Extra Large's wait below the fold, with calm space under the strip.
    private func detailsContent(_ plan: LayoutPlan, viewport: CGFloat, scrollToTiles: @escaping () -> Void) -> some View {
        let stripHeight = LayoutPlan.stripHeight(k: plan.k)
        return VStack(alignment: .leading, spacing: plan.gap) {
            strip(plan, scrollToTiles: scrollToTiles)
                .id(plan.scrollsWhole && !plan.twoPane ? "details.strip" : Self.topID)
            if plan.mapOnFirstScreen {
                map.frame(height: max(LayoutPlan.mapMin, viewport - stripHeight - plan.gap))
            } else {
                if !plan.mapPeeks {
                    Color.clear
                        .frame(height: max(0, viewport - stripHeight - 2 * plan.gap))
                        .accessibilityHidden(true)
                }
                map.frame(height: LayoutPlan.map)
            }
            VStack(alignment: .leading, spacing: Self.tileGap) {
                Text("Details".uppercased())
                    .font(.system(size: Look.captionSize * plan.k, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .accessibilityLabel("Details")
                    .accessibilityAddTraits(.isHeader)
                tiles
            }
            .id(Self.tilesID)
            if plan.showsFooter { footer }
        }
        .padding(.horizontal, Self.margin)
    }

    private var map: some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                   speed: nav.speed.map { Geo.speedText($0, feet: nav.feet) }, dimmed: nav.nightMode)
    }

    // MARK: Summary strip

    /// One row, 64 high, frosted: the coordinates (two units wide), the elevation and the sun, divided by
    /// hairlines. At accessibility Text Sizes it becomes a list, one cell under another.
    private func strip(_ plan: LayoutPlan, scrollToTiles: @escaping () -> Void) -> some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
            let k = plan.k
            Group {
                if plan.accessibilityText {
                    VStack(alignment: .leading, spacing: 0) {
                        coordinateCell(k: k, stale: stale)
                            .padding(.vertical, 10)
                        Rectangle().fill(Palette.tileStroke).frame(height: Look.stroke)
                        elevationCell(k: k, scrollToTiles: scrollToTiles)
                            .padding(.vertical, 10)
                        Rectangle().fill(Palette.tileStroke).frame(height: Look.stroke)
                        sunCell(k: k, scrollToTiles: scrollToTiles)
                            .padding(.vertical, 10)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                    // Two equal halves: the coordinates, then elevation and sun sharing the other half.
                    HStack(spacing: 0) {
                        coordinateCell(k: k, stale: stale)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        Rectangle().fill(Palette.tileStroke).frame(width: Look.stroke)
                        HStack(spacing: 0) {
                            elevationCell(k: k, scrollToTiles: scrollToTiles)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            Rectangle().fill(Palette.tileStroke).frame(width: Look.stroke)
                            sunCell(k: k, scrollToTiles: scrollToTiles)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(.vertical, 10)
                    .frame(height: LayoutPlan.stripHeight(k: k))
                }
            }
            .frostedTile()
        }
    }

    /// The coordinates in the current format: latitude over longitude, or one grid reference on one or two
    /// lines. Tap for the next format, long-press to copy (as the Latitude and Longitude tiles).
    private func coordinateCell(k: CGFloat, stale: Bool) -> some View {
        let formatted = nav.fix.map { Geo.format(nav.format, lat: $0.latitude, lon: $0.longitude) }
        let text: String
        let spokenValue: String
        switch formatted {
        case let .some(.pair(lat, lon)):
            text = "\(lat)\n\(lon)"
            spokenValue = "\(Self.spokenCoordinate(lat)), \(Self.spokenCoordinate(lon))"
        case let .some(.single(value)):
            text = value
            spokenValue = value
        case .none:
            text = "—"
            spokenValue = nav.locating ? "finding you" : "not known yet"
        }
        // "decimal degrees", but "UTM" and "MGRS" stay in capitals so they're spelled out.
        let name = nav.format.name
        let formatWords = name == name.uppercased() ? name : name.lowercased()
        return CoordinateText(copyAction: "Copy", copy: copyCoordinates) {
            Text(text)
                .font(.system(size: 17 * k, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(stale ? Color.white.opacity(Palette.Op.caption) : .white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Coordinates, \(spokenValue), \(formatWords)")
        }
    }

    /// "39.09898° N" → "39.09898 north" (degree, minute and second marks read as numbers).
    static func spokenCoordinate(_ text: String) -> String {
        let hemispheres = ["N": "north", "S": "south", "E": "east", "W": "west"]
        let parts = text.split(separator: " ").map(String.init)
        guard let last = parts.last, let word = hemispheres[last] else { return text }
        let number = parts.dropLast().joined(separator: " ")
            .replacingOccurrences(of: "°", with: " degrees")
            .replacingOccurrences(of: "′", with: " minutes")
            .replacingOccurrences(of: "″", with: " seconds")
        return "\(number) \(word)"
    }

    /// "9,596 ft" over "2,925 m" (metres first when chosen). Tap: scrolls to the tiles.
    private func elevationCell(k: CGFloat, scrollToTiles: @escaping () -> Void) -> some View {
        let main: String, second: String, spokenText: String
        switch nav.elevation {
        case let .value(metres, fromGPS, _):
            let e = Geo.elevation(metres)
            main = nav.feet ? e.ft : e.m
            second = nav.feet ? e.m : e.ft
            let feetWords = "\(Geo.group(metres / Geo.foot)) feet", metreWords = "\(Geo.group(metres)) metres"
            let pressure = nav.pressure.map { ", pressure \(Self.spoken(Geo.pressureText($0, feet: nav.feet)))" } ?? ""
            spokenText = "Elevation, \(nav.feet ? feetWords : metreWords), \(nav.feet ? metreWords : feetWords), from \(fromGPS ? "GPS" : "terrain data")\(pressure)"
        case let .pending(text):
            main = "—"
            second = " "
            spokenText = "Elevation, \(text.trimmingCharacters(in: .whitespaces).isEmpty ? "not known yet" : text)"
        }
        return Button(action: scrollToTiles) {
            VStack(alignment: .leading, spacing: 1) {
                Text(main)
                    .font(.system(size: 17 * k, weight: .medium))
                    .foregroundStyle(.white)
                Text(second)
                    .font(.system(size: 13 * k))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spokenText)
        .accessibilityHint("Shows the details")
    }

    /// "6:42–5:01" over the moon and "82%". Tap: scrolls to the tiles.
    private func sunCell(k: CGFloat, scrollToTiles: @escaping () -> Void) -> some View {
        let value: String, spokenSun: String
        if let times = nav.sunTimes {
            if let rise = times.sunriseDate, let down = times.sunsetDate {
                value = "\(Self.shortTime(rise))–\(Self.shortTime(down))"
                spokenSun = "rises \(rise.formatted(date: .omitted, time: .shortened)), sets \(down.formatted(date: .omitted, time: .shortened))"
            } else {
                value = times.polar == .day ? "Up all day" : "Down all day"
                spokenSun = times.polar == .day ? "up all day" : "down all day"
            }
        } else {
            value = "—"
            spokenSun = "not known yet"
        }
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        return Button(action: scrollToTiles) {
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 15 * k, weight: .medium))
                    .foregroundStyle(.white)
                HStack(spacing: 4) {
                    MoonGlyph(phase: phase.phase, size: 12 * k)
                    Text("\(percent)%")
                        .font(.system(size: 13 * k))
                        .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sun, \(spokenSun), moon \(phase.name.lowercased()), \(percent) percent")
        .accessibilityHint("Shows the details")
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
                // here, the rows take only the height they need.
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

    /// Tap to change the format, long-press to copy (right-click on a Mac): the same as the strip's cell.
    private func coordinateTile(_ tile: Tile) -> some View {
        CoordinateText(copy: copyCoordinates) { tile }
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
        show("Coordinates copied", for: 1.2)
    }

    private func show(_ text: String, for seconds: Double = 1.6) {
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(seconds))
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

/// One place for the coordinates' tap and long-press, shared by the summary strip's cell and the Latitude
/// and Longitude tiles so they behave the same: tap for the next of the six formats, long-press to copy
/// ("Coordinates copied"), right-click › Copy Coordinates on a Mac, and the same as VoiceOver actions.
/// The content is expected to be one accessibility element already (a Tile, or a labelled cell).
struct CoordinateText<Content: View>: View {
    @EnvironmentObject private var nav: Navigator
    private let copyAction: String
    private let copy: () -> Void
    private let content: Content

    init(copyAction: String = "Copy Coordinates", copy: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.copyAction = copyAction
        self.copy = copy
        self.content = content()
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { nav.cycleFormat() }
            .onLongPressGesture { copy() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Changes the coordinate format")
            .accessibilityAction(named: "Next Format") { nav.cycleFormat() }
            .accessibilityAction(named: copyAction) { copy() }
            #if os(macOS)
            .contextMenu { Button("Copy Coordinates") { copy() } }
            #endif
    }
}

/// The bottom of Details' content in its scroll view, to know whether more is below the fold.
private struct DetailsBottomKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Details drawn as a plain stack clipped to its height instead of a ScrollView: ImageRenderer can't draw a
/// ScrollView (the Mac self-test sets it). False everywhere else.
private struct FlatDetailsKey: EnvironmentKey { static let defaultValue = false }

/// How much larger the column's type is: the system's Text Size (up to 1.3) times the wider iPad and Mac
/// column (1.15). 1 on a phone at the default size.
private struct UIScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
/// The wider iPad and Mac column alone (1.15, or 1 on a phone), for spacing that shouldn't grow with
/// Text Size.
private struct UIWideKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues {
    var flatDetails: Bool {
        get { self[FlatDetailsKey.self] }
        set { self[FlatDetailsKey.self] = newValue }
    }
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
