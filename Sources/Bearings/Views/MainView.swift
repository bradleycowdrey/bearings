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

/// Bearings' one screen, the "Instrument panel" (docs/REFINE.md §3, Cycle 2 and Cycle 3): one fixed,
/// non-scrolling screen of header bar → dial (the hero) → readout → status line → lock row → spot row →
/// tile grid → map card (only where it fits whole). The header is pinned at the safe top + 8 in every layout
/// and state; every gap is a frozen token × k; the dial, the grid (`LayoutPlan.cells`), the map and the
/// tiles come from the planner and nowhere else, so what is drawn is what was planned (and the self-tests
/// check the drawing against the plan). Each fact appears once, in one tile component (caption pinned to
/// the top, value block to the bottom, as the widgets). No value is ever ellipsized (it scales to 0.85,
/// then wraps); at accessibility text sizes the whole screen becomes one scrolling list. Wide windows and
/// phones on their side get two panes under one header. The same view on Mac, iPhone and iPad, in Two
/// Degrees' look (docs/LOOK.md), with iPad's own type ramp.
struct MainView: View {
    @EnvironmentObject private var nav: Navigator
    /// "Bearings 0.2.0 is available" on the Mac (nil elsewhere).
    var update: (version: String, url: URL)?
    @State private var toast: String?
    @State private var showAbout = false
    @State private var showDetails = false
    @Environment(\.openURL) private var openURL
    /// Drawn for ImageRenderer (the self-tests), which can't draw a ScrollView or a menu.
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

    /// A Mac window: 24 in from every edge.
    static var isMac: Bool {
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

    /// The lock row's two columns (C3.4 #7): "Locked 240°" and "turn 12° right", each with no-break spaces
    /// inside, so neither value ever splits.
    static func lockParts(_ text: String) -> (label: String, cue: String) {
        let parts = text.components(separatedBy: " · ")
        let label = (parts.first ?? text).replacingOccurrences(of: " ", with: "\u{00A0}")
        let cue = parts.dropFirst().joined(separator: " · ")
        return (label, keepTogether(cue))
    }

    /// The type ramp for this plan: iPad's regular-width one on a tablet.
    static func ramp(_ plan: LayoutPlan) -> Ramp { plan.tablet ? .tablet : .phone }

    var body: some View {
        GeometryReader { geo in
            let plan = makePlan(for: geo)
            Group {
                if plan.list {
                    listScreen(plan)
                } else if plan.twoPane {
                    twoPanes(plan)
                } else {
                    singleColumn(plan)
                }
            }
            .environment(\.uiScale, plan.k)
            .environment(\.panelRamp, Self.ramp(plan))
            .environment(\.panelRows, plan.list)
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
                               accessibilityText: typeSize.isAccessibilitySize, hasSpot: hasSpotRow,
                               locked: nav.lockText != nil, noCompass: nav.noCompass,
                               hasUpdateBanner: update != nil, mac: Self.isMac,
                               isLandscapePhone: landscapePhone)
    }

    // MARK: The three arrangements

    /// One column, C wide, centred: the header pinned at the top inset, every block at its planned height
    /// and gap; spare goes only where the plan put it (under the header, and at the bottom).
    private func singleColumn(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            header(plan)
                .padding(.top, plan.topInset)
            if let update {
                updateBanner(update)
                    .padding(.top, LayoutPlan.bannerGap)
            }
            dial(side: plan.dial)
                .padding(.top, plan.gapHeaderDial + plan.topExtra)
            readoutGroup(plan)
                .padding(.top, plan.gapDialReadout)
            rows(plan, firstGap: plan.gapStatusRows)
            if plan.map == .card {
                mapCard
                    .frame(width: plan.columnWidth, height: plan.mapHeight)
                    .padding(.top, plan.gapGridMap)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, plan.bottomInset)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// The lock row, the spot row and the tile grid, 8 × k apart; `firstGap` above the first of them. When
    /// the plan merged the rows (the owner's rule), the lock and the spot share one 44 × k row.
    private func rows(_ plan: LayoutPlan, firstGap: CGFloat) -> some View {
        let locked = nav.lockText != nil
        return VStack(spacing: 0) {
            if plan.merged && (locked || hasSpotRow) {
                mergedRow(plan)
                    .padding(.top, firstGap)
                tileGrid(plan)
                    .padding(.top, plan.gapRows)
            } else {
                separateRows(plan, firstGap: firstGap)
            }
        }
    }

    @ViewBuilder
    private func separateRows(_ plan: LayoutPlan, firstGap: CGFloat) -> some View {
        let locked = nav.lockText != nil
        VStack(spacing: 0) {
            if locked {
                lockRow(plan)
                    .padding(.top, firstGap)
            }
            if hasSpotRow {
                spotRow(plan)
                    .padding(.top, locked ? plan.gapRows : firstGap)
            }
            tileGrid(plan)
                .padding(.top, locked || hasSpotRow ? plan.gapRows : firstGap)
        }
    }

    /// Wide windows and phones on their side (§3.5, C3.4 #5): one full-width header; the dial, readout and
    /// status line centred in the leading pane (24 or more from the bottom); the lock row, the spot row, the
    /// grid (fixed rows, never stretched) and the map card in the trailing pane. Large and Extra Large
    /// centre their short trailing stack.
    private func twoPanes(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            header(plan)
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
                        .padding(.top, plan.gapDialReadout)
                }
                .padding(.horizontal, plan.margin)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                trailingPane(plan)
                    .frame(width: plan.columnWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.trailing, plan.margin)
            }
            .padding(.top, plan.gapHeaderDial)
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
                    .padding(.top, plan.gapGridMap)
            }
        }
    }

    /// Accessibility text sizes (§3.6, C3.4 #6), or nothing fits even with the dial at its floor: one
    /// scrolling list in which every block is complete: the header, a smaller dial, the readout, one
    /// Targets card for the lock and the spot, the tiles as 64 pt rows (caption leading, value trailing),
    /// the map card. The indicator flashes on appear and a 24 pt fade at the bottom is the cue that it
    /// continues. For ImageRenderer, the same stack, clipped.
    @ViewBuilder
    private func listScreen(_ plan: LayoutPlan) -> some View {
        if flatDetails {
            listContent(plan)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
        } else {
            ScrollView {
                listContent(plan)
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

    private func listContent(_ plan: LayoutPlan) -> some View {
        let targets = nav.lockText != nil || hasSpotRow
        return VStack(spacing: 0) {
            header(plan)
                .padding(.top, plan.topInset)
            if let update {
                updateBanner(update)
                    .padding(.top, LayoutPlan.bannerGap)
            }
            dial(side: plan.dial)
                .padding(.top, plan.gapHeaderDial)
            readoutGroup(plan)
                .padding(.top, plan.gapDialReadout)
            if targets {
                targetsCard(plan)
                    .padding(.top, plan.gapStatusRows)
            }
            listTiles(plan)
                .padding(.top, targets ? plan.gapRows : plan.gapStatusRows)
            mapCard
                .frame(width: plan.columnWidth, height: plan.mapHeight)
                .padding(.top, plan.gapGridMap)
        }
        // Room under the last block for the fade.
        .padding(.bottom, plan.bottomInset + LayoutPlan.maxSpare)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: The header bar

    /// 48 high (56 on iPad, × k), on the sky for the sun's altitude here, pinned at the safe top + 8: the
    /// full place name over the date and time with the Sample pill trailing line 2 (line 1 only at
    /// accessibility sizes), then the sky symbol, the map button (only when the map is neither a tile nor a
    /// card) and ⋯, which never moves. Nothing in it is ever ellipsized (C3.4 #4): the date shortens first
    /// ("Nov 1"), then goes; the place scales down rather than lose ", Colorado".
    private func header(_ plan: LayoutPlan) -> some View {
        let k = plan.k
        let ramp = Self.ramp(plan)
        let pillOnPlaceLine = nav.sample && plan.list
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    placeLine(size: ramp.title * k, wraps: plan.list)
                    if pillOnPlaceLine { sampleBadge(k: k) }
                }
                HStack(spacing: 6) {
                    dateText(size: ramp.subtitle * k, wraps: plan.list)
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
            menu
        }
        .foregroundStyle(.white)
        .padding(.leading, 14)
        .padding(.trailing, 2)
        .padding(.vertical, plan.list ? 6 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: plan.headerHeight, maxHeight: plan.list ? nil : plan.headerHeight)
        .skyCard(altitude: nav.sunPosition?.altitude, radius: Look.headerRadius)
    }

    /// "Maroon Bells, Colorado", 17 semibold (22 on iPad): the full name always, at 0.85 if it must, then
    /// scaled further rather than cut. At accessibility sizes it may wrap to two lines.
    @ViewBuilder
    private func placeLine(size: CGFloat, wraps: Bool) -> some View {
        let full = nav.placeTitle
        if wraps {
            Text(full)
                .font(.system(size: size, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                Text(full).lineLimit(1).fixedSize()
                Text(full).font(.system(size: size * Look.minScale, weight: .semibold)).lineLimit(1).fixedSize()
                Text(full).font(.system(size: size * Look.minScale, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .font(.system(size: size, weight: .semibold))
        }
    }

    /// "Sun, Nov 1 · 9:41 AM", then "Nov 1 · 9:41 AM", then "9:41 AM": never an ellipsis in the time.
    @ViewBuilder
    private func dateText(size: CGFloat, wraps: Bool) -> some View {
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
        .font(.system(size: size))
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

    /// Opens the map sheet when the map is neither a tile nor a card (Large and Extra Large).
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

    /// The Sample pill: 13 semibold in a 20 pt capsule on the notice amber.
    static let pillHeight: CGFloat = 20
    private func sampleBadge(k: CGFloat) -> some View {
        Text("Sample")
            .font(.system(size: 13 * k, weight: .semibold))
            .foregroundStyle(Color.black)
            .padding(.horizontal, 7)
            .frame(height: Self.pillHeight * k)
            .background(Capsule().fill(Palette.notice))
            .fixedSize()
    }

    /// The ⋯ menu; for ImageRenderer (`flatDetails`, the self-tests), which can't draw a menu, its symbol alone.
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
            // The first group: the layout, each with a symbol, a subtitle that says what it changes
            // ("Bigger compass · map in header") and a check on the current one.
            Picker(selection: $nav.layout) {
                ForEach(Layout.allCases) { layout in
                    Label {
                        Text(layout.name)
                        Text(layout.subtitle)
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

    // MARK: Dial, readout, status line

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

    /// The status line's slot when there is no compass (two lines allowed, wrapping at the "·"). It carries
    /// what the separate "NO HEADING" caption used to say (C3.2 #3).
    static let noCompassText = "No compass · position, sun and map still work"
    /// What the no-heading readout stands for (VoiceOver and the string checks): an em dash and the degree
    /// sign. It is drawn as a shape, not this glyph (ReadoutGlyphs).
    static let noHeadingText = "\u{2014}°"

    /// The readout and the status line, 6 apart, centred under the dial: two lines, also with no compass.
    private func readoutGroup(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            readout(plan)
            statusLine(plan)
                .padding(.top, plan.gapReadoutStatus)
        }
    }

    /// How far a line of the light system font at `size` reaches above its capitals: trimmed off the
    /// readout's line box, so the 12 under the dial runs to the digits' cap height (C2.3 #7).
    static func capInset(size: CGFloat) -> CGFloat {
        let font = PlatformFont.systemFont(ofSize: size, weight: .light)
        return max(0, font.ascender - font.capHeight)
    }

    /// The light system font's cap height at `size`: the no-heading dash sits on its midline.
    static func capHeight(size: CGFloat) -> CGFloat {
        PlatformFont.systemFont(ofSize: size, weight: .light).capHeight
    }

    /// The width of `text` in the system font with tabular digits, for the self-tests' fit checks.
    fileprivate static func textWidth(_ text: String, size: CGFloat, weight: PlatformFont.Weight) -> CGFloat {
        let font = PlatformFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// "228° SW", unchanged in style, in a block trimmed to the digits' cap height. With no heading, a drawn
    /// dash at white 40% where the digits would be, and the degree sign where it sits after "228".
    private func readout(_ plan: LayoutPlan) -> some View {
        let big = plan.headingSize
        let spokenHeading = nav.heading.map { "Heading \(Int($0.rounded()) % 360) degrees, \(Geo.pointName($0).lowercased())" }
        return ReadoutGlyphs(heading: nav.heading, size: big, pointColor: secondary)
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

    /// The owner's rule, the last step before the list (LayoutPlan's `merged`): the lock and the spot share
    /// one 44 × k row, side by side at (C − 8) / 2 each (either alone takes the whole row), each value at
    /// 15 × k semibold with its ✕, the lock on its maroon fill and the spot on the tile fill.
    private func mergedRow(_ plan: LayoutPlan) -> some View {
        let k = plan.k, height = LayoutPlan.mergedHeight(k: k)
        let both = nav.lockText != nil && hasSpotRow
        let width = both ? (plan.columnWidth - LayoutPlan.rowGap) / 2 : plan.columnWidth
        let shape = RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
        return HStack(spacing: LayoutPlan.rowGap) {
            if let text = nav.lockText {
                HStack(spacing: 0) {
                    FitText(text: Self.keepTogether(text), size: 15 * k, weight: .semibold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(text.replacingOccurrences(of: "°", with: " degrees").replacingOccurrences(of: " · ", with: ", "))
                        .accessibilityActions {
                            Button("Unlock Bearing") { nav.toggleLock() }
                        }
                    closeButton(k: k, label: "Unlock Bearing") { nav.toggleLock() }
                }
                .foregroundStyle(.white)
                .padding(.leading, Look.tilePaddingH)
                .padding(.trailing, 4)
                .frame(width: width, height: height)
                .background(shape.fill(Palette.lockFill))
                .overlay(shape.strokeBorder(Palette.lockBorder, lineWidth: Look.stroke))
            }
            if hasSpotRow {
                HStack(spacing: 0) {
                    mergedSpotLabel(k: k)
                    closeButton(k: k, label: "Clear Marked Spot") { nav.clearSpot() }
                }
                .padding(.leading, Look.tilePaddingH)
                .padding(.trailing, 4)
                .frame(width: width, height: height)
                .frostedTile()
            }
        }
        .frame(width: plan.columnWidth, height: height)
    }

    /// The merged row's spot value, opening the spot's menu as the spot row does.
    @ViewBuilder
    private func mergedSpotLabel(k: CGFloat) -> some View {
        let label = FitText(text: Self.keepTogether(nav.spotText ?? ""), size: 15 * k, weight: .semibold)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        if flatDetails {
            label
        } else {
            Menu {
                Button("Lock to Spot", systemImage: "scope") { nav.lockToSpot() }
                Button("Clear Marked Spot", systemImage: "mappin.slash") { nav.clearSpot() }
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Marked spot, \(spotSpoken)")
            .accessibilityActions {
                Button("Lock to Spot") { nav.lockToSpot() }
                Button("Clear") { nav.clearSpot() }
            }
        }
    }

    /// The locked bearing (C3.4 #7, one component on both ports): 52 high, #3D2128 with a 1 pt #5A2C38
    /// border, "Locked 240°" leading at 17 regular, "turn 12° right" trailing at 17 semibold (12 or more
    /// between them, never split inside a value), and a ✕ (18) in a 44 × 44 target 4 in from the edge.
    private func lockRow(_ plan: LayoutPlan) -> some View {
        let k = plan.k, height = LayoutPlan.lockHeight(k: k)
        let text = nav.lockText ?? ""
        let parts = Self.lockParts(text)
        let spokenText = text.replacingOccurrences(of: "°", with: " degrees").replacingOccurrences(of: " · ", with: ", ")
        let shape = RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
        return HStack(spacing: 0) {
            TwoColumnText(label: parts.label, value: parts.cue, size: 17 * k, wraps: plan.list)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenText)
                .accessibilityActions {
                    Button("Unlock Bearing") { nav.toggleLock() }
                }
            closeButton(k: k, label: "Unlock Bearing") { nav.toggleLock() }
        }
        .foregroundStyle(.white)
        .padding(.leading, Look.tilePaddingH)
        .padding(.trailing, 4)
        .frame(width: plan.columnWidth)
        .frame(minHeight: height, maxHeight: plan.list ? nil : height)
        .background(shape.fill(Palette.lockFill))
        .overlay(shape.strokeBorder(Palette.lockBorder, lineWidth: Look.stroke))
        .accessibilityElement(children: .contain)
    }

    /// The ✕ of the lock and spot rows: an 18 pt glyph in a 44 × 44 target.
    private func closeButton(k: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 18 * k, weight: .semibold))
                .foregroundStyle(Color.white.opacity(nav.nightMode ? Palette.nightSecondary : Palette.Op.body))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    /// The marked spot, on the same two-column rule on the neutral tile fill, 52 high: "Marked spot"
    /// leading, "9.2 mi · 46° NE" trailing, and the ✕. The row opens a small menu (Lock to Spot, Clear).
    private func spotRow(_ plan: LayoutPlan) -> some View {
        let k = plan.k, height = LayoutPlan.spotHeight(k: k)
        return HStack(spacing: 0) {
            spotLabel(plan)
            closeButton(k: k, label: "Clear Marked Spot") { nav.clearSpot() }
        }
        .padding(.leading, Look.tilePaddingH)
        .padding(.trailing, 4)
        .frame(width: plan.columnWidth)
        .frame(minHeight: height, maxHeight: plan.list ? nil : height)
        .frostedTile()
    }

    /// "0.4 miles, 245 degrees southwest" (the point in words, as the dial's value says it).
    private var spotSpoken: String {
        if let d = nav.spotDistance, let b = nav.spotBearing {
            let shown = nav.cardAngle(b)
            return "\(Self.spoken(Geo.distanceText(d, feet: nav.feet))), \(Int(Geo.jsRound(shown)) % 360) degrees \(Geo.pointName(shown).lowercased())"
        }
        return Self.spoken((nav.spotText ?? "").replacingOccurrences(of: " · ", with: ", ").replacingOccurrences(of: "°", with: " degrees"))
    }

    /// The spot's two columns, opening the spot's menu (ImageRenderer, which can't draw a menu: the row alone).
    @ViewBuilder
    private func spotLabel(_ plan: LayoutPlan) -> some View {
        let label = TwoColumnText(label: "Marked spot", value: Self.keepTogether(nav.spotText ?? ""), size: 17 * plan.k,
                                  wraps: plan.list)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        if flatDetails {
            label
        } else {
            Menu {
                Button("Lock to Spot", systemImage: "scope") { nav.lockToSpot() }
                Button("Clear Marked Spot", systemImage: "mappin.slash") { nav.clearSpot() }
            } label: {
                label
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .accessibilityLabel("Marked spot, \(spotSpoken)")
            .accessibilityActions {
                Button("Lock to Spot") { nav.lockToSpot() }
                Button("Clear") { nav.clearSpot() }
            }
        }
    }

    /// Accessibility sizes (C3.4 #6): the lock and the spot in one "Targets" card, a 44 line each, the values
    /// free to wrap.
    private func targetsCard(_ plan: LayoutPlan) -> some View {
        let k = plan.k
        let text = nav.lockText
        return VStack(spacing: 0) {
            if let text {
                let parts = Self.lockParts(text)
                HStack(spacing: 0) {
                    TwoColumnText(label: parts.label, value: parts.cue, size: 17 * k, wraps: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(text.replacingOccurrences(of: "°", with: " degrees").replacingOccurrences(of: " · ", with: ", "))
                    closeButton(k: k, label: "Unlock Bearing") { nav.toggleLock() }
                }
                .frame(minHeight: LayoutPlan.targetsLine * k)
            }
            if hasSpotRow {
                HStack(spacing: 0) {
                    spotLabel(plan)
                    closeButton(k: k, label: "Clear Marked Spot") { nav.clearSpot() }
                }
                .frame(minHeight: LayoutPlan.targetsLine * k)
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, LayoutPlan.targetsPadding * k)
        .padding(.leading, Look.tilePaddingH)
        .padding(.trailing, 4)
        .frame(width: plan.columnWidth)
        .frostedTile()
    }

    // MARK: The tile grid

    /// The grid exactly as the plan's `cells` give it, rows 8 × k apart and tiles 8 apart: Medium's
    /// 3 columns (Position 2u | Elevation, then Sun | Moon | Map), Large's 2 × 2 (Position | Elevation, Sun |
    /// Moon), the compact row of Small and Extra Large (Position | Elevation | Sun, the moon in Sun's
    /// caption). Every row's widths and gutters add up to C.
    @ViewBuilder
    private func tileGrid(_ plan: LayoutPlan) -> some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
                .frame(width: plan.columnWidth, height: plan.gridHeight)
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                gridContent(plan, stale: stale)
            }
        }
    }

    private func gridContent(_ plan: LayoutPlan, stale: Bool) -> some View {
        VStack(spacing: plan.gapRows) {
            ForEach(Array(plan.cells.enumerated()), id: \.offset) { _, row in
                HStack(spacing: LayoutPlan.rowGap) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        tileView(cell.tile, plan: plan, stale: stale)
                            .frame(width: cell.width, height: plan.tileHeight)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func tileView(_ tile: LayoutPlan.Tile, plan: LayoutPlan, stale: Bool) -> some View {
        let compact = plan.grid == .compact
        switch tile {
        case .position: positionTile(plan, stale: stale, compact: compact)
        case .elevation: elevationTile(plan, stale: stale)
        case .sun: sunTile(plan, compact: compact)
        case .moon: moonTile(plan)
        case .map: mapTile
        }
    }

    /// Accessibility sizes: every tile a full-width row of 64 or more, caption leading, value trailing,
    /// values wrapping.
    @ViewBuilder
    private func listTiles(_ plan: LayoutPlan) -> some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
                .frame(width: plan.columnWidth)
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                VStack(spacing: plan.gapRows) {
                    ForEach(Array(plan.cells.joined().enumerated()), id: \.offset) { _, cell in
                        tileView(cell.tile, plan: plan, stale: stale)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: cell.width)
                    }
                }
            }
        }
    }

    /// "Finding position…" under a "—", before the first fix (never blank).
    private var waitingText: String { nav.access == .allowed || nav.locating ? "Finding position…" : "Not known yet" }

    /// A tile's value: 17 medium (22 semibold on iPad; 15 in the compact row), tabular, white (dimmed when
    /// the fix is stale). Scales to 0.85, then wraps; never ellipsized.
    private func valueText(_ text: String, plan: LayoutPlan, stale: Bool = false, size: CGFloat? = nil) -> some View {
        let ramp = Self.ramp(plan)
        return FitText(text: text, size: (size ?? ramp.value) * plan.k, weight: ramp.valueWeight, wraps: plan.list)
            .monospacedDigit()
            .foregroundStyle(stale ? secondary : .white)
    }

    /// POSITION · DD: latitude over longitude at one shared size (C3.4 #12), or one grid reference at 20
    /// (26 on iPad). Tap for the next format; long-press (right-click on a Mac) for Copy and Details….
    private func positionTile(_ plan: LayoutPlan, stale: Bool, compact: Bool) -> some View {
        let ramp = Self.ramp(plan)
        let formatted = nav.fix.map { Geo.format(nav.format, lat: $0.latitude, lon: $0.longitude) }
        let lines: [String], spokenValue: String
        switch formatted {
        case let .some(.pair(lat, lon)):
            lines = [lat, lon]
            spokenValue = "\(Self.spokenCoordinate(lat)), \(Self.spokenCoordinate(lon))"
        case let .some(.single(value)):
            lines = [value]
            spokenValue = value
        case .none:
            lines = ["—"]
            spokenValue = waitingText.lowercased()
        }
        // "decimal degrees", but "UTM" and "MGRS" stay in capitals so they're spelled out.
        let name = nav.format.name
        let formatWords = name == name.uppercased() ? name : name.lowercased()
        let size: CGFloat
        if lines.count == 1 && nav.fix != nil {
            size = compact ? ramp.compactValue : ramp.singleValue
        } else {
            size = compact ? ramp.compactValue : ramp.value
        }
        return CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
            PanelTile("Position · \(Self.shortName(nav.format))", secondary: nav.fix == nil ? waitingText : nil) {
                PositionValue(lines: lines, size: size * plan.k, weight: ramp.valueWeight, wraps: plan.list)
                    .foregroundStyle(stale ? secondary : .white)
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

    /// SUN (a text-only caption, C3.4 #13): "↑ 6:36 AM" over "↓ 5:08 PM" (one formatter, Look.time, in the
    /// device's 12- or 24-hour style), or "Up all day" / "Down all day". In the compact row the values are
    /// 15 semibold and the moon rides in the caption ("SUN · ◐ 53%"). Tap: the Details sheet.
    private func sunTile(_ plan: LayoutPlan, compact: Bool) -> some View {
        let k = plan.k
        let ramp = Self.ramp(plan)
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
        let base = compact ? ramp.compactValue : ramp.value
        let weight: Font.Weight = compact ? .semibold : ramp.valueWeight
        return PanelTile("Sun", moon: compact ? phase : nil, secondary: times == nil ? waitingText : nil) {
            if let rise, let down {
                VStack(alignment: .leading, spacing: -2) {
                    SunTime(arrow: "↑", time: Look.time(rise), size: base * k, weight: weight, k: k, wraps: plan.list)
                    SunTime(arrow: "↓", time: Look.time(down), size: base * k, weight: weight, k: k, wraps: plan.list)
                }
                .monospacedDigit()
            } else if let times {
                valueText(times.polar == .day ? "Up all day" : "Down all day", plan: plan, size: base)
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
        let ramp = Self.ramp(plan)
        return PanelTile("Moon", secondary: Look.phaseName(phase)) {
            HStack(spacing: 6) {
                MoonGlyph(phase: phase.phase, size: (ramp.value - 2) * plan.k)
                valueText("\(percent)%", plan: plan)
            }
        }
        .panelAction("Moon, \(percent) percent lit, \(Look.phaseName(phase).lowercased())", hint: "Shows the details") { showDetails = true }
    }

    /// MAP (C3.4 #9): a still map picture north up with your dot and heading cone, no controls or gestures,
    /// on a 24 pt bottom band with "MAP" and the expand glyph leading and the Maps attribution trailing.
    /// One element for VoiceOver. Tap: the map sheet, which carries the full Legal link.
    private var mapTile: some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: .constant(false), satellite: nav.satellite,
                   dimmed: nav.nightMode, thumbnail: true)
            .allowsHitTesting(false)
            // The picture takes no touches; this clear layer takes the tap for the whole tile.
            .overlay { Color.clear.contentShape(Rectangle()) }
            .panelAction("Map, opens full map", hint: "Opens the map") { nav.mapSheet = true }
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

/// One tile, the same component everywhere (docs/REFINE.md §3.2, C2.3 #6 and C3.4 #13, the widgets'
/// pattern): a text-only caps caption (for the compact row's Sun, the moon's glyph and percentage after it)
/// pinned to the top inset, and the value block (value and second line) pinned to the bottom inset, so a
/// grown tile is never half empty at the bottom. Leading-aligned on a frosted fill (radius 16). Sizes from
/// the type ramp (iPad's own). In the scrolling list it is a row: caption leading, value trailing, 64 or
/// more high. The caller sets its frame.
struct PanelTile<Value: View>: View {
    let caption: String
    var moon: Sky.Phase?
    var secondary: String?
    let value: Value
    @Environment(\.uiScale) private var k
    @Environment(\.nightText) private var night
    @Environment(\.panelRamp) private var ramp
    @Environment(\.panelRows) private var rows

    init(_ caption: String, moon: Sky.Phase? = nil, secondary: String? = nil, @ViewBuilder value: () -> Value) {
        self.caption = caption
        self.moon = moon
        self.secondary = secondary
        self.value = value()
    }

    var body: some View {
        if rows {
            HStack(alignment: .center, spacing: 12) {
                captionRow
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    value
                    if let secondary {
                        FitText(text: secondary, size: ramp.secondary * k, wraps: true)
                            .foregroundStyle(Palette.secondary(night: night))
                    }
                }
                .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, ramp.insetH)
            .padding(.vertical, ramp.insetV)
            .frame(maxWidth: .infinity, minHeight: LayoutPlan.listRow * k, alignment: .leading)
            .frostedTile()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                captionRow
                Spacer(minLength: 2)
                VStack(alignment: .leading, spacing: 0) {
                    value
                    if let secondary {
                        FitText(text: secondary, size: ramp.secondary * k)
                            .foregroundStyle(Palette.secondary(night: night))
                    }
                }
            }
            .padding(.horizontal, ramp.insetH)
            .padding(.vertical, ramp.insetV)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frostedTile()
        }
    }

    /// "SUN · ◐ 53%": scaled to 0.85 when too wide; the words never truncate.
    private var captionRow: some View {
        ViewThatFits(in: .horizontal) {
            captionContent
            captionContent
                .scaleEffect(Look.minScale, anchor: .leading)
        }
        .foregroundStyle(Palette.secondary(night: night))
    }

    private var captionContent: some View {
        HStack(spacing: 3) {
            Text(caption.uppercased())
                .tracking(Look.tileCaptionTracking)
            if let moon {
                Text("·")
                MoonGlyph(phase: moon.phase, size: ramp.caption * k)
                Text("\(Int(Geo.jsRound(moon.fraction * 100)))%")
                    .monospacedDigit()
            }
        }
        .font(.system(size: ramp.caption * k, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
    }
}

/// The Position value (C3.4 #12): latitude over longitude, or one grid reference, all at one size: the
/// size that fits the longer line, then 0.85 of it, then wrapped at 0.85. Never each line on its own.
struct PositionValue: View {
    let lines: [String]
    let size: CGFloat
    var weight: Font.Weight = .medium
    var wraps = false

    var body: some View {
        if wraps {
            stack(size)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            ViewThatFits(in: .horizontal) {
                stack(size)
                    .lineLimit(1)
                    .fixedSize()
                stack(size * Look.minScale)
                    .lineLimit(1)
                    .fixedSize()
                stack(size * Look.minScale)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stack(_ size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: -2) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
            }
        }
        .font(.system(size: size, weight: weight))
        .monospacedDigit()
    }
}

/// The lock and spot rows' two columns (C3.4 #7): the label leading at regular weight, the value trailing
/// at semibold, 12 or more between them. In the scrolling list, the value drops under the label when the
/// two don't fit on one line.
struct TwoColumnText: View {
    let label: String
    let value: String
    let size: CGFloat
    var wraps = false

    var body: some View {
        if wraps {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    Text(label).font(.system(size: size)).lineLimit(1).fixedSize()
                    Spacer(minLength: 12)
                    Text(value).font(.system(size: size, weight: .semibold)).lineLimit(1).fixedSize()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(label).font(.system(size: size))
                    Text(value).font(.system(size: size * 15 / 17, weight: .semibold))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .monospacedDigit()
        } else {
            HStack(spacing: 0) {
                Text(label).font(.system(size: size)).lineLimit(1).fixedSize()
                Spacer(minLength: 12)
                FitText(text: value, size: size, weight: .semibold)
                    .multilineTextAlignment(.trailing)
            }
            .monospacedDigit()
        }
    }
}

/// The readout's glyphs: "228°" light with the point ("SW") at half size; with no heading (C3.2 #3) a dash
/// drawn as a shape, 0.5 em × 0.08 em at white 40%, centred on the digits' cap-height midline in the
/// width of three digits, and the degree sign after it where it sits after "228". (The em-dash glyph sat
/// on the baseline and drew as "_ °".)
struct ReadoutGlyphs: View {
    var heading: Double?
    var size: CGFloat
    var pointColor: Color = Color.white.opacity(Palette.Op.caption)

    /// The dash, in em.
    static let dashWidth: CGFloat = 0.5
    static let dashHeight: CGFloat = 0.08

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let h = heading {
                Text("\(Int(h.rounded()) % 360)°")
                    .font(.system(size: size, weight: .light))
                    .foregroundStyle(.white)
                    .tracking(-2)
                Text(Geo.point(h))
                    .font(.system(size: size / 2, weight: .medium))
                    .foregroundStyle(pointColor)
                    .frame(minWidth: size, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    ZStack(alignment: Alignment(horizontal: .center, vertical: .firstTextBaseline)) {
                        // Three digits' width, so the degree sign lands where it does after "228".
                        Text("000")
                            .tracking(-2)
                            .hidden()
                        RoundedRectangle(cornerRadius: size * Self.dashHeight / 2, style: .continuous)
                            .fill(Color.white.opacity(0.4))
                            .frame(width: size * Self.dashWidth, height: size * Self.dashHeight)
                            // Its middle on the capitals' midline: the baseline is half the cap height
                            // under the dash's middle.
                            .alignmentGuide(.firstTextBaseline) { d in d.height / 2 + MainView.capHeight(size: size) / 2 }
                    }
                    Text("°")
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .font(.system(size: size, weight: .light))
            }
        }
        .monospacedDigit()
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

// MARK: Checks for the self-tests: what must fit (C2's "no … anywhere"), and what is drawn (C3)

extension MainView {
    /// Measures what the tiles and the header must hold, in the system font, on every Apple device of the
    /// planner's table at Text Size 1.0 and 1.3, and checks that the strings the tiles, the lock row and the
    /// header show never carry "…" (and that the lock row's values can't split). Each failure is one line;
    /// empty when all is well.
    static func fitFailures(sunrise: Date, sunset: Date, now: Date, lat: Double, lon: Double,
                            place: String = "Maroon Bells, Colorado") -> [String] {
        var failures: [String] = []
        let times = [Look.time(sunrise), Look.time(sunset)]
        let dates = dateLines(now)
        // The strings themselves.
        var shown: [String] = [dates.full, dates.short, dates.time, Look.timeText(sunrise), Look.timeText(sunset),
                               noHeadingText, noCompassText, place]
        for format in Geo.Format.allCases {
            switch Geo.format(format, lat: lat, lon: lon) {
            case let .pair(a, b): shown += [a, b]
            case let .single(value): shown.append(value)
            }
        }
        for text in shown where text.contains("…") { failures.append("\"\(text)\" has an ellipsis") }
        // The lock row: "Locked 240°" and "turn 12° right" never split inside a value (C3.4 #7).
        let lock = lockParts("Locked 240° · turn 12° right")
        if lock.label.contains(" ") || lock.cue.contains(" ") || lock.label != "Locked\u{00A0}240°" {
            failures.append("The lock row's values can split: \"\(lock.label)\" / \"\(lock.cue)\"")
        }

        let dd = Geo.format(.dd, lat: lat, lon: lon)
        let pill = textWidth("Sample", size: 13, weight: .semibold) + 14 + 6
        // Apple's devices only (an Android font is not this one).
        for d in LayoutPlan.devices where !d.name.hasPrefix("Android") && !d.name.hasPrefix("Pixel") {
            for k in [CGFloat(1), 1.3] {
                for layout in Layout.allCases {
                    let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, hasSpot: true, locked: true, mac: d.mac)
                    let name = "\(d.name) \(layout.rawValue) k\(k)"
                    let ramp = Self.ramp(p)
                    if !p.list {
                        // The header: the sky symbol, the map button (when shown) and ⋯ trail; line 2 holds at
                        // least the time and the Sample pill, and line 1 the full place at 0.85.
                        let headerWidth = p.twoPane ? d.w - 2 * p.margin : p.columnWidth
                        let trailing: CGFloat = 20 + 8 + 44 + 8 + (p.mapInHeader ? 44 + 8 : 0) + 4
                        let room = headerWidth - 16 - trailing
                        if textWidth(dates.time, size: ramp.subtitle * k, weight: .regular) + pill * k > room + 0.5 {
                            failures.append("\(name): the header time and Sample don't fit (\(Int(room)) pt)")
                        }
                        if k == 1 && textWidth(place, size: ramp.title * Look.minScale, weight: .semibold) > room + 0.5 {
                            failures.append("\(name): \"\(place)\" doesn't fit at 0.85 (\(Int(room)) pt)")
                        }
                    }
                    for cell in p.cells.joined() {
                        let room = cell.width - 2 * ramp.insetH
                        let compact = p.grid == .compact
                        switch cell.tile {
                        case .sun:
                            // Some step of the Sun ladder fits (at the latest, the time over its "AM").
                            let size = (compact ? ramp.compactValue : ramp.value) * k * Look.minScale
                            let weight: PlatformFont.Weight = compact || p.tablet ? .semibold : .medium
                            for t in times {
                                let clock = textWidth("↑\u{00A0}\(t.clock)", size: size, weight: weight)
                                let period = t.period.map { textWidth($0, size: Look.periodSize * k, weight: weight) } ?? 0
                                if max(clock, period) > room + 0.5 {
                                    failures.append("\(name): Sun \(t.clock) needs \(Int(max(clock, period))) of \(Int(room)) pt")
                                }
                            }
                        case .position where k == 1 && !p.list:
                            // Decimal degrees (the default): the longitude fits on one line at 0.85.
                            if case let .pair(_, lonText) = dd {
                                let size = (compact ? ramp.compactValue : ramp.value) * Look.minScale
                                let width = textWidth(lonText, size: size, weight: p.tablet ? .semibold : .medium)
                                if width > room + 0.5 { failures.append("\(name): \(lonText) needs \(Int(width)) of \(Int(room)) pt") }
                            }
                        default:
                            break
                        }
                    }
                }
            }
        }
        return failures
    }

    /// The no-heading readout as drawn (C3.2 #3, the check that would have caught "_ °"): at the phone,
    /// Extra Large and iPad sizes, the dash's vertical centre is within 4 pt of the digits' centre-line in
    /// "228°", it is about 0.5 em wide, and it is thin. Empty when all is well.
    @MainActor
    static func dashFailures() -> [String] {
        var failures: [String] = []
        for size in [LayoutPlan.heading, LayoutPlan.heading * 1.25, LayoutPlan.headingTablet] {
            guard let digits = Pixels(render: glyphCanvas(heading: 228, size: size)),
                  let dash = Pixels(render: glyphCanvas(heading: nil, size: size)) else {
                failures.append("The readout at \(Int(size)) pt didn't draw")
                continue
            }
            // The digits' slot, clear of the degree sign.
            let slot = textWidth("000", size: size, weight: .light) * 0.8
            guard let a = digits.inkRows(x0: canvasInset, x1: canvasInset + slot, threshold: 60),
                  let b = dash.inkRows(x0: canvasInset, x1: canvasInset + slot, threshold: 30) else {
                failures.append("The readout at \(Int(size)) pt: no ink where the digits go")
                continue
            }
            let digitMid = (a.top + a.bottom) / 2, dashMid = (b.top + b.bottom) / 2
            if abs(digitMid - dashMid) > 4 {
                failures.append(String(format: "The no-heading dash at %.0f pt is centred at %.1f, the digits at %.1f", size, dashMid, digitMid))
            }
            if b.bottom - b.top > size * 0.15 {
                failures.append("The no-heading dash at \(Int(size)) pt is \(Int(b.bottom - b.top)) pt tall")
            }
            if let c = dash.inkColumns(y0: b.top, y1: b.bottom, x0: canvasInset, x1: canvasInset + slot / 0.8, threshold: 30) {
                let width = c.right - c.left
                if width < size * 0.4 || width > size * 0.6 {
                    failures.append("The no-heading dash at \(Int(size)) pt is \(Int(width)) pt wide, not about \(Int(size / 2))")
                }
            }
        }
        return failures
    }

    private static let canvasInset: CGFloat = 8

    private static func glyphCanvas(heading: Double?, size: CGFloat) -> some View {
        ReadoutGlyphs(heading: heading, size: size)
            .padding(canvasInset)
            .frame(width: size * 5, height: size * 2, alignment: .topLeading)
            .background(Color.black)
    }

    /// Both Position lines at one size (C3.4 #12), as drawn: in a tile too narrow for the longer line at its
    /// size, the two lines' ink is the same height. Empty when all is well.
    @MainActor
    static func positionSizeFailures() -> [String] {
        let view = PositionValue(lines: ["39.09898° N", "106.94117° W"], size: 20)
            .foregroundStyle(.white)
            .frame(width: 130, height: 80, alignment: .topLeading)
            .background(Color.black)
        guard let px = Pixels(render: view) else { return ["The Position value didn't draw"] }
        let bands = px.inkBands(threshold: 60)
        guard bands.count >= 2 else { return ["The Position value drew \(bands.count) line(s)"] }
        let heights = bands.map { $0.bottom - $0.top }
        if let low = heights.min(), let high = heights.max(), high - low > 1 {
            return [String(format: "The Position lines are drawn at two sizes (%.1f and %.1f pt tall)", low, high)]
        }
        return []
    }

    /// The whole screen as drawn, checked against its plan, in every layout and in the sample, no-compass and
    /// live (nothing locked or marked) states (C3.2 #1–#2, C3.4's tests): the header's top is at the plan's
    /// inset in every one (it never jumps); each grid row has as many tiles as the plan's row, at the planned
    /// height, and a map card is where planned; the empty band at the bottom is what the plan left (24 or
    /// less unless the plan centred the panel); and neighbouring layouts draw different grids. `nav` is a
    /// navigator of its own (its sample state is changed). Returns failures and info lines.
    @MainActor
    static func drawingFailures(nav: Navigator, width: CGFloat, height: CGFloat) -> (failures: [String], info: [String]) {
        var failures: [String] = [], info: [String] = []
        let states: [(name: String, apply: () -> Void)] = [
            ("sample", { nav.showSample(lock: 240) }),
            ("no compass", { nav.showSample(noCompass: true) }),
            ("live", { nav.showSample(); nav.clearSpot() }),
        ]
        let size = "\(Int(width)) × \(Int(height))"
        for state in states {
            state.apply()
            var signatures: [[Int]] = []
            var plans: [LayoutPlan] = []
            for layout in Layout.allCases {
                nav.showLayout(layout.rawValue)
                let plan = LayoutPlan.plan(w: width, h: height, s: height, layout: layout,
                                           hasSpot: nav.spot != nil && nav.fix != nil, locked: nav.lockText != nil,
                                           noCompass: nav.noCompass, mac: isMac)
                let name = "\(size) \(layout.rawValue) \(state.name)"
                plans.append(plan)
                // The owner's rule: in one column, taller than wide, the dial is 0.40 H or more.
                if !plan.twoPane && height >= width && plan.dial < plan.ownerFloor(h: height) - 0.5 {
                    failures.append("\(name): dial \(Int(plan.dial)) under the owner's 0.40 H (\(Int(plan.ownerFloor(h: height))))")
                }
                guard !plan.list && !plan.twoPane else {
                    info.append("\(name): \(plan.list ? "scrolling list" : "two panes"), not checked")
                    signatures.append([])
                    continue
                }
                let screen = MainView()
                    .environmentObject(nav)
                    .environment(\.flatDetails, true)
                    .frame(width: width, height: height)
                guard let px = Pixels(render: screen) else {
                    failures.append("\(name): nothing drawn")
                    signatures.append([])
                    continue
                }
                // The header is pinned: its sky starts at the top inset.
                if let top = px.firstInk(x: width / 2, threshold: 30), abs(top - plan.topInset) > 1.5 {
                    failures.append(String(format: "%@: the header starts at %.1f, planned %.0f", name, top, plan.topInset))
                }
                // The grid as drawn: tiles per row at each planned row, then the map card.
                let x0 = (width - plan.columnWidth) / 2 - 4, x1 = (width + plan.columnWidth) / 2 + 4
                var signature: [Int] = []
                for (i, row) in plan.cells.enumerated() {
                    let y = plan.gridTop + CGFloat(i) * (plan.tileHeight + plan.gapRows) + plan.tileHeight / 2
                    let drawn = px.segments(y: y, x0: x0, x1: x1)
                    signature.append(drawn)
                    if drawn != row.count {
                        failures.append("\(name): grid row \(i + 1) draws \(drawn) tile(s), planned \(row.count)")
                    }
                }
                if plan.map == .card {
                    let y = plan.gridTop + plan.gridHeight + plan.gapGridMap + plan.mapHeight / 2
                    let drawn = px.segments(y: y, x0: x0, x1: x1)
                    signature.append(drawn == 1 ? 100 : drawn)
                    if drawn != 1 { failures.append("\(name): no map card where planned") }
                }
                signatures.append(signature)
                // The bottom: what the plan left, and no more than 24 over the inset unless centred.
                if let last = px.lastInkRow(threshold: 10) {
                    let band = height - last
                    let planned = plan.bottomInset + plan.bottomSpare
                    if abs(band - planned) > 2 {
                        failures.append(String(format: "%@: %.0f empty at the bottom, planned %.0f", name, band, planned))
                    }
                    if !plan.centred && band > plan.bottomInset + LayoutPlan.maxSpare + 1 {
                        failures.append(String(format: "%@: %.0f empty at the bottom", name, band))
                    }
                    if plan.centred { info.append(String(format: "%@: centred, %.0f over and under the panel", name, plan.bottomSpare)) }
                }
                info.append("\(name): \(plan.description)")
            }
            // Neighbouring layouts draw different grids (Large is not Medium plus 24), unless one of them gave
            // up its grid or map card to keep the owner's 0.40 H.
            for (i, layout) in Layout.allCases.enumerated().dropLast() {
                let a = signatures[i], b = signatures[i + 1]
                if !a.isEmpty && a == b && !plans[i].yielded && !plans[i + 1].yielded {
                    failures.append("\(size) \(state.name): \(layout.rawValue) and \(Layout.allCases[i + 1].rawValue) draw the same grid \(a)")
                }
            }
        }
        return (failures, info)
    }
}

/// A drawing's pixels, for the self-tests' checks of what is drawn (row 0 at the top, in points through
/// `scale`).
struct Pixels {
    let width: Int
    let height: Int
    let scale: CGFloat
    private let bytes: [UInt8]

    @MainActor
    init?<V: View>(render view: V, scale: CGFloat = 2) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        self.init(image, scale: scale)
    }

    init?(_ image: CGImage, scale: CGFloat) {
        let w = image.width, h = image.height
        guard w > 0, h > 0 else { return nil }
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            // On black, as the screen is: anything left transparent reads as black.
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: w, height: h))
            context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        width = w
        height = h
        self.scale = scale
        bytes = data
    }

    /// The brightest channel at a pixel, 0…255 (0 outside).
    func level(_ x: Int, _ y: Int) -> Int {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        let i = (y * width + x) * 4
        return Int(max(bytes[i], bytes[i + 1], bytes[i + 2]))
    }

    /// The top and bottom (points) of everything brighter than `threshold` between x0 and x1 (points).
    func inkRows(x0: CGFloat, x1: CGFloat, threshold: Int) -> (top: CGFloat, bottom: CGFloat)? {
        let a = max(0, Int(x0 * scale)), b = min(width, Int(x1 * scale))
        guard a < b else { return nil }
        var top: Int?, bottom: Int?
        for y in 0..<height {
            for x in a..<b where level(x, y) > threshold {
                if top == nil { top = y }
                bottom = y
                break
            }
        }
        guard let top, let bottom else { return nil }
        return (CGFloat(top) / scale, CGFloat(bottom + 1) / scale)
    }

    /// The left and right (points) of everything brighter than `threshold` between y0 and y1 and x0 and x1.
    func inkColumns(y0: CGFloat, y1: CGFloat, x0: CGFloat, x1: CGFloat, threshold: Int) -> (left: CGFloat, right: CGFloat)? {
        let top = max(0, Int(y0 * scale)), bottom = min(height, Int((y1 * scale).rounded(.up)))
        let a = max(0, Int(x0 * scale)), b = min(width, Int(x1 * scale))
        guard top < bottom, a < b else { return nil }
        var left: Int?, right: Int?
        for x in a..<b {
            for y in top..<bottom where level(x, y) > threshold {
                if left == nil { left = x }
                right = x
                break
            }
        }
        guard let left, let right else { return nil }
        return (CGFloat(left) / scale, CGFloat(right + 1) / scale)
    }

    /// Runs of rows with ink anywhere across, top to bottom (points): the lines of a block of text.
    func inkBands(threshold: Int) -> [(top: CGFloat, bottom: CGFloat)] {
        var bands: [(top: CGFloat, bottom: CGFloat)] = []
        var start: Int?
        for y in 0...height {
            let ink = y < height && (0..<width).contains { level($0, y) > threshold }
            if ink && start == nil { start = y }
            if !ink, let s = start {
                bands.append((CGFloat(s) / scale, CGFloat(y) / scale))
                start = nil
            }
        }
        return bands
    }

    /// How many separate things a row at y crosses between x0 and x1 (points): runs of ink (`ink` or
    /// brighter, as a frosted tile) split by `gap` points or more of black (a gutter).
    func segments(y: CGFloat, x0: CGFloat, x1: CGFloat, ink: Int = 10, gap: CGFloat = 4) -> Int {
        let row = Int(y * scale), a = max(0, Int(x0 * scale)), b = min(width, Int(x1 * scale))
        guard a < b, row >= 0, row < height else { return 0 }
        let minDark = Int(gap * scale)
        var count = 0, inside = false, dark = 0
        for x in a..<b {
            if level(x, row) >= ink {
                if !inside {
                    count += 1
                    inside = true
                }
                dark = 0
            } else if inside {
                dark += 1
                if dark >= minDark { inside = false }
            }
        }
        return count
    }

    /// The first row from the top (points) with ink brighter than `threshold` in the column at x.
    func firstInk(x: CGFloat, threshold: Int) -> CGFloat? {
        let column = Int(x * scale)
        for y in 0..<height where level(column, y) > threshold { return CGFloat(y) / scale }
        return nil
    }

    /// The bottom (points) of the last row with ink brighter than `threshold` anywhere across.
    func lastInkRow(threshold: Int) -> CGFloat? {
        for y in stride(from: height - 1, through: 0, by: -1) {
            for x in stride(from: 0, to: width, by: 2) where level(x, y) > threshold { return CGFloat(y + 1) / scale }
        }
        return nil
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

/// Drawn for ImageRenderer instead of with a ScrollView or a menu (the self-tests set it). False
/// everywhere else.
private struct FlatDetailsKey: EnvironmentKey { static let defaultValue = false }

/// How much larger the type is: the system's Text Size (up to 1.3). 1 at the default size.
private struct UIScaleKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }

/// Night mode, for secondary text that must stay readable under the red tint (§4.3).
private struct NightTextKey: EnvironmentKey { static let defaultValue = false }

/// The panel's type ramp: the phone's, or iPad's (C3.4 #10).
private struct PanelRampKey: EnvironmentKey { static let defaultValue = Ramp.phone }

/// The scrolling list: tiles are rows (caption leading, value trailing).
private struct PanelRowsKey: EnvironmentKey { static let defaultValue = false }

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
    var panelRamp: Ramp {
        get { self[PanelRampKey.self] }
        set { self[PanelRampKey.self] = newValue }
    }
    var panelRows: Bool {
        get { self[PanelRowsKey.self] }
        set { self[PanelRowsKey.self] = newValue }
    }
}
