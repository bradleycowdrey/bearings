import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

#if os(iOS)
fileprivate typealias PlatformFont = UIFont
#else
fileprivate typealias PlatformFont = NSFont
#endif

/// Bearings' one screen, the "Instrument panel" (docs/REFINE.md §3 and Cycle 2): one fixed, non-scrolling
/// screen of header bar → dial (the hero) → readout → status line → lock row → spot row → tile grid → map
/// card (only where it fits whole). Each fact appears once, in one tile component (caption pinned to the
/// top, value block to the bottom, as the widgets). The planner (LayoutPlan) places everything bottom-up so
/// nothing is empty and nothing is cut; no value is ever ellipsized (it scales to 0.85, then wraps); at
/// accessibility text sizes the whole screen becomes one scrolling list. Wide windows and phones on their
/// side get two panes under one header. The same view on Mac, iPhone and iPad, in Two Degrees' look
/// (docs/LOOK.md).
struct MainView: View {
    @EnvironmentObject private var nav: Navigator
    /// "Bearings 0.2.0 is available" on the Mac (nil elsewhere).
    var update: (version: String, url: URL)?
    @State private var toast: String?
    @State private var showAbout = false
    @State private var showDetails = false
    @Environment(\.openURL) private var openURL
    /// Drawn for ImageRenderer (the Mac self-test), which can't draw a ScrollView or a menu.
    @Environment(\.flatDetails) private var flatDetails
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    #if os(iOS)
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var lastAnnouncement = Date.distantPast
    @State private var announcedNoCompass = false
    #endif

    /// Night mode's red: multiplied over everything, so whites turn red and nothing stays blue or green.
    static let nightTint = Palette.nightTint

    private static let gap = LayoutPlan.rowGap

    /// A Mac window: 16 in from every edge (24 at widths of 600 or more).
    private static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// The system's Text Size, as a multiplier on the header, status line and tiles: 1 at the default size.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    /// Text Size alone, capped at 1.3 (the planner's `k`).
    private var textK: CGFloat { min(max(textScale, 1), LayoutPlan.maxK) }

    /// A marked spot with a fix: the spot row shows above the grid.
    private var hasSpotRow: Bool { nav.spot != nil && nav.fix != nil }

    /// Secondary text: white at 60%, brighter at night (§4.3).
    private var secondary: Color { Palette.secondary(night: nav.nightMode) }

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
            // What each layout gives on this screen, for the Layout menu ("Dial 386 · map in header").
            let subtitles = Dictionary(uniqueKeysWithValues: Layout.allCases.map { ($0, makePlan(for: geo, layout: $0).menuSubtitle) })
            Group {
                if plan.list {
                    listScreen(plan, subtitles: subtitles)
                } else if plan.twoPane {
                    twoPanes(plan, subtitles: subtitles)
                } else {
                    singleColumn(plan, subtitles: subtitles)
                }
            }
            .environment(\.uiScale, plan.k)
            .environment(\.nightText, nav.nightMode)
            // Choosing a layout animates it (a 0.35 s spring); with Reduce Motion it just changes.
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: nav.layout)
        }
        .background(Palette.screen.ignoresSafeArea())
        .foregroundStyle(.white)
        .overlay(alignment: .bottom) { toastView }
        // No accent colour inside the app: the menu's checks and the alert's buttons are white.
        .tint(.white)
        .environment(\.colorScheme, .dark)
        // Night mode covers the whole screen: the header, the dial, the tiles and the map.
        .colorMultiply(nav.nightMode ? Self.nightTint : .white)
        #if os(iOS)
        .onChange(of: nav.heading.map { Int($0 / 15) }) { announceHeading() }
        .onChange(of: nav.noCompass) { announceNoCompass() }
        #endif
        .sheet(isPresented: $nav.mapSheet) { mapSheet }
        .sheet(isPresented: $showDetails) { detailsSheet }
        .alert("Bearings", isPresented: $showAbout) {
            Button("Source Code") { openURL(Brand.repository) }
            Button("Done", role: .cancel) {}
        } message: {
            Text("\(Brand.tagline)\nFree, open source, no ads, no tracking.\n\nMade by \(Brand.author) · bradcowdrey.com\n\nGround elevation: Open-Meteo (CC BY 4.0), Copernicus DEM GLO-90 © DLR/ESA. Place names: GeoNames (CC BY 4.0). Sun and moon after SunCalc. Map: Apple Maps.\nVersion \(Self.version)")
        }
    }

    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev" }

    // MARK: The plan

    /// The planner's answer for this window (in `layout`, or the chosen one): H is the full height (safe
    /// area included, what a screenshot shows), S the safe height inside which everything is laid out.
    private func makePlan(for geo: GeometryProxy, layout: Layout? = nil) -> LayoutPlan {
        let w = geo.size.width, s = geo.size.height
        let h = s + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
        #if os(iOS)
        // An iPhone on its side (every iPhone is vertically compact in landscape).
        let landscapePhone = verticalSizeClass == .compact && w > s
        #else
        let landscapePhone = false
        #endif
        return LayoutPlan.plan(w: w, h: h, s: s, layout: layout ?? nav.layout, k: textK,
                               accessibilityText: typeSize.isAccessibilitySize, hasSpot: hasSpotRow,
                               locked: nav.lockText != nil, noCompass: nav.noCompass,
                               hasUpdateBanner: update != nil, mac: Self.isMac,
                               isLandscapePhone: landscapePhone)
    }

    // MARK: The three arrangements

    /// One column, C = min(W − 2 × margin, 640) wide, centred: every block at its planned height, so the
    /// column ends with no more than 24 to spare (§3.3).
    private func singleColumn(_ plan: LayoutPlan, subtitles: [Layout: String]) -> some View {
        VStack(spacing: 0) {
            header(plan, subtitles: subtitles)
                .padding(.top, plan.topInset + plan.topExtra)
            if let update {
                updateBanner(update)
                    .padding(.top, LayoutPlan.bannerGap)
            }
            dial(side: plan.dial)
                .padding(.top, plan.gapHeaderDial)
            readoutGroup(plan)
                .padding(.top, plan.gapDialReadout)
            rows(plan, firstGap: plan.gapGroupGrid)
            if plan.map == .card {
                mapCard
                    .frame(width: plan.columnWidth, height: plan.mapHeight)
                    .padding(.top, LayoutPlan.gridToMap)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, plan.bottomInset)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The lock row, the spot row and the tile grid, 8 apart; `firstGap` above the first of them.
    private func rows(_ plan: LayoutPlan, firstGap: CGFloat) -> some View {
        let locked = nav.lockText != nil
        return VStack(spacing: 0) {
            if locked {
                lockRow(plan)
                    .padding(.top, firstGap)
            }
            if hasSpotRow {
                spotRow(plan)
                    .padding(.top, locked ? LayoutPlan.rowGap : firstGap)
            }
            tileGrid(plan)
                .padding(.top, locked || hasSpotRow ? LayoutPlan.rowGap : firstGap)
        }
    }

    /// Wide windows and phones on their side (§3.5, C2.3 #8): one full-width header; the dial, readout and
    /// status line centred in the leading pane; the lock row, the spot row, the grid (fixed 80 rows) and the
    /// map card in the trailing pane, level with the dial's top.
    private func twoPanes(_ plan: LayoutPlan, subtitles: [Layout: String]) -> some View {
        VStack(spacing: 0) {
            header(plan, subtitles: subtitles)
                .padding(.horizontal, plan.margin)
                .padding(.top, plan.topInset)
            if let update {
                updateBanner(update)
                    .padding(.horizontal, plan.margin)
                    .padding(.top, LayoutPlan.bannerGap)
            }
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    dial(side: plan.dial)
                    readoutGroup(plan)
                        .padding(.top, LayoutPlan.dialToReadout)
                }
                .padding(.horizontal, plan.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                trailingPane(plan)
                    .frame(width: plan.columnWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, plan.margin)
            }
            .padding(.top, LayoutPlan.headerToDial)
            .padding(.bottom, plan.bottomInset)
        }
    }

    @ViewBuilder
    private func trailingPane(_ plan: LayoutPlan) -> some View {
        if plan.trailingScrolls && !flatDetails {
            ScrollView {
                trailingContent(plan)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicatorsFlash(onAppear: true)
        } else {
            trailingContent(plan)
                .padding(.top, plan.trailingInset)
        }
    }

    private func trailingContent(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            rows(plan, firstGap: 0)
            if plan.map == .card {
                mapCard
                    .frame(width: plan.columnWidth, height: plan.mapHeight)
                    .padding(.top, LayoutPlan.gridToMap)
            }
        }
    }

    /// Accessibility text sizes (§3.6), or nothing fits even with the dial at its floor: one scrolling
    /// list in which every block is complete, the indicator flashed on appear and a 24 pt fade at the
    /// bottom as the cue that it continues. For ImageRenderer, the same stack, clipped.
    @ViewBuilder
    private func listScreen(_ plan: LayoutPlan, subtitles: [Layout: String]) -> some View {
        if flatDetails {
            listContent(plan, subtitles: subtitles)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView {
                listContent(plan, subtitles: subtitles)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicatorsFlash(onAppear: true)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [Palette.screen.opacity(0), Palette.screen], startPoint: .top, endPoint: .bottom)
                    .frame(height: LayoutPlan.maxSpare)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func listContent(_ plan: LayoutPlan, subtitles: [Layout: String]) -> some View {
        VStack(spacing: LayoutPlan.gridToMap) {
            header(plan, subtitles: subtitles)
            if let update { updateBanner(update) }
            dial(side: plan.dial)
            readoutGroup(plan)
            if nav.lockText != nil { lockRow(plan) }
            if hasSpotRow { spotRow(plan) }
            listTiles(plan)
            mapCard
                .frame(width: plan.columnWidth, height: LayoutPlan.listMap)
        }
        .padding(.top, plan.topInset)
        // Room under the last block for the fade.
        .padding(.bottom, plan.bottomInset + LayoutPlan.maxSpare)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: The header bar

    /// 48 high (52 on iPad, × k), on the sky for the sun's altitude here: the place over the date and
    /// time (with the Sample pill), then the sky symbol, the map button (only when the map is neither a
    /// tile nor a card) and ⋯, which never moves. The time is never ellipsized (C2.3 #14): the date
    /// shortens first ("Nov 1"), then goes; with k > 1.1 or the map button, the Sample pill moves to line 1.
    private func header(_ plan: LayoutPlan, subtitles: [Layout: String]) -> some View {
        let k = plan.k
        let pillOnPlaceLine = nav.sample && (k > 1.1 || plan.mapInHeader)
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    placeLine(k: k, wraps: plan.list)
                    if pillOnPlaceLine { sampleBadge(k: k) }
                }
                HStack(spacing: 6) {
                    dateText(k: k, wraps: plan.list)
                    if nav.sample && !pillOnPlaceLine { sampleBadge(k: k) }
                }
            }
            // The screen's title for VoiceOver: "Bearings" first, then where and when.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(headerSpoken)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            skySymbol
            if plan.mapInHeader { mapButton }
            menu(subtitles: subtitles)
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.vertical, plan.list ? 6 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: plan.headerHeight, maxHeight: plan.list ? nil : plan.headerHeight)
        .skyCard(altitude: nav.sunPosition?.altitude, radius: Look.headerRadius)
    }

    /// "Maroon Bells, Colorado", 17 semibold: when too long the state goes first ("Maroon Bells"), then it
    /// truncates (the place is the one thing allowed to). At accessibility sizes it may wrap to two lines.
    @ViewBuilder
    private func placeLine(k: CGFloat, wraps: Bool) -> some View {
        let full = nav.placeTitle
        let short = full.components(separatedBy: ", ").first ?? full
        if wraps {
            Text(full)
                .font(.system(size: 17 * k, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(full).lineLimit(1).fixedSize()
                Text(short).lineLimit(1).fixedSize()
                Text(short).lineLimit(1).truncationMode(.tail)
            }
            .font(.system(size: 17 * k, weight: .semibold))
        }
    }

    /// "Sun, Nov 1 · 9:41 AM", then "Nov 1 · 9:41 AM", then "9:41 AM": never an ellipsis in the time.
    @ViewBuilder
    private func dateText(k: CGFloat, wraps: Bool) -> some View {
        let lines = Self.dateLines(nav.now)
        Group {
            if wraps {
                Text(Self.keepTogether(lines.full))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ViewThatFits(in: .horizontal) {
                    Text(lines.full).lineLimit(1).fixedSize()
                    Text(lines.short).lineLimit(1).fixedSize()
                    Text(lines.time).lineLimit(1).fixedSize()
                }
            }
        }
        .font(.system(size: 13 * k))
        .foregroundStyle(Color.white.opacity(0.75))
        .monospacedDigit()
    }

    /// The header's second line, longest first: "Sun, Nov 1 · 9:41 AM", "Nov 1 · 9:41 AM", "9:41 AM" (the
    /// device's 12- or 24-hour style, through the one time formatter, Look.timeText).
    static func dateLines(_ date: Date) -> (full: String, short: String, time: String) {
        let time = Look.timeText(date)
        let day = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let shortDay = date.formatted(.dateTime.month(.abbreviated).day())
        return ("\(day) · \(time)", "\(shortDay) · \(time)", time)
    }

    private var headerSpoken: String {
        let when = Self.dateLines(nav.now).full.replacingOccurrences(of: " · ", with: ", ")
        return "\(Brand.appName). \(nav.placeTitle). \(when)\(nav.sample ? ". Sample" : "")"
    }

    /// The sun, sunrise or sunset, or moon symbol (decorative), 20 pt.
    private var skySymbol: some View {
        Image(systemName: SkyTone.symbol(for: nav.sunPosition))
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.white.opacity(Palette.Op.body))
            .accessibilityHidden(true)
    }

    /// Opens the map sheet when the map is neither a tile nor a card.
    private var mapButton: some View {
        Button { nav.mapSheet = true } label: {
            Image(systemName: "map")
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map")
        .accessibilityHint("Opens the map")
    }

    /// 11 semibold on the notice amber.
    private func sampleBadge(k: CGFloat) -> some View {
        Text("Sample")
            .font(.system(size: 11 * k, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 6).padding(.vertical, 1)
            .background(Capsule().fill(Palette.notice))
            .fixedSize()
    }

    /// The ⋯ menu; for ImageRenderer (`flatDetails`, the Mac self-test), which can't draw a menu, its symbol alone.
    @ViewBuilder
    private func menu(subtitles: [Layout: String]) -> some View {
        if flatDetails {
            menuSymbol
                .accessibilityLabel("Settings and more")
        } else {
            settingsMenu(subtitles: subtitles)
        }
    }

    private var menuSymbol: some View {
        Image(systemName: "ellipsis.circle")
            .font(.system(size: 22, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    private func settingsMenu(subtitles: [Layout: String]) -> some View {
        Menu {
            // The first group: the layout, each with a symbol, a subtitle that states what it gives on this
            // screen ("Dial 386 · map in header") and a check on the current one.
            Picker(selection: $nav.layout) {
                ForEach(Layout.allCases) { layout in
                    Label {
                        Text(layout.name)
                        Text(subtitles[layout] ?? layout.subtitle)
                    } icon: {
                        Image(systemName: layout.symbol)
                    }
                    .tag(layout)
                }
            } label: {
                Label("Layout", systemImage: nav.layout.symbol)
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
                Button("Show Map", systemImage: "map") { nav.mapSheet = true }
                Toggle("Follow Heading", isOn: $nav.followHeading)
                Picker("Map Style", selection: $nav.satellite) {
                    Text("Standard").tag(false)
                    Text("Satellite").tag(true)
                }
                .pickerStyle(.menu)
                Button("Open in Maps", systemImage: "arrow.up.right") {
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
            Button("Details", systemImage: "info.circle") { showDetails = true }
            if let text = nav.shareLocationText {
                ShareLink(item: text) { Label("Share My Location…", systemImage: "location") }
            }
            ShareLink(item: Brand.productPage, message: Text(Brand.shareMessage)) {
                Label("Share Bearings…", systemImage: "square.and.arrow.up")
            }
            Divider()
            Link(destination: Brand.legal) { Label("Terms & Privacy", systemImage: "doc.text") }
            // The footer of earlier versions lives here on every layout (C2.3 #8).
            Link(destination: Brand.website) { Label("Made by \(Brand.author)", systemImage: "person.crop.circle") }
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

    /// The Mac's update banner: 44 high, in the tile style, between the header and the content.
    private func updateBanner(_ update: (version: String, url: URL)) -> some View {
        HStack {
            Text("Bearings \(update.version) is available.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
            Button("Download") { openURL(update.url) }
                .buttonStyle(LookButtonStyle())
        }
        .padding(.leading, 12).padding(.trailing, 6)
        .frame(height: LayoutPlan.banner)
        .frame(maxWidth: .infinity)
        .frostedTile()
    }

    // MARK: Dial, readout, status line, lock chip

    /// The dial: tap to lock or unlock the bearing; pinch to step the layout; VoiceOver reads it as one
    /// element with its custom actions.
    private func dial(side: CGFloat) -> some View {
        Button { nav.toggleLock() } label: {
            DialView(rotation: nav.cardRotation, heading: nav.heading, lock: nav.lock, tilt: nav.tilt,
                     sun: nav.sunPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                     moon: nav.moonPosition.map { DialView.SkyMark(angle: nav.cardAngle($0.azimuth), aboveHorizon: $0.altitude > 0) },
                     moonPhase: nav.moonPhase.phase,
                     spot: nav.spotBearing.map { nav.cardAngle($0) },
                     noCompass: nav.noCompass)
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
            parts.append("No compass, north is fixed at the top")
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

    /// The no-compass state is announced once, politely (§4.2).
    private func announceNoCompass() {
        guard nav.noCompass, !announcedNoCompass else { return }
        announcedNoCompass = true
        UIAccessibility.post(notification: .announcement, argument: Self.noCompassText.replacingOccurrences(of: " · ", with: ". "))
    }
    #endif

    /// The status line's slot when there is no compass (two lines allowed, wrapping at the "·").
    static let noCompassText = "No compass · position, sun and map still work"
    /// The readout with no heading: an em dash (U+2014) and the degree sign.
    static let noHeadingText = "\u{2014}°"

    /// The readout and the status line (with no compass, "NO HEADING" between them), centred under the dial.
    private func readoutGroup(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            readout(plan)
            if plan.noCompass {
                Text("No heading".uppercased())
                    .font(.system(size: Look.tileCaptionSize * plan.k, weight: .semibold))
                    .tracking(Look.tileCaptionTracking)
                    .foregroundStyle(secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .frame(height: LayoutPlan.captionLine * plan.k)
                    .padding(.top, LayoutPlan.readoutToCaption)
                    .accessibilityHidden(true)
            }
            statusLine(plan)
                .padding(.top, LayoutPlan.readoutToStatus)
        }
    }

    /// How far a line of the light system font at `size` reaches above its capitals: trimmed off the
    /// readout's line box, so the 12 under the dial runs to the digits' cap height (C2.3 #7).
    static func capInset(size: CGFloat) -> CGFloat {
        let font = PlatformFont.systemFont(ofSize: size, weight: .light)
        return max(0, font.ascender - font.capHeight)
    }

    /// The width of `text` in the system font with tabular digits, for the self-tests' fit checks.
    fileprivate static func textWidth(_ text: String, size: CGFloat, weight: PlatformFont.Weight) -> CGFloat {
        let font = PlatformFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// "228° SW", unchanged in style, in a block trimmed to the digits' cap height. With no heading "—°"
    /// (an em dash and a degree sign on one baseline) at white 40%.
    private func readout(_ plan: LayoutPlan) -> some View {
        let big = plan.headingSize
        let spokenHeading = nav.heading.map { "Heading \(Int($0.rounded()) % 360) degrees, \(Geo.pointName($0).lowercased())" }
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let h = nav.heading {
                Text("\(Int(h.rounded()) % 360)°")
                    .font(.system(size: big, weight: .light))
                    .foregroundStyle(.white)
                    .tracking(-2)
                Text(Geo.point(h))
                    .font(.system(size: big / 2, weight: .medium))
                    .foregroundStyle(secondary)
                    .frame(minWidth: big, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\u{2014}")
                    Text("°")
                }
                .font(.system(size: big, weight: .light))
                .foregroundStyle(Color.white.opacity(0.4))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
        // The line box above the capitals is trimmed; the block is cap height plus 4 under the baseline.
        .padding(.top, -Self.capInset(size: big))
        .frame(height: LayoutPlan.readoutHeight(headingSize: big), alignment: .top)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenHeading ?? (nav.noCompass ? "Heading unavailable" : "Heading not known yet"))
    }

    /// "True north · 8° E declination · ±8° accuracy", 13 regular, one line (two only at k > 1.1, after a
    /// dot). Amber warnings take its place; with no compass, the no-compass note (two lines allowed,
    /// within C − 32).
    @ViewBuilder
    private func statusLine(_ plan: LayoutPlan) -> some View {
        let lines = Int(plan.statusLines)
        let height = LayoutPlan.statusHeight(k: plan.k, lines: plan.statusLines)
        Group {
            if nav.noCompass {
                Text(Self.keepTogether(Self.noCompassText))
                    .foregroundStyle(secondary)
                    .lineLimit(plan.list ? nil : 2)
                    .accessibilityLabel("No compass. Position, sun and map still work.")
            } else if let warning = nav.compassWarning {
                Text(warning)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.notice)
                    .lineLimit(plan.list ? nil : lines)
            } else if nav.heading != nil {
                Text(Self.keepTogether(nav.statusText))
                    .foregroundStyle(secondary)
                    .lineLimit(plan.list ? nil : lines)
                    .accessibilityLabel(nav.spokenStatus)
            } else {
                Text(" ")
                    .accessibilityHidden(true)
            }
        }
        .font(.system(size: 13 * plan.k))
        .monospacedDigit()
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: plan.list)
        .padding(.horizontal, nav.noCompass ? 16 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: height, maxHeight: plan.list ? nil : height)
    }

    // MARK: Lock and marked spot

    /// The locked bearing, in the spot row's form (C2.3 #16): a full-width tile, 44 high, leading-aligned:
    /// lock, "Locked 240°", then "turn 12° right" trailing and a ✕ 8 after it in a 44 × 44 target.
    private func lockRow(_ plan: LayoutPlan) -> some View {
        let k = plan.k, height = LayoutPlan.lockHeight(k: k)
        let text = nav.lockText ?? ""
        let parts = text.components(separatedBy: " · ")
        let first = parts.first ?? text
        let rest = parts.dropFirst().joined(separator: " · ")
        let spokenText = text.replacingOccurrences(of: "°", with: " degrees").replacingOccurrences(of: " · ", with: ", ")
        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 17 * k, weight: .semibold))
                Text(Self.keepTogether(first))
                    .font(.system(size: 15 * k, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 8)
                if !rest.isEmpty {
                    FitText(text: Self.keepTogether(rest), size: 15 * k, wraps: plan.list)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenText)
            .accessibilityActions {
                Button("Unlock Bearing") { nav.toggleLock() }
            }
            Button { nav.toggleLock() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13 * k, weight: .bold))
                    .foregroundStyle(secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The glyph sits 8 after the text; its 44 target reaches back under the text's end.
            .padding(.leading, -8)
            .accessibilityLabel("Unlock Bearing")
        }
        .foregroundStyle(.white)
        .padding(.leading, Look.tilePaddingH)
        .frame(width: plan.columnWidth)
        .frame(minHeight: height, maxHeight: plan.list ? nil : height)
        .background(RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
            .fill(Palette.accent.opacity(nav.nightMode ? 0.25 : 0.20)))
        .frostedTile()
        .accessibilityElement(children: .contain)
    }

    /// A full-width tile, 44 high: pin, "Marked spot", then "9.2 mi · 46° NE" trailing, and a ✕ 8 after
    /// it in a 44 × 44 target. The row opens a small menu (Lock to Spot, Clear Marked Spot).
    private func spotRow(_ plan: LayoutPlan) -> some View {
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
            // ImageRenderer can't draw a menu (the Mac self-test): the row alone there.
            if flatDetails {
                spotLabel(details: details, plan: plan)
            } else {
                Menu {
                    Button("Lock to Spot", systemImage: "scope") { nav.lockToSpot() }
                    Button("Clear Marked Spot", systemImage: "mappin.slash") { nav.clearSpot() }
                } label: {
                    spotLabel(details: details, plan: plan)
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
                    .font(.system(size: 13 * k, weight: .bold))
                    .foregroundStyle(secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // The glyph sits 8 after the text; its 44 target reaches back under the text's end.
            .padding(.leading, -8)
            .accessibilityLabel("Clear Marked Spot")
        }
        .padding(.leading, Look.tilePaddingH)
        .frame(width: plan.columnWidth)
        .frame(minHeight: height, maxHeight: plan.list ? nil : height)
        .frostedTile()
    }

    private func spotLabel(details: String, plan: LayoutPlan) -> some View {
        let k = plan.k
        return HStack(spacing: 8) {
            Image(systemName: "mappin")
                .font(.system(size: 17 * k, weight: .semibold))
            Text("Marked spot")
                .font(.system(size: 15 * k, weight: .medium))
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 8)
            FitText(text: Self.keepTogether(details), size: 15 * k, wraps: plan.list)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }


    // MARK: The tile grid

    /// 3 columns, u = (C − 16) / 3, rows 8 apart. Full: Position (2u) | Elevation, then Sun | Moon | Map
    /// (Sun | Moon in halves when the map is a card or the header button). Compact: Position | Elevation |
    /// Sun with widths from C (LayoutPlan.compactWidths), the moon in Sun's caption. A trailing pane
    /// narrower than 360: 2 columns, Position, Elevation | Sun, Moon, and Map, each spanning both. Every
    /// row's widths and gutters add up to C (LayoutPlan.rowWidths).
    @ViewBuilder
    private func tileGrid(_ plan: LayoutPlan) -> some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
                .frame(width: plan.columnWidth, height: gridHeight(plan))
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                gridContent(plan, stale: stale)
            }
        }
    }

    private func gridHeight(_ plan: LayoutPlan) -> CGFloat {
        let rows = CGFloat(plan.rowWidths.count)
        return rows * plan.tileHeight + (rows - 1) * Self.gap
    }

    @ViewBuilder
    private func gridContent(_ plan: LayoutPlan, stale: Bool) -> some View {
        let u = plan.unit, t = plan.tileHeight, c = plan.columnWidth, g = Self.gap
        if plan.columns == 3 {
            VStack(spacing: g) {
                if plan.grid == .compact {
                    // Position wider; Elevation and Sun w = max(104, 0.27 C) each; exactly C across.
                    let widths = plan.compactWidths
                    HStack(spacing: g) {
                        positionTile(plan, stale: stale, compact: true)
                            .frame(width: widths.position, height: t)
                        elevationTile(plan, stale: stale)
                            .frame(width: widths.other, height: t)
                        sunTile(plan, compact: true)
                            .frame(width: widths.other, height: t)
                    }
                } else {
                    HStack(spacing: g) {
                        positionTile(plan, stale: stale, compact: false)
                            .frame(width: 2 * u + g, height: t)
                        elevationTile(plan, stale: stale)
                            .frame(width: u, height: t)
                    }
                    HStack(spacing: g) {
                        if plan.map == .tile {
                            sunTile(plan, compact: false).frame(width: u, height: t)
                            moonTile(plan).frame(width: u, height: t)
                            mapTile.frame(width: u, height: t)
                        } else {
                            sunTile(plan, compact: false).frame(width: (c - g) / 2, height: t)
                            moonTile(plan).frame(width: (c - g) / 2, height: t)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: g) {
                positionTile(plan, stale: stale, compact: false)
                    .frame(width: c, height: t)
                HStack(spacing: g) {
                    elevationTile(plan, stale: stale).frame(width: u, height: t)
                    sunTile(plan, compact: false).frame(width: u, height: t)
                }
                moonTile(plan)
                    .frame(width: c, height: t)
                if plan.map == .tile {
                    mapTile.frame(width: c, height: t)
                }
            }
        }
    }

    /// Accessibility sizes: every tile a full-width row, caption above the value, values wrapping.
    @ViewBuilder
    private func listTiles(_ plan: LayoutPlan) -> some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
                .frame(width: plan.columnWidth)
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                VStack(spacing: Self.gap) {
                    positionTile(plan, stale: stale, compact: false)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: plan.columnWidth)
                    elevationTile(plan, stale: stale)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: plan.columnWidth)
                    sunTile(plan, compact: false)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: plan.columnWidth)
                    moonTile(plan)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: plan.columnWidth)
                }
            }
        }
    }

    /// "Finding position…" under a "—", before the first fix (never blank).
    private var waitingText: String { nav.access == .allowed || nav.locating ? "Finding position…" : "Not known yet" }

    /// A tile's value: 17 medium (15 in the compact row), tabular, white (dimmed when the fix is stale).
    /// Scales to 0.85, then wraps; never ellipsized.
    private func valueText(_ text: String, plan: LayoutPlan, stale: Bool = false, size: CGFloat = Look.tileValueSize,
                           weight: Font.Weight = .medium) -> some View {
        FitText(text: text, size: size * plan.k, weight: weight, wraps: plan.list)
            .monospacedDigit()
            .foregroundStyle(stale ? secondary : .white)
    }

    /// POSITION · DD: latitude over longitude, or one grid reference (15 pt in the compact row). Tap for
    /// the next format; long-press (right-click on a Mac) for Copy and Details….
    private func positionTile(_ plan: LayoutPlan, stale: Bool, compact: Bool) -> some View {
        let formatted = nav.fix.map { Geo.format(nav.format, lat: $0.latitude, lon: $0.longitude) }
        let first: String, second: String?, spokenValue: String
        switch formatted {
        case let .some(.pair(lat, lon)):
            first = lat
            second = lon
            spokenValue = "\(Self.spokenCoordinate(lat)), \(Self.spokenCoordinate(lon))"
        case let .some(.single(value)):
            first = value
            second = nil
            spokenValue = value
        case .none:
            first = "—"
            second = nil
            spokenValue = waitingText.lowercased()
        }
        // "decimal degrees", but "UTM" and "MGRS" stay in capitals so they're spelled out.
        let name = nav.format.name
        let formatWords = name == name.uppercased() ? name : name.lowercased()
        let size = compact ? Look.compactValueSize : Look.tileValueSize
        return CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
            PanelTile("Position · \(Self.shortName(nav.format))", secondary: nav.fix == nil ? waitingText : nil) {
                VStack(alignment: .leading, spacing: -2) {
                    valueText(first, plan: plan, stale: stale, size: size)
                    if let second {
                        valueText(second, plan: plan, stale: stale, size: size)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position, \(spokenValue), \(formatWords)")
        }
    }

    /// The format's short name in the Position caption: DD, DMS, DDM, UTM, MGRS, PLUS.
    static func shortName(_ format: Geo.Format) -> String {
        switch format {
        case .dd: "DD"
        case .dms: "DMS"
        case .ddm: "DDM"
        case .utm: "UTM"
        case .mgrs: "MGRS"
        case .plus: "PLUS"
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

    /// ELEVATION: "9,587 ft" over "2,922 m" (metres first when chosen). Tap: the Details sheet.
    private func elevationTile(_ plan: LayoutPlan, stale: Bool) -> some View {
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
            let waiting = text.trimmingCharacters(in: .whitespaces)
            second = nav.fix == nil || waiting.isEmpty ? waitingText : waiting
            spokenText = "Elevation, \(second.lowercased())"
        }
        return PanelTile("Elevation", secondary: second) {
            valueText(main, plan: plan, stale: stale)
        }
        .panelAction(spokenText, hint: "Shows the details") { showDetails = true }
    }

    /// SUN, with its glyph in the caption: "↑ 6:36 AM" over "↓ 5:08 PM" (one formatter, Look.time, in the
    /// device's 12- or 24-hour style), or "Up all day" / "Down all day". In the compact row the values are
    /// 15 semibold and the moon rides in the caption ("SUN · ◐ 53%"). Tap: the Details sheet.
    private func sunTile(_ plan: LayoutPlan, compact: Bool) -> some View {
        let k = plan.k
        let times = nav.sunTimes
        let rise = times?.sunriseDate, down = times?.sunsetDate
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        var spokenSun: String
        if let rise, let down {
            spokenSun = "rises \(Look.timeText(rise)), sets \(Look.timeText(down))"
        } else if let times {
            spokenSun = times.polar == .day ? "up all day" : "down all day"
        } else {
            spokenSun = waitingText.lowercased()
        }
        if compact { spokenSun += ". Moon \(percent) percent lit, \(Look.phaseName(phase).lowercased())" }
        let size = (compact ? Look.compactValueSize : Look.tileValueSize) * k
        let weight: Font.Weight = compact ? .semibold : .medium
        return PanelTile("Sun", symbol: "sun.max.fill", moon: compact ? phase : nil,
                         secondary: times == nil ? waitingText : nil) {
            if let rise, let down {
                VStack(alignment: .leading, spacing: -2) {
                    SunTime(arrow: "↑", time: Look.time(rise), size: size, weight: weight, k: k, wraps: plan.list)
                    SunTime(arrow: "↓", time: Look.time(down), size: size, weight: weight, k: k, wraps: plan.list)
                }
                .monospacedDigit()
            } else if let times {
                valueText(times.polar == .day ? "Up all day" : "Down all day", plan: plan, size: compact ? Look.compactValueSize : Look.tileValueSize)
            } else {
                valueText("—", plan: plan)
            }
        }
        .panelAction("Sun, \(spokenSun)", hint: "Shows the details") { showDetails = true }
    }

    /// MOON: the phase's glyph and "53%", over "Last quarter". Tap: the Details sheet.
    private func moonTile(_ plan: LayoutPlan) -> some View {
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        return PanelTile("Moon", secondary: Look.phaseName(phase)) {
            HStack(spacing: 6) {
                MoonGlyph(phase: phase.phase, size: 15 * plan.k)
                valueText("\(percent)%", plan: plan)
            }
        }
        .panelAction("Moon, \(percent) percent lit, \(Look.phaseName(phase).lowercased())", hint: "Shows the details") { showDetails = true }
    }

    /// MAP: a live thumbnail, north up with the heading cone, no controls or gestures, its caption
    /// bottom-leading on a scrim. Tap: the map sheet.
    private var mapTile: some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: .constant(false), satellite: nav.satellite,
                   dimmed: nav.nightMode, thumbnail: true)
            .allowsHitTesting(false)
            // The map itself takes no touches; this clear layer takes the tap for the whole tile.
            .overlay { Color.clear.contentShape(Rectangle()) }
            .panelAction("Map", hint: "Opens the map") { nav.mapSheet = true }
    }

    /// The full-width map card, with its one control cluster.
    private var mapCard: some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                   speed: nav.speed.map { Geo.speedText($0, feet: nav.feet) }, dimmed: nav.nightMode)
    }

    private var askForLocation: some View {
        HStack(spacing: 12) {
            Text(nav.access == .denied
                 ? "Location is off for Bearings. Turn it on in Settings to see your coordinates, elevation and map."
                 : "Allow your location to see your latitude, longitude, elevation and map. It stays on this device.")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(Palette.Op.body))
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            Button(nav.access == .denied ? "Settings" : "Use My Location") {
                if nav.access == .denied { openLocationSettings() } else { nav.start() }
            }
            .buttonStyle(LookButtonStyle())
            // The row is at least 44 high around the capsule (LOOK.md's compact button).
            .frame(minHeight: 44)
        }
        .padding(.horizontal, Look.tilePaddingH)
        .padding(.vertical, Look.tilePaddingV)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frostedTile()
    }

    private func openLocationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") { openURL(url) }
        #endif
    }

    // MARK: Sheets

    /// A sheet's top bar: its title and Done, on one baseline.
    private func sheetBar(_ title: String, done: @escaping () -> Void) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button("Done", action: done)
                .font(.system(size: 17, weight: .semibold))
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    /// The map sheet (C2.3 #11): the map full-bleed under a translucent bar ("Map", Done trailing, one
    /// baseline), with the same control cluster and speed chip as the map card below the bar, and the
    /// attribution in the bottom safe area. Full height on iPhone; a page-sized sheet on iPad.
    private var mapSheet: some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                   speed: nav.speed.map { Geo.speedText($0, feet: nav.feet) }, dimmed: nav.nightMode,
                   bleed: true, topInset: Self.sheetBarHeight)
            // The map runs to the sheet's bottom edge; Apple Maps keeps its logo and Legal link in the safe area.
            .ignoresSafeArea(edges: .bottom)
            .overlay(alignment: .top) {
                sheetBar("Map") { nav.mapSheet = false }
                    .padding(.bottom, 4)
                    .frame(height: Self.sheetBarHeight, alignment: .bottom)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            }
            .foregroundStyle(.white)
            .background(Palette.screen.ignoresSafeArea())
            .environment(\.colorScheme, .dark)
            .environment(\.nightText, nav.nightMode)
            .colorMultiply(nav.nightMode ? Self.nightTint : .white)
            #if os(iOS)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .pageSizedSheet()
            #else
            .frame(minWidth: 480, minHeight: 560)
            #endif
    }

    /// The map sheet's bar: 8 for the grabber, the 44 row, 4 under it.
    private static let sheetBarHeight: CGFloat = 56

    /// The Details sheet: what the old DETAILS tiles showed, as a grouped list.
    private var detailsSheet: some View {
        VStack(spacing: 0) {
            sheetBar("Details") { showDetails = false }
            List {
                Section("Position") {
                    LabeledContent("Format", value: nav.format.name)
                    LabeledContent("Coordinates", value: nav.copyText ?? "—")
                    LabeledContent("Accuracy", value: nav.fix.map { Geo.accuracy($0.accuracy, feet: nav.feet) } ?? "—")
                    LabeledContent("Fix", value: fixAge(now: Date()))
                }
                Section("Elevation") {
                    switch nav.elevation {
                    case let .value(metres, _, source):
                        let e = Geo.elevation(metres)
                        LabeledContent("Elevation", value: nav.feet ? "\(e.ft) · \(e.m)" : "\(e.m) · \(e.ft)")
                        LabeledContent("Source", value: source)
                    case let .pending(text):
                        LabeledContent("Elevation", value: text.trimmingCharacters(in: .whitespaces).isEmpty ? "—" : text)
                    }
                    if let pressure = nav.pressure {
                        LabeledContent("Pressure", value: Geo.pressureText(pressure, feet: nav.feet))
                    }
                }
                Section("Sun") {
                    LabeledContent("Sunrise", value: sunEvent(nav.sunTimes?.sunriseDate))
                    LabeledContent("Sunset", value: sunEvent(nav.sunTimes?.sunsetDate))
                }
                Section("Moon") {
                    LabeledContent("Phase", value: Look.phaseName(nav.moonPhase))
                    LabeledContent("Lit", value: "\(Int(Geo.jsRound(nav.moonPhase.fraction * 100)))%")
                }
                Section("Compass") {
                    LabeledContent("North", value: nav.noCompass ? "No compass" : nav.statusText)
                }
            }
        }
        .foregroundStyle(.white)
        .background(Palette.screen.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .colorMultiply(nav.nightMode ? Self.nightTint : .white)
        #if os(iOS)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #else
        .frame(minWidth: 420, minHeight: 520)
        #endif
    }

    /// "6:36 AM · 112° ESE": the time and the sun's direction then; "—" in polar day or night.
    private func sunEvent(_ date: Date?) -> String {
        guard let date, let fix = nav.fix else { return "—" }
        let azimuth = Sky.sunPosition(at: date, lat: fix.latitude, lon: fix.longitude).azimuth
        let shown = nav.cardAngle(azimuth)
        return "\(Look.timeText(date)) · \(Int(Geo.jsRound(shown)) % 360)° \(Geo.point(shown))"
    }

    /// "Just now", "40 s ago", "3 min ago", or "Sample".
    private func fixAge(now: Date) -> String {
        guard let fix = nav.fix else { return waitingText }
        if nav.sample { return "Sample" }
        let s = max(0, Int(now.timeIntervalSince(fix.time)))
        if s < 10 { return "Just now" }
        if s < 60 { return "\(s) s ago" }
        if s < 3600 { return "\(s / 60) min ago" }
        return "\(s / 3600) hr ago"
    }

    // MARK: Copy, toast

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

/// The Position tile's gestures: tap for the next of the six formats; long-press (right-click on a Mac)
/// for a menu of Copy and Details…; the same as VoiceOver actions. The content is expected to be one
/// accessibility element already.
struct CoordinateText<Content: View>: View {
    @EnvironmentObject private var nav: Navigator
    private let copy: () -> Void
    private let details: () -> Void
    private let content: Content

    init(copy: @escaping () -> Void, details: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.copy = copy
        self.details = details
        self.content = content()
    }

    var body: some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { nav.cycleFormat() }
            .contextMenu {
                Button("Copy", systemImage: "doc.on.doc") { copy() }
                Button("Details…", systemImage: "info.circle") { details() }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Changes the coordinate format")
            .accessibilityAction(named: "Next Format") { nav.cycleFormat() }
            .accessibilityAction(named: "Copy Coordinates") { copy() }
            .accessibilityAction(named: "Details") { details() }
    }
}

/// One tile, the same component everywhere (docs/REFINE.md §3.2 and C2.3 #6, the widgets' pattern): an
/// 11 pt caps caption (with an optional symbol, and for the compact row's Sun the moon's glyph and
/// percentage) pinned 10 from the top, and the value block (a 17 pt tabular value and a 13 pt second line)
/// pinned 10 from the bottom, so a grown tile is never half empty at the bottom. Leading-aligned on a
/// frosted fill (radius 16), 12 in from the sides. The caller sets its frame.
struct PanelTile<Value: View>: View {
    let caption: String
    var symbol: String?
    var moon: Sky.Phase?
    var secondary: String?
    let value: Value
    @Environment(\.uiScale) private var k
    @Environment(\.nightText) private var night

    init(_ caption: String, symbol: String? = nil, moon: Sky.Phase? = nil, secondary: String? = nil,
         @ViewBuilder value: () -> Value) {
        self.caption = caption
        self.symbol = symbol
        self.moon = moon
        self.secondary = secondary
        self.value = value()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            captionRow
            Spacer(minLength: 2)
            VStack(alignment: .leading, spacing: 0) {
                value
                if let secondary {
                    FitText(text: secondary, size: Look.tileSecondarySize * k)
                        .foregroundStyle(Palette.secondary(night: night))
                }
            }
        }
        .padding(.horizontal, Look.tilePaddingH)
        .padding(.vertical, Look.tilePaddingV)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .frostedTile()
    }

    /// "☀ SUN · ◐ 53%": the symbol is dropped first when the caption is too wide; the words never truncate.
    private var captionRow: some View {
        ViewThatFits(in: .horizontal) {
            captionContent(withSymbol: symbol != nil)
            captionContent(withSymbol: false)
            captionContent(withSymbol: false)
                .scaleEffect(0.85, anchor: .leading)
        }
        .foregroundStyle(Palette.secondary(night: night))
    }

    private func captionContent(withSymbol: Bool) -> some View {
        HStack(spacing: 3) {
            if withSymbol, let symbol {
                Image(systemName: symbol)
                    .font(.system(size: Look.tileCaptionSymbolSize * k, weight: .semibold))
            }
            Text(caption.uppercased())
                .tracking(Look.tileCaptionTracking)
            if let moon {
                Text("·")
                MoonGlyph(phase: moon.phase, size: Look.tileCaptionSize * k)
                Text("\(Int(Geo.jsRound(moon.fraction * 100)))%")
                    .monospacedDigit()
            }
        }
        .font(.system(size: Look.tileCaptionSize * k, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
    }
}

/// Text that is never ellipsized (C2.2 #1): at its size on one line, else at 0.85 of it, else wrapped
/// at 0.85. In the scrolling list (`wraps`) it wraps at its full size.
struct FitText: View {
    let text: String
    let size: CGFloat
    var weight: Font.Weight = .regular
    var wraps = false

    var body: some View {
        if wraps {
            Text(text)
                .font(.system(size: size, weight: weight))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(text)
                    .font(.system(size: size, weight: weight))
                    .lineLimit(1)
                    .fixedSize()
                Text(text)
                    .font(.system(size: size * Look.minScale, weight: weight))
                    .lineLimit(1)
                    .fixedSize()
                Text(text)
                    .font(.system(size: size * Look.minScale, weight: weight))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// One of the Sun tile's rows, "↑ 6:36 AM", never ellipsized (C2.2 #1): on one line at its size, then at
/// 0.85, then with the day period in 11 pt beside the time, then the time over an 11 pt "AM".
struct SunTime: View {
    let arrow: String
    let time: (clock: String, period: String?)
    let size: CGFloat
    let weight: Font.Weight
    let k: CGFloat
    var wraps = false

    private var whole: String {
        "\(arrow)\u{00A0}\(time.clock)" + (time.period.map { "\u{202F}\($0)" } ?? "")
    }

    var body: some View {
        if wraps {
            Text(whole)
                .font(.system(size: size, weight: weight))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(whole)
                    .font(.system(size: size, weight: weight))
                    .lineLimit(1)
                    .fixedSize()
                Text(whole)
                    .font(.system(size: size * Look.minScale, weight: weight))
                    .lineLimit(1)
                    .fixedSize()
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(arrow)\u{00A0}\(time.clock)")
                        .font(.system(size: size, weight: weight))
                    if let period = time.period {
                        Text(period)
                            .font(.system(size: Look.periodSize * k, weight: weight))
                    }
                }
                .lineLimit(1)
                .fixedSize()
                VStack(alignment: .leading, spacing: -2) {
                    Text("\(arrow)\u{00A0}\(time.clock)")
                        .font(.system(size: size * Look.minScale, weight: weight))
                    if let period = time.period {
                        Text(period)
                            .font(.system(size: Look.periodSize * k, weight: weight))
                    }
                }
                .lineLimit(1)
                .fixedSize()
            }
        }
    }
}

// MARK: Fit checks for the self-tests (C2's "no … anywhere")

extension MainView {
    /// Measures what the compact row and the header must hold, in the system font, on every device of the
    /// planner's table at Text Size 1.0 and 1.3, and checks that the strings the tiles and the header show
    /// never carry "…". Each failure is one line; empty when all is well.
    static func fitFailures(sunrise: Date, sunset: Date, now: Date, lat: Double, lon: Double) -> [String] {
        var failures: [String] = []
        let times = [Look.time(sunrise), Look.time(sunset)]
        let dates = dateLines(now)
        // The strings themselves.
        var shown: [String] = [dates.full, dates.short, dates.time, Look.timeText(sunrise), Look.timeText(sunset),
                               noHeadingText, noCompassText]
        for format in Geo.Format.allCases {
            switch Geo.format(format, lat: lat, lon: lon) {
            case let .pair(a, b): shown += [a, b]
            case let .single(value): shown.append(value)
            }
        }
        for text in shown where text.contains("…") { failures.append("\"\(text)\" has an ellipsis") }
        if noHeadingText != "\u{2014}°" { failures.append("The no-compass readout is \"\(noHeadingText)\", not \"—°\"") }

        let dd = Geo.format(.dd, lat: lat, lon: lon)
        for d in LayoutPlan.devices {
            for k in [CGFloat(1), 1.3] {
                for layout in Layout.allCases {
                    let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, hasSpot: true, locked: true, mac: d.mac)
                    let name = "\(d.name) \(layout.rawValue) k\(k)"
                    if !p.list {
                        // The header's last step, the time alone, fits beside the sky symbol, the map
                        // button (when shown) and ⋯.
                        let mapButton: CGFloat = p.mapInHeader ? 52 : 0
                        let trailing: CGFloat = 82 + mapButton
                        // The Sample pill (6 + about 50) shares the time's line unless it moved to line 1.
                        let pill: CGFloat = k > 1.1 || p.mapInHeader ? 0 : 56
                        let room: CGFloat = p.columnWidth - 18 - trailing - pill
                        if textWidth(dates.time, size: 13 * k, weight: .regular) > room + 0.5 {
                            failures.append("\(name): the header time doesn't fit (\(Int(room)) pt)")
                        }
                    }
                    guard p.grid == .compact else { continue }
                    let widths = p.compactWidths
                    // Sun: some step of its ladder fits on a line (at the latest, the time over its "AM").
                    let sunRoom = widths.other - 2 * Look.tilePaddingH
                    for t in times {
                        let clock = textWidth("↑\u{00A0}\(t.clock)", size: Look.compactValueSize * Look.minScale * k, weight: .semibold)
                        let period = t.period.map { textWidth($0, size: Look.periodSize * k, weight: .semibold) } ?? 0
                        if max(clock, period) > sunRoom + 0.5 {
                            failures.append("\(name): Sun \(t.clock) needs \(Int(max(clock, period))) of \(Int(sunRoom)) pt")
                        }
                    }
                    // Position (decimal degrees, the default): the longitude fits on one line at 0.85 of
                    // 15 pt at the default Text Size (larger sizes may wrap; the tile is taller then).
                    if k == 1, case let .pair(_, lonText) = dd {
                        let room = widths.position - 2 * Look.tilePaddingH
                        let width = textWidth(lonText, size: Look.compactValueSize * Look.minScale, weight: .medium)
                        if width > room + 0.5 { failures.append("\(name): \(lonText) needs \(Int(width)) of \(Int(room)) pt") }
                    }
                }
            }
        }
        return failures
    }
}

extension View {
    /// A tile that does one thing when tapped, read by VoiceOver as one button with this label.
    func panelAction(_ label: String, hint: String, action: @escaping () -> Void) -> some View {
        self
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }

    /// iPad: the map sheet is page-sized rather than a form sheet over half the dial (iOS 18 and later;
    /// earlier systems keep their default).
    @ViewBuilder
    func pageSizedSheet() -> some View {
        #if compiler(>=6.0)
        if #available(iOS 18.0, macOS 15.0, *) {
            self.presentationSizing(.page)
        } else {
            self
        }
        #else
        self
        #endif
    }
}

/// Drawn for ImageRenderer instead of with a ScrollView or a menu (the Mac self-test sets it). False
/// everywhere else.
private struct FlatDetailsKey: EnvironmentKey { static let defaultValue = false }

/// How much larger the type is: the system's Text Size (up to 1.3). 1 at the default size.
private struct UIScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }

/// Night mode, for secondary text that must stay readable under the red tint (§4.3).
private struct NightTextKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    var flatDetails: Bool {
        get { self[FlatDetailsKey.self] }
        set { self[FlatDetailsKey.self] = newValue }
    }
    var uiScale: CGFloat {
        get { self[UIScaleKey.self] }
        set { self[UIScaleKey.self] = newValue }
    }
    var nightText: Bool {
        get { self[NightTextKey.self] }
        set { self[NightTextKey.self] = newValue }
    }
}
