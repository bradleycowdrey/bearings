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

/// Bearings' one screen, Concept A "Instrument Panel (Targets + Grid)", Option 1 (docs/REFINE.md "Concept A
/// (chosen)"): one fixed, non-scrolling screen that starts with the dial, 18 under the safe top, then the
/// readout, the status line, the location card (the sky card with the place, the time, the map button
/// where a layout has one, and ⋯), one Targets card (the lock and the marked spot, only those that exist)
/// and the layout's tiles or map: Small a map card with a band, Medium a 2 × 2 with the Map tile, Large a
/// 3 × 2, Extra Large one summary strip. Every frame comes from the planner (`LayoutPlan`), so what is
/// drawn is what was planned (and the self-tests check the drawing against the plan). No value is ever
/// ellipsized (it scales to 0.85, then the layout gives way); at accessibility text sizes the whole screen
/// becomes one scrolling list. Wide windows and phones on their side get two panes: the dial on the left,
/// the location card, Targets, the grid and a map card on the right. The same view on Mac, iPhone and iPad.
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

    /// A Mac window.
    static var isMac: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    /// The system's Text Size, as a multiplier on the cards, the status line and the tiles: 1 at the default.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1

    /// Text Size alone, capped at 1.3 (the planner's `k`).
    private var textK: CGFloat { min(max(textScale, 1), LayoutPlan.maxK) }

    /// A marked spot with a fix: the spot row shows in the Targets card.
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

    /// The lock row's two columns: "Locked 240°" and "turn 12° right", each with no-break spaces inside, so
    /// neither value ever splits.
    static func lockParts(_ text: String) -> (label: String, cue: String) {
        let parts = text.components(separatedBy: " · ")
        let label = (parts.first ?? text).replacingOccurrences(of: " ", with: "\u{00A0}")
        let cue = parts.dropFirst().joined(separator: " · ")
        return (label, keepTogether(cue))
    }

    /// The type ramp for this plan: the list's, iPad's regular-width one, or the phone's.
    static func ramp(_ plan: LayoutPlan) -> Ramp { plan.list ? .list : (plan.tablet ? .tablet : .phone) }

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
        // Night mode covers the whole screen: the cards, the dial, the tiles and the map.
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
    /// shows), S the safe height inside which everything is laid out. With a home indicator the stack ends
    /// at the safe bottom; a Mac window keeps its 28 pt title band clear (less what the safe area already
    /// leaves out).
    private func makePlan(for geo: GeometryProxy) -> LayoutPlan {
        let w = geo.size.width, s = geo.size.height
        let insets = geo.safeAreaInsets
        let h = s + insets.top + insets.bottom
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
                               isLandscapePhone: landscapePhone,
                               homeIndicator: Self.isMac ? false : insets.bottom > 0,
                               topBand: Self.isMac ? max(0, LayoutPlan.macTitleBand - insets.top) : 0,
                               speed: nav.speed, splitPosition: nav.format == .dd)
    }

    // MARK: The three arrangements

    /// One column, C wide, centred: the dial at the plan's top, every block at its planned height and gap.
    private func singleColumn(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            dial(side: plan.dial)
                .padding(.top, plan.dialTop)
            readoutGroup(plan)
                .padding(.top, plan.gapDialReadout)
            lowerStack(plan)
                .padding(.top, plan.gapStatusCard)
            Spacer(minLength: 0)
        }
        .padding(.bottom, plan.bottomInset)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Everything under the status line (one column), or the whole right pane (two panes): the location
    /// card, the Mac's update banner, the Targets card, the grid, the map card, 8 apart.
    private func lowerStack(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            locationCard(plan)
            if let update {
                updateBanner(update)
                    .padding(.top, plan.gap)
            }
            if plan.hasTargets {
                targetsCard(plan)
                    .padding(.top, plan.gap)
            }
            if plan.gridHeight > 0 {
                tileGrid(plan)
                    .padding(.top, plan.gap)
            }
            if plan.map == .card {
                mapCard(plan)
                    .frame(width: plan.columnWidth, height: plan.mapHeight)
                    .padding(.top, plan.gap)
            }
        }
        .frame(width: plan.columnWidth)
    }

    /// Two panes (iPad landscape, wide Mac windows, a phone on its side): no full-width header. The dial,
    /// readout and status line top-aligned on the left; the location card (level with the dial's top), the
    /// Targets card, the grid and a map card to the bottom on the right.
    private func twoPanes(_ plan: LayoutPlan) -> some View {
        HStack(alignment: .top, spacing: LayoutPlan.paneGap) {
            VStack(spacing: 0) {
                dial(side: plan.dial)
                readoutGroup(plan)
                    .padding(.top, plan.gapDialReadout)
            }
            .frame(width: plan.leftWidth)
            trailingPane(plan)
                .frame(width: plan.columnWidth)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, plan.dialTop)
        .padding(.horizontal, plan.margin)
        .padding(.bottom, plan.bottomInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func trailingPane(_ plan: LayoutPlan) -> some View {
        if plan.trailingScrolls && !flatDetails {
            ScrollView {
                lowerStack(plan)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicatorsFlash(onAppear: true)
        } else {
            lowerStack(plan)
        }
    }

    /// Accessibility text sizes, or nothing fits even with every step given up: one scrolling list in
    /// which every block is complete: the dial (0.40 H), the readout, the status line, the location card
    /// (wrapping), the Targets card (the cue on line 2), the tiles as 96 rows (caption leading, value
    /// trailing) and a 176 Map tile. The indicator flashes on appear and a 24 pt fade at the bottom is the
    /// cue that it continues. For ImageRenderer, the same stack, clipped.
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
        VStack(spacing: 0) {
            dial(side: plan.dial)
                .padding(.top, plan.dialTop)
            readoutGroup(plan)
                .padding(.top, plan.gapDialReadout)
            locationCard(plan)
                .padding(.top, plan.gapStatusCard)
            if let update {
                updateBanner(update)
                    .padding(.top, plan.gap)
            }
            if plan.hasTargets {
                targetsCard(plan)
                    .padding(.top, plan.gap)
            }
            listTiles(plan)
                .padding(.top, plan.gap)
            mapTile(plan, height: plan.mapHeight)
                .frame(width: plan.columnWidth, height: plan.mapHeight)
                .padding(.top, LayoutPlan.gapAboveListMap)
        }
        // Room under the last block for the fade.
        .padding(.bottom, plan.bottomInset + LayoutPlan.maxSpare)
        .frame(width: plan.columnWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: The location card

    /// The sky card (formerly the header), under the status line: 48 high (56 on iPad, × k), radius 14 (16
    /// on iPad), on the sky for the sun's altitude here. The full place name over the date and time with the
    /// Sample pill trailing line 2 (line 1 in the list), then the sky glyph in a 32 slot, the map button
    /// (Large and Extra Large, and wherever the map gave way; hidden with its slot kept in two panes, where a
    /// map card is on screen) and ⋯. Nothing in it is ever ellipsized: the date shortens first ("Nov 1"),
    /// then goes; the place scales down rather than lose ", Colorado".
    private func locationCard(_ plan: LayoutPlan) -> some View {
        let k = plan.k
        let ramp = Self.ramp(plan)
        let titleSize: CGFloat = plan.list ? ramp.title : ramp.title * k
        let dateSize: CGFloat = plan.list ? ramp.subtitle : ramp.subtitle * k
        let pillOnPlaceLine = nav.sample && plan.list
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    placeLine(size: titleSize, wraps: plan.list)
                    if pillOnPlaceLine { sampleBadge(plan) }
                }
                HStack(spacing: 6) {
                    dateText(size: dateSize, wraps: plan.list, tablet: plan.tablet)
                    if nav.sample && !pillOnPlaceLine { sampleBadge(plan) }
                }
            }
            // One element: where and when, then the buttons after it.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(locationSpoken)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            skySymbol
            if plan.mapButtonSlot {
                mapButton(plan)
                    .opacity(plan.twoPane ? 0 : 1)
                    .disabled(plan.twoPane)
                    .accessibilityHidden(plan.twoPane)
            }
            menu(plan)
        }
        .foregroundStyle(.white)
        .padding(.leading, plan.tablet ? 16 : 14)
        .padding(.trailing, 4)
        .padding(.vertical, plan.list ? 8 : 0)
        .frame(maxWidth: .infinity)
        .frame(minHeight: plan.cardHeight, maxHeight: plan.list ? nil : plan.cardHeight)
        .skyCard(altitude: nav.sunPosition?.altitude, radius: plan.tablet ? Look.radius : Look.headerRadius)
    }

    /// "Maroon Bells, Colorado", 17 semibold (20 on iPad): the full name always, at 0.85 if it must, then
    /// scaled further rather than cut. In the list it may wrap to two lines.
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

    /// "Sun, Nov 1 · 9:41 AM", then "Nov 1 · 9:41 AM", then "9:41 AM": never an ellipsis in the time. White
    /// at 75% (85% on iPad), tabular.
    @ViewBuilder
    private func dateText(size: CGFloat, wraps: Bool, tablet: Bool) -> some View {
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
        .foregroundStyle(Color.white.opacity(tablet ? Palette.Op.body : 0.75))
        .monospacedDigit()
    }

    /// The card's second line, longest first: "Sun, Nov 1 · 9:41 AM", "Nov 1 · 9:41 AM", "9:41 AM" (the
    /// device's 12- or 24-hour style, through the one time formatter, Look.timeText).
    static func dateLines(_ date: Date) -> (full: String, short: String, time: String) {
        let time = Look.timeText(date)
        let day = date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        let shortDay = date.formatted(.dateTime.month(.abbreviated).day())
        return ("\(day) · \(time)", "\(shortDay) · \(time)", time)
    }

    /// "Maroon Bells, Colorado, Sunday November 1, 9:41 AM, sample data".
    private var locationSpoken: String {
        let day = nav.now.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return "\(nav.placeTitle), \(day), \(Look.timeText(nav.now))\(nav.sample ? ", sample data" : "")"
    }

    /// The sun, sunrise or sunset, or moon symbol (decorative): 22 pt at white 85% in a 32 slot.
    private var skySymbol: some View {
        Image(systemName: SkyTone.symbol(for: nav.sunPosition))
            .font(.system(size: 22, weight: .medium))
            .foregroundStyle(Color.white.opacity(Palette.Op.body))
            .frame(width: 32)
            .accessibilityHidden(true)
    }

    /// The location card's map button (Large and Extra Large): a 24 glyph in a 44 target (48 on iPad).
    private func mapButton(_ plan: LayoutPlan) -> some View {
        let target: CGFloat = plan.tablet ? 48 : 44
        return Button { nav.mapSheet = true } label: {
            Image(systemName: "map")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: target, height: target)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map")
        .accessibilityHint("Opens the map")
    }

    /// The Sample pill: 12 semibold, black on the notice amber, in a 17 capsule (13 in a 19 on iPad). At
    /// night an outline: black fill, a 1.5 white edge, white text.
    private func sampleBadge(_ plan: LayoutPlan) -> some View {
        let k = plan.list ? 1 : plan.k
        let size: CGFloat = plan.list ? 17 : (plan.tablet ? 13 : 12)
        let height: CGFloat = plan.list ? 26 : (plan.tablet ? 19 : 17)
        let night = nav.nightMode
        return Text("Sample")
            .font(.system(size: size * k, weight: .semibold))
            .foregroundStyle(night ? Color.white : Color.black)
            .padding(.horizontal, 7)
            .frame(height: height * k)
            .background {
                if night {
                    Capsule().fill(Color.black).overlay(Capsule().strokeBorder(Color.white, lineWidth: 1.5))
                } else {
                    Capsule().fill(Palette.notice)
                }
            }
            .fixedSize()
    }

    /// The ⋯ menu; for ImageRenderer (`flatDetails`, the self-tests), which can't draw a menu, its symbol alone.
    @ViewBuilder
    private func menu(_ plan: LayoutPlan) -> some View {
        if flatDetails {
            menuSymbol(plan)
                .accessibilityLabel("Settings and more")
        } else {
            settingsMenu(plan)
        }
    }

    /// `ellipsis.circle` 28 in a 44 target (48 on iPad).
    private func menuSymbol(_ plan: LayoutPlan) -> some View {
        let target: CGFloat = plan.tablet ? 48 : 44
        return Image(systemName: "ellipsis.circle")
            .font(.system(size: 28, weight: .regular))
            .foregroundStyle(.white)
            .frame(width: target, height: target)
            .contentShape(Rectangle())
    }

    private func settingsMenu(_ plan: LayoutPlan) -> some View {
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
            menuSymbol(plan)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("Settings and more")
    }

    /// The Mac's update banner: 44 high, in the tile style, between the location card and the Targets card.
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
        UIAccessibility.post(notification: .announcement, argument: Self.noHeadingSpoken)
    }
    #endif

    /// The status line's slot when there is no compass.
    static let noCompassText = "Position, sun and map still work"
    /// What replaces the readout when there is no compass, in words (Concept A): 34 semibold, white 55%.
    static let noHeadingText = "No heading"
    /// How VoiceOver says it.
    static let noHeadingSpoken = "Heading unavailable"

    /// The readout and the status line, 6 × k apart, centred under the dial.
    private func readoutGroup(_ plan: LayoutPlan) -> some View {
        VStack(spacing: 0) {
            readout(plan)
            statusLine(plan)
                .padding(.top, plan.gapReadoutStatus)
        }
    }

    /// How far a line of the system font at `size` reaches above its capitals: trimmed off the readout's
    /// line box, so the 12 under the dial runs to the digits' cap height.
    static func capInset(size: CGFloat, semibold: Bool = false) -> CGFloat {
        let font = PlatformFont.systemFont(ofSize: size, weight: semibold ? .semibold : .light)
        return max(0, font.ascender - font.capHeight)
    }

    /// The width of `text` in the system font with tabular digits, for the self-tests' fit checks.
    fileprivate static func textWidth(_ text: String, size: CGFloat, weight: PlatformFont.Weight) -> CGFloat {
        let font = PlatformFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    /// "228° SW", unchanged in style, in a block trimmed to the digits' cap height. With no compass, "No
    /// heading" in words in the same slot (which is tall enough for either); still waiting for a first
    /// heading, the slot stays empty.
    @ViewBuilder
    private func readout(_ plan: LayoutPlan) -> some View {
        let big = plan.headingSize
        if nav.noCompass {
            NoHeadingReadout()
                .frame(height: plan.readoutSlot, alignment: .top)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.noHeadingSpoken)
        } else if let heading = nav.heading {
            ReadoutGlyphs(heading: heading, size: big, pointColor: secondary)
                // The line box above the capitals is trimmed; the block is cap height plus 4 under the baseline.
                .padding(.top, -Self.capInset(size: big))
                .frame(height: plan.readoutSlot, alignment: .top)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(headingSpoken(heading))
        } else {
            Color.clear
                .frame(height: plan.readoutSlot)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Heading not known yet")
        }
    }

    /// "Heading 228 degrees southwest, locked 240, turn 12 right".
    private func headingSpoken(_ h: Double) -> String {
        var text = "Heading \(Int(h.rounded()) % 360) degrees \(Geo.pointName(h).lowercased())"
        if let lock = nav.lockText {
            text += ", " + lock.lowercased().replacingOccurrences(of: "°", with: "").replacingOccurrences(of: " · ", with: ", ")
        }
        return text
    }

    /// "True north · 8° E declination · ±8° accuracy", 13 regular (iPad too), one line (two only at k > 1.1,
    /// after a dot). Amber warnings take its place; with no compass, "Position, sun and map still work".
    @ViewBuilder
    private func statusLine(_ plan: LayoutPlan) -> some View {
        let lines = Int(plan.statusLines)
        // 13 × k as before Concept A on every device (the list: 17, its accessibility size).
        let size: CGFloat = plan.list ? 17 : 13 * plan.k
        Group {
            if nav.noCompass {
                Text(Self.keepTogether(Self.noCompassText))
                    .foregroundStyle(secondary)
                    .lineLimit(plan.list ? nil : lines)
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
        .font(.system(size: size))
        .monospacedDigit()
        .minimumScaleFactor(0.85)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: plan.list)
        .frame(maxWidth: .infinity)
        .frame(minHeight: plan.statusHeight, maxHeight: plan.list ? nil : plan.statusHeight)
    }

    // MARK: The Targets card

    /// One card for the lock and the marked spot (only the rows that exist; none, no card): radius 16 on the
    /// tile fill with its 1 pt edge. The lock row first, on the maroon tint (#3D2128, a 1 pt #5A2C38 inset
    /// edge), then a hairline, then the spot row. Rows 44 high (Extra Large and iPad 52; 36 under pressure),
    /// text 17 (Small 15, iPad 19), ✕ in a 44 target. Tap a row for its menu; ✕ clears it. Each row is one
    /// VoiceOver element with the ✕ as a named action.
    private func targetsCard(_ plan: LayoutPlan) -> some View {
        let shape = RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
        let locked = nav.lockText != nil
        return VStack(spacing: 0) {
            if let text = nav.lockText {
                lockRow(text, plan: plan)
                    .frame(minHeight: plan.targetsRowHeight, maxHeight: plan.list ? nil : plan.targetsRowHeight)
                    .background { lockFill(only: !hasSpotRow) }
            }
            if hasSpotRow {
                spotRow(plan)
                    .frame(minHeight: plan.targetsRowHeight, maxHeight: plan.list ? nil : plan.targetsRowHeight)
                    .overlay(alignment: .top) {
                        if locked {
                            // The hairline between the rows: white 8%.
                            Rectangle().fill(Color.white.opacity(Palette.Op.tile)).frame(height: 1)
                        }
                    }
            }
        }
        .frame(width: plan.columnWidth)
        .background(shape.fill(Palette.tileFill))
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.tileStroke, lineWidth: Look.stroke).allowsHitTesting(false))
    }

    /// The lock row's maroon: all four corners when it is the only row, else the top two.
    @ViewBuilder
    private func lockFill(only: Bool) -> some View {
        if only {
            RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
                .fill(Palette.lockFill)
                .overlay(RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
                    .strokeBorder(Palette.lockBorder, lineWidth: Look.stroke))
        } else {
            UnevenRoundedRectangle(topLeadingRadius: Look.radius, topTrailingRadius: Look.radius, style: .continuous)
                .fill(Palette.lockFill)
                .overlay(UnevenRoundedRectangle(topLeadingRadius: Look.radius, topTrailingRadius: Look.radius, style: .continuous)
                    .stroke(Palette.lockBorder, lineWidth: Look.stroke)
                    .padding(Look.stroke / 2))
        }
    }

    /// The Targets card's text size: 17 (Small 15, iPad 19), × k.
    private func targetsSize(_ plan: LayoutPlan) -> CGFloat {
        (plan.tablet ? 19 : plan.layout.targetsText) * (plan.list ? 1.3 : plan.k)
    }

    /// The glyph column of a Targets row: 14 × 16 at white 85% in a 16 slot.
    private func targetsGlyph(_ system: String, plan: LayoutPlan) -> some View {
        Image(systemName: system)
            .font(.system(size: 14 * plan.k, weight: .semibold))
            .foregroundStyle(Color.white.opacity(Palette.Op.body))
            .frame(width: 16 * plan.k)
            .accessibilityHidden(true)
    }

    /// "Locked 240°" leading at regular weight, "turn 12° right" trailing at semibold, the ✕. Below a 320
    /// column the label shortens to "240°".
    private func lockRow(_ text: String, plan: LayoutPlan) -> some View {
        let parts = Self.lockParts(text)
        let label = plan.columnWidth < 320 ? parts.label.replacingOccurrences(of: "Locked\u{00A0}", with: "") : parts.label
        let spokenText = text.replacingOccurrences(of: "°", with: " degrees").replacingOccurrences(of: " · ", with: ", ")
        return HStack(spacing: plan.tablet ? 10 : 8) {
            targetsGlyph("lock.fill", plan: plan)
            TwoColumnText(label: label, value: parts.cue, size: targetsSize(plan), wraps: plan.list)
                .frame(maxWidth: .infinity, alignment: .leading)
            closeButton(plan) { nav.toggleLock() }
        }
        .foregroundStyle(.white)
        .padding(.leading, plan.tablet ? 16 : 14)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenText)
        .accessibilityAction(named: "Clear lock") { nav.toggleLock() }
    }

    /// "Marked spot" leading, "9.2 mi · 46° NE" trailing at semibold, the ✕. The row opens a small menu
    /// (Lock to Spot, Clear).
    private func spotRow(_ plan: LayoutPlan) -> some View {
        HStack(spacing: plan.tablet ? 10 : 8) {
            targetsGlyph("mappin", plan: plan)
            spotLabel(plan)
            closeButton(plan) { nav.clearSpot() }
        }
        .padding(.leading, plan.tablet ? 16 : 14)
        .padding(.trailing, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marked spot, \(spotSpoken)")
        .accessibilityAction(named: "Clear marked spot") { nav.clearSpot() }
        .accessibilityAction(named: "Lock to spot") { nav.lockToSpot() }
    }

    /// The ✕ of a Targets row: a 14 glyph at white 60% (90% at night) in a 44 target.
    private func closeButton(_ plan: LayoutPlan, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 14 * plan.k, weight: .semibold))
                .foregroundStyle(Color.white.opacity(nav.nightMode ? Palette.nightSecondary : Palette.Op.caption))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        let label = TwoColumnText(label: "Marked\u{00A0}spot", value: Self.keepTogether(nav.spotText ?? ""),
                                  size: targetsSize(plan), wraps: plan.list)
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
        }
    }

    // MARK: The tile grid

    /// The grid exactly as the plan's `cells` and `rowHeights` give it, rows and tiles 8 apart. Every row's
    /// widths and gutters add up to C.
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
        VStack(spacing: plan.gap) {
            ForEach(Array(plan.cells.enumerated()), id: \.offset) { index, row in
                HStack(spacing: LayoutPlan.rowGap) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        tileView(cell.tile, plan: plan, height: rowHeight(plan, index), stale: stale)
                            .frame(width: cell.width, height: rowHeight(plan, index))
                    }
                }
            }
        }
    }

    private func rowHeight(_ plan: LayoutPlan, _ index: Int) -> CGFloat {
        index < plan.rowHeights.count ? plan.rowHeights[index] : plan.tileHeight
    }

    /// The value sizes for this plan's grid: Medium's quad Position 15 and Elevation 17, Large's six 16,
    /// the compact arrangements 15, iPad 22, the list 22.
    private func sizes(_ plan: LayoutPlan) -> (value: CGFloat, position: CGFloat, sun: CGFloat) {
        let ramp = Self.ramp(plan)
        if plan.list || plan.tablet { return (ramp.value, ramp.value, ramp.value) }
        switch plan.grid {
        case .quad: return (Look.tileValueSize, Look.compactValueSize, Look.compactValueSize)
        case .six: return (Self.sixValue, Self.sixValue, Self.sixValue)
        default: return (Look.compactValueSize, Look.compactValueSize, Look.compactValueSize)
        }
    }

    /// Large's compact tiles: values 16 medium.
    static let sixValue: CGFloat = 16

    /// The moon rides in the Sun tile's caption ("SUN · ◐ 53%") where there is no Moon tile, except at
    /// large text (the caption is then "SUN" only).
    private func moonInSunCaption(_ plan: LayoutPlan) -> Bool {
        !plan.list && !plan.largeText && !plan.cells.joined().contains { $0.tile == .moon }
    }

    @ViewBuilder
    private func tileView(_ tile: LayoutPlan.Tile, plan: LayoutPlan, height: CGFloat, stale: Bool) -> some View {
        switch tile {
        case .position: positionTile(plan, stale: stale)
        case .elevation: elevationTile(plan, stale: stale)
        case .sun: sunTile(plan, tall: !plan.tablet && plan.grid == .quad && height >= LayoutPlan.tallSun * plan.k)
        case .moon: moonTile(plan)
        case .map: mapTile(plan, height: height)
        case .latitude: coordinateTile(plan, stale: stale, latitude: true)
        case .longitude: coordinateTile(plan, stale: stale, latitude: false)
        case .sunrise: sunriseTile(plan)
        case .sixth: sixthTile(plan)
        case .strip: summaryStrip(plan, stale: stale)
        }
    }

    /// Accessibility sizes: every tile a full-width row of 96 or more, caption leading, value trailing,
    /// values wrapping.
    @ViewBuilder
    private func listTiles(_ plan: LayoutPlan) -> some View {
        if nav.fix == nil && nav.access != .allowed {
            askForLocation
                .frame(width: plan.columnWidth)
        } else {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                let stale = !nav.sample && (nav.fix.map { context.date.timeIntervalSince($0.time) > 120 } ?? false)
                VStack(spacing: plan.gap) {
                    ForEach(Array(plan.cells.joined().enumerated()), id: \.offset) { _, cell in
                        tileView(cell.tile, plan: plan, height: LayoutPlan.listRow, stale: stale)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(width: cell.width)
                    }
                }
            }
        }
    }

    /// "Finding position…" under a "—", before the first fix (never blank).
    private var waitingText: String { nav.access == .allowed || nav.locating ? "Finding position…" : "Not known yet" }

    /// A tile's value: medium weight, tabular, white (dimmed when the fix is stale). Scales to 0.85, then
    /// wraps; never ellipsized.
    private func valueText(_ text: String, plan: LayoutPlan, stale: Bool = false, size: CGFloat) -> some View {
        FitText(text: text, size: size * plan.k, weight: Self.ramp(plan).valueWeight, wraps: plan.list)
            .monospacedDigit()
            .foregroundStyle(stale ? secondary : .white)
    }

    /// The position as the chosen format gives it: two lines, or one grid reference; and how it is spoken.
    private func positionLines() -> (lines: [String], spoken: String) {
        switch nav.fix.map({ Geo.format(nav.format, lat: $0.latitude, lon: $0.longitude) }) {
        case let .some(.pair(lat, lon)):
            return ([lat, lon], "\(Self.spokenCoordinate(lat)), \(Self.spokenCoordinate(lon))")
        case let .some(.single(value)):
            return ([value], value)
        case .none:
            return (["—"], waitingText.lowercased())
        }
    }

    /// "decimal degrees", but "UTM" and "MGRS" stay in capitals so they're spelled out.
    private var formatWords: String {
        let name = nav.format.name
        return name == name.uppercased() ? name : name.lowercased()
    }

    /// POSITION · DD: latitude over longitude at one shared size (15 on the phone, 22 on iPad), or one grid
    /// reference. Tap for the next format; long-press (right-click on a Mac) for Copy and Details….
    private func positionTile(_ plan: LayoutPlan, stale: Bool) -> some View {
        let position = positionLines()
        let single = position.lines.count == 1 && nav.fix != nil
        let size = single && (plan.tablet || plan.list) ? Self.ramp(plan).singleValue : sizes(plan).position
        return CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
            PanelTile("Position · \(Self.shortName(nav.format))", secondary: nav.fix == nil ? waitingText : nil,
                      insetH: tileInset(plan)) {
                PositionValue(lines: position.lines, size: size * plan.k, weight: Self.ramp(plan).valueWeight, wraps: plan.list)
                    .foregroundStyle(stale ? secondary : .white)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Position, \(position.spoken), \(formatWords)")
        }
    }

    /// Large's tiles sit 10 in from each side; the others use the ramp's inset.
    private func tileInset(_ plan: LayoutPlan) -> CGFloat? { plan.grid == .six && !plan.tablet ? 10 : nil }

    /// LATITUDE / LONGITUDE (Large, decimal degrees): "39.09898°" over "North". Tap for the next format.
    private func coordinateTile(_ plan: LayoutPlan, stale: Bool, latitude: Bool) -> some View {
        let lines = positionLines().lines
        let line = latitude ? (lines.first ?? "—") : (lines.count > 1 ? lines[1] : "—")
        let parts = line.split(separator: " ").map(String.init)
        let hemispheres = ["N": "North", "S": "South", "E": "East", "W": "West"]
        let word = parts.last.flatMap { hemispheres[$0] }
        let number = word == nil ? line : parts.dropLast().joined(separator: " ")
        let caption = latitude ? "Latitude" : "Longitude"
        return CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
            PanelTile(caption, secondary: word ?? (nav.fix == nil ? waitingText : nil), insetH: tileInset(plan)) {
                valueText(number, plan: plan, stale: stale, size: sizes(plan).value)
                    .tracking(-0.2)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(caption), \(Self.spokenCoordinate(line))")
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

    /// The elevation's two units, the chosen one first, and how it is spoken; nil while waiting.
    private func elevationValues() -> (main: String, second: String, spoken: String) {
        switch nav.elevation {
        case let .value(metres, fromGPS, _):
            let e = Geo.elevation(metres)
            let feetWords = "\(Geo.group(metres / Geo.foot)) feet", metreWords = "\(Geo.group(metres)) metres"
            let pressure = nav.pressure.map { ", pressure \(Self.spoken(Geo.pressureText($0, feet: nav.feet)))" } ?? ""
            return (nav.feet ? e.ft : e.m, nav.feet ? e.m : e.ft,
                    "Elevation, \(nav.feet ? feetWords : metreWords), \(nav.feet ? metreWords : feetWords), from \(fromGPS ? "GPS" : "terrain data")\(pressure)")
        case let .pending(text):
            let waiting = text.trimmingCharacters(in: .whitespaces)
            let second = nav.fix == nil || waiting.isEmpty ? waitingText : waiting
            return ("—", second, "Elevation, \(second.lowercased())")
        }
    }

    /// ELEVATION: "9,587 ft" over "2,922 m · 21.04 inHg" (Medium and iPad add the pressure; Large keeps it for
    /// its own tile). Tap: the Details sheet.
    private func elevationTile(_ plan: LayoutPlan, stale: Bool) -> some View {
        let values = elevationValues()
        let withPressure = (plan.grid == .quad || plan.list) && nav.pressure != nil && values.main != "—"
        let second = withPressure ? "\(values.second) · \(Geo.pressureText(nav.pressure ?? 0, feet: nav.feet))" : values.second
        return PanelTile("Elevation", secondary: Self.keepTogether(second), insetH: tileInset(plan)) {
            valueText(values.main, plan: plan, stale: stale, size: sizes(plan).value)
        }
        .panelAction(values.spoken, hint: "Shows the details") { showDetails = true }
    }

    /// SUN: "↑ 6:36 AM" over "↓ 5:08 PM" (one formatter, Look.time), or "Up all day" / "Down all day"; the
    /// moon in its caption ("SUN · ◐ 53%") where there is no Moon tile. Medium's tall live tile (150 or more)
    /// adds "10 h 32 m of daylight", a hairline and a MOON section. Tap: the Details sheet.
    private func sunTile(_ plan: LayoutPlan, tall: Bool) -> some View {
        let k = plan.k
        let times = nav.sunTimes
        let rise = times?.sunriseDate, down = times?.sunsetDate
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        let moonCaption = moonInSunCaption(plan) && !tall
        var spokenSun: String
        if let rise, let down {
            spokenSun = "rises \(Look.timeText(rise)), sets \(Look.timeText(down))"
        } else if let times {
            spokenSun = times.polar == .day ? "up all day" : "down all day"
        } else {
            spokenSun = waitingText.lowercased()
        }
        if moonCaption || tall { spokenSun += ". Moon \(percent) percent lit, \(Look.phaseName(phase).lowercased())" }
        let base = sizes(plan).sun
        let weight = Self.ramp(plan).valueWeight
        let daylight: String? = {
            guard tall, let rise, let down else { return nil }
            let minutes = Int(down.timeIntervalSince(rise) / 60)
            return "\(minutes / 60)\u{00A0}h \(minutes % 60)\u{00A0}m of daylight"
        }()
        return PanelTile("Sun", moon: moonCaption ? phase : nil, secondary: times == nil ? waitingText : daylight,
                         insetH: tileInset(plan), topAligned: tall) {
            if let rise, let down {
                VStack(alignment: .leading, spacing: -2) {
                    SunTime(arrow: "↑", time: Look.time(rise), size: base * k, weight: weight, k: k, wraps: plan.list)
                    SunTime(arrow: "↓", time: Look.time(down), size: base * k, weight: weight, k: k, wraps: plan.list)
                }
                .monospacedDigit()
            } else if let times {
                valueText(times.polar == .day ? "Up all day" : "Down all day", plan: plan, size: base)
            } else {
                valueText("—", plan: plan, size: base)
            }
        } extra: {
            if tall {
                VStack(alignment: .leading, spacing: 4) {
                    Rectangle().fill(Palette.tileStroke).frame(height: 1)
                        .padding(.vertical, 6)
                    Text("MOON")
                        .font(.system(size: Look.tileCaptionSize * k, weight: .semibold))
                        .tracking(Look.tileCaptionTracking)
                        .foregroundStyle(secondary)
                    HStack(spacing: 6) {
                        MoonGlyph(phase: phase.phase, size: 13 * k)
                        valueText("\(percent)%", plan: plan, size: base)
                    }
                    FitText(text: Look.phaseName(phase), size: Look.tileSecondarySize * k)
                        .foregroundStyle(secondary)
                }
            }
        }
        .panelAction("Sun, \(spokenSun)", hint: "Shows the details") { showDetails = true }
    }

    /// SUNRISE (Large): "↑ 6:36 AM" with the day period at 12 and 70%, over "Sets 5:08 PM". Tap: Details.
    private func sunriseTile(_ plan: LayoutPlan) -> some View {
        let k = plan.k
        let times = nav.sunTimes
        let rise = times?.sunriseDate, down = times?.sunsetDate
        let size = sizes(plan).value
        let second: String?
        if let down {
            second = Self.keepTogether("Sets \(Look.timeText(down))")
        } else if let times {
            second = times.polar == .day ? "Up all day" : "Down all day"
        } else {
            second = waitingText
        }
        var spokenText = rise.map { "Sunrise \(Look.timeText($0))" } ?? "Sunrise, none today"
        if let down { spokenText += ", sets " + Look.timeText(down) }
        return PanelTile("Sunrise", secondary: second, insetH: tileInset(plan)) {
            if let rise {
                let t = Look.time(rise)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("↑\u{00A0}\(t.clock)")
                        .font(.system(size: size * k, weight: Self.ramp(plan).valueWeight))
                    if let period = t.period {
                        Text(period)
                            .font(.system(size: 12 * k, weight: .medium))
                            .foregroundStyle(Color.white.opacity(Palette.Op.sub))
                    }
                }
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            } else {
                valueText("—", plan: plan, size: size)
            }
        }
        .panelAction(spokenText, hint: "Shows the details") { showDetails = true }
    }

    /// MOON: the phase's glyph and "53%", over "Last quarter". Tap: the Details sheet.
    private func moonTile(_ plan: LayoutPlan) -> some View {
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        let size = sizes(plan).value
        return PanelTile("Moon", secondary: Look.phaseName(phase), insetH: tileInset(plan)) {
            HStack(spacing: 6) {
                MoonGlyph(phase: phase.phase, size: (size - 2) * plan.k)
                valueText("\(percent)%", plan: plan, size: size)
            }
        }
        .panelAction("Moon, \(percent) percent lit, \(Look.phaseName(phase).lowercased())", hint: "Shows the details") { showDetails = true }
    }

    /// Large's sixth tile: SPEED while moving (0.5 m/s or more), otherwise PRESSURE; never other data. With
    /// no barometer and no motion, PRESSURE "—".
    private func sixthTile(_ plan: LayoutPlan) -> some View {
        let size = sizes(plan).value
        let moving = LayoutPlan.sixth(speed: nav.speed) == .speed
        let main: String?, second: String?, caption: String
        if moving, let speed = nav.speed {
            caption = "Speed"
            main = Geo.speedText(speed, feet: nav.feet)
            second = Geo.speedText(speed, feet: !nav.feet)
        } else {
            caption = "Pressure"
            main = nav.pressure.map { Geo.pressureText($0, feet: nav.feet) }
            second = nav.pressure.map { Geo.pressureText($0, feet: !nav.feet) }
        }
        // "21.04" at the value size, "inHg" at 12 and 70%.
        let parts = (main ?? "—").split(separator: " ", maxSplits: 1).map(String.init)
        let spokenValue: String = main.map { Self.spoken($0) } ?? "not known"
        return PanelTile(caption, secondary: second.map(Self.keepTogether), insetH: tileInset(plan)) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(parts.first ?? "—")
                    .font(.system(size: size * plan.k, weight: Self.ramp(plan).valueWeight))
                if parts.count > 1 {
                    Text(parts[1])
                        .font(.system(size: 12 * plan.k, weight: .medium))
                        .foregroundStyle(Color.white.opacity(Palette.Op.sub))
                }
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(Look.minScale)
        }
        .panelAction("\(caption), \(spokenValue)", hint: "Shows the details") { showDetails = true }
    }

    /// Extra Large's one summary strip: POSITION | ELEVATION | SUN in columns 1.2 | 1 | 1 split by 1 pt
    /// dividers, each 12 across and 14 down. Position taps for the next format; the others open Details.
    private func summaryStrip(_ plan: LayoutPlan, stale: Bool) -> some View {
        let widths = plan.stripWidths
        let k = plan.k
        let position = positionLines()
        let values = elevationValues()
        let times = nav.sunTimes
        let size = sizes(plan).value
        let weight = Self.ramp(plan).valueWeight
        return HStack(spacing: 0) {
            CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
                stripColumn("Position", plan: plan) {
                    PositionValue(lines: position.lines, size: size * k, weight: weight)
                        .foregroundStyle(stale ? secondary : .white)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Position, \(position.spoken), \(formatWords)")
            }
            .frame(width: widths[0])
            stripDivider
            stripColumn("Elevation", plan: plan) {
                VStack(alignment: .leading, spacing: 0) {
                    valueText(values.main, plan: plan, stale: stale, size: size)
                    FitText(text: values.second, size: Look.tileSecondarySize * k)
                        .foregroundStyle(secondary)
                }
            }
            .panelAction(values.spoken, hint: "Shows the details") { showDetails = true }
            .frame(width: widths[1])
            stripDivider
            stripColumn("Sun", plan: plan) {
                if let rise = times?.sunriseDate, let down = times?.sunsetDate {
                    VStack(alignment: .leading, spacing: -2) {
                        SunTime(arrow: "↑", time: Look.time(rise), size: size * k, weight: weight, k: k)
                        SunTime(arrow: "↓", time: Look.time(down), size: size * k, weight: weight, k: k)
                    }
                    .monospacedDigit()
                } else {
                    valueText(times.map { $0.polar == .day ? "Up all day" : "Down all day" } ?? "—", plan: plan, size: size)
                }
            }
            .panelAction(sunSpoken, hint: "Shows the details") { showDetails = true }
            .frame(width: widths[2])
        }
        .frostedTile()
    }

    private var stripDivider: some View {
        Rectangle().fill(Palette.tileStroke).frame(width: LayoutPlan.divider)
            .padding(.vertical, 12)
            .accessibilityHidden(true)
    }

    /// One column of the strip: the caption at the top, the values at the bottom.
    private func stripColumn<V: View>(_ caption: String, plan: LayoutPlan, @ViewBuilder value: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption.uppercased())
                .font(.system(size: Self.ramp(plan).caption * plan.k, weight: .semibold))
                .tracking(Look.tileCaptionTracking)
                .foregroundStyle(secondary)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 2)
            value()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// "Sun, rises 6:36 AM, sets 5:08 PM".
    private var sunSpoken: String {
        if let rise = nav.sunTimes?.sunriseDate, let down = nav.sunTimes?.sunsetDate {
            return "Sun, rises \(Look.timeText(rise)), sets \(Look.timeText(down))"
        }
        if let times = nav.sunTimes { return times.polar == .day ? "Sun, up all day" : "Sun, down all day" }
        return "Sun, \(waitingText.lowercased())"
    }

    /// Small's band along the map card's bottom: 68 × k on near-black at 78% with a 1 pt top edge; three
    /// columns 1.15 | 1 | 1, 8 apart, 12 across and 10 down: POSITION · DD | ELEVATION | SUN · ◐ 53%, each
    /// two lines of 13 semibold.
    private func band(_ plan: LayoutPlan) -> some View {
        let widths = plan.bandWidths
        let k = plan.k
        let position = positionLines()
        let values = elevationValues()
        let times = nav.sunTimes
        let phase = nav.moonPhase
        let percent = Int(Geo.jsRound(phase.fraction * 100))
        return HStack(alignment: .top, spacing: LayoutPlan.rowGap) {
            CoordinateText(copy: copyCoordinates, details: { showDetails = true }) {
                bandColumn("Position · \(Self.shortName(nav.format))", lines: position.lines, k: k)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Position, \(position.spoken), \(formatWords)")
            }
            .frame(width: widths[0], alignment: .leading)
            bandColumn("Elevation", lines: [values.main, values.second], k: k)
                .panelAction(values.spoken, hint: "Shows the details") { showDetails = true }
                .frame(width: widths[1], alignment: .leading)
            bandColumn("Sun · ◐\u{00A0}\(percent)%", lines: sunLines(times), k: k)
                .panelAction("\(sunSpoken). Moon \(percent) percent lit", hint: "Shows the details") { showDetails = true }
                .frame(width: widths[2], alignment: .leading)
        }
        .padding(.horizontal, LayoutPlan.bandPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(red: 12 / 255, green: 14 / 255, blue: 14 / 255).opacity(0.78))
        .overlay(alignment: .top) { Rectangle().fill(Palette.tileStroke).frame(height: Look.stroke) }
    }

    /// "↑ 6:36 AM" and "↓ 5:08 PM" (no-break spaces), or the polar day or night.
    private func sunLines(_ times: Sky.Times?) -> [String] {
        if let rise = times?.sunriseDate, let down = times?.sunsetDate {
            return ["↑\u{00A0}\(Look.timeText(rise))", "↓\u{00A0}\(Look.timeText(down))"]
        }
        if let times { return [times.polar == .day ? "Up all day" : "Down all day"] }
        return ["—"]
    }

    private func bandColumn(_ caption: String, lines: [String], k: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(caption.uppercased())
                .font(.system(size: Look.tileCaptionSize * k, weight: .semibold))
                .tracking(Look.tileCaptionTracking)
                .foregroundStyle(secondary)
                .lineLimit(1)
                .minimumScaleFactor(Look.minScale)
                .padding(.bottom, 3)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                FitText(text: line, size: 13 * k, weight: .semibold)
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }

    /// MAP: a still map picture north up with your dot and heading cone, no controls or gestures, on a
    /// 24 pt bottom scrim with the expand glyph, "MAP" and the Maps attribution. One element for VoiceOver.
    /// A tall tile (Medium live) also shows the speed while moving. Tap: the map sheet.
    private func mapTile(_ plan: LayoutPlan, height: CGFloat) -> some View {
        MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: .constant(false), satellite: nav.satellite,
                   dimmed: nav.nightMode, thumbnail: true)
            .allowsHitTesting(false)
            .overlay(alignment: .topLeading) {
                if height >= LayoutPlan.tallSun * plan.k, let speed = movingSpeedText {
                    speedChip(speed, k: plan.k)
                        .padding(8)
                }
            }
            // The picture takes no touches; this clear layer takes the tap for the whole tile.
            .overlay { Color.clear.contentShape(Rectangle()) }
            .panelAction("Map, opens full map", hint: "Opens the map") { nav.mapSheet = true }
    }

    /// "3.2 mph" while moving (0.5 m/s or more), else nil.
    private var movingSpeedText: String? {
        guard LayoutPlan.sixth(speed: nav.speed) == .speed, let speed = nav.speed else { return nil }
        return Geo.speedText(speed, feet: nav.feet)
    }

    /// The speed chip: 13 semibold tabular on black at 72%, 10 × 5, radius 14.
    private func speedChip(_ text: String, k: CGFloat) -> some View {
        Text(text.replacingOccurrences(of: " ", with: "\u{00A0}"))
            .font(.system(size: 13 * k, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.72)))
            .accessibilityLabel("Speed, \(text)")
    }

    /// The map card (Small, iPad, two panes), with its controls and the speed chip while moving. Small's card
    /// carries the band along its bottom, under the map so the map's own logo and Legal link stay clear.
    @ViewBuilder
    private func mapCard(_ plan: LayoutPlan) -> some View {
        if plan.grid == .band {
            let bandHeight = LayoutPlan.band * plan.k
            let shape = RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
            VStack(spacing: 0) {
                MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                           speed: movingSpeedText, dimmed: nav.nightMode, bleed: true)
                    .frame(height: max(0, plan.mapHeight - bandHeight))
                band(plan)
                    .frame(height: bandHeight)
            }
            .background(Palette.tileFill)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.tileStroke, lineWidth: Look.stroke).allowsHitTesting(false))
        } else {
            MapSnippet(fix: nav.fix, heading: nav.heading, followHeading: $nav.followHeading, satellite: nav.satellite,
                       speed: movingSpeedText, dimmed: nav.nightMode)
        }
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

/// One tile, the same component everywhere (Concept A's tile, the widgets' pattern): a text-only caps
/// caption (11 semibold, tracking 0.6, white 60%; with the moon's glyph and percentage after it for the
/// compact Sun) pinned to the top inset, and the value block (value and second line) pinned to the bottom
/// inset, so a grown tile is never half empty at the bottom. A tall tile (`topAligned`) keeps its value under
/// the caption and adds its `extra` below. Leading-aligned on the tile fill (radius 16) with its 1 pt edge.
/// Sizes from the type ramp (iPad's own). In the scrolling list it is a row: caption leading, value
/// trailing, 96 or more high. The caller sets its frame.
struct PanelTile<Value: View, Extra: View>: View {
    let caption: String
    var moon: Sky.Phase?
    var secondary: String?
    /// The horizontal inset (nil: the ramp's).
    var insetH: CGFloat?
    var topAligned = false
    let value: Value
    let extra: Extra
    @Environment(\.uiScale) private var k
    @Environment(\.nightText) private var night
    @Environment(\.panelRamp) private var ramp
    @Environment(\.panelRows) private var rows

    init(_ caption: String, moon: Sky.Phase? = nil, secondary: String? = nil, insetH: CGFloat? = nil,
         topAligned: Bool = false, @ViewBuilder value: () -> Value, @ViewBuilder extra: () -> Extra) {
        self.caption = caption
        self.moon = moon
        self.secondary = secondary
        self.insetH = insetH
        self.topAligned = topAligned
        self.value = value()
        self.extra = extra()
    }

    var body: some View {
        if rows {
            HStack(alignment: .center, spacing: 12) {
                captionRow
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 0) {
                    value
                    if let secondary {
                        FitText(text: secondary, size: ramp.secondary, wraps: true)
                            .foregroundStyle(Palette.secondary(night: night))
                    }
                }
                .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, ramp.insetH)
            .padding(.vertical, ramp.insetV)
            .frame(maxWidth: .infinity, minHeight: LayoutPlan.listRow, alignment: .leading)
            .frostedTile()
        } else {
            VStack(alignment: .leading, spacing: 0) {
                captionRow
                if topAligned {
                    valueBlock
                        .padding(.top, 6)
                    extra
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 2)
                    valueBlock
                }
            }
            .padding(.horizontal, insetH ?? ramp.insetH)
            .padding(.vertical, ramp.insetV)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .frostedTile()
        }
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            value
            if let secondary {
                FitText(text: secondary, size: ramp.secondary * k)
                    .foregroundStyle(Palette.secondary(night: night))
            }
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
        let size = rows ? ramp.caption : ramp.caption * k
        return HStack(spacing: 3) {
            Text(caption.uppercased())
                .tracking(Look.tileCaptionTracking)
            if let moon {
                Text("·")
                MoonGlyph(phase: moon.phase, size: size)
                Text("\(Int(Geo.jsRound(moon.fraction * 100)))%")
                    .monospacedDigit()
            }
        }
        .font(.system(size: size, weight: .semibold))
        .lineLimit(1)
        .fixedSize()
    }
}

extension PanelTile where Extra == EmptyView {
    init(_ caption: String, moon: Sky.Phase? = nil, secondary: String? = nil, insetH: CGFloat? = nil,
         topAligned: Bool = false, @ViewBuilder value: () -> Value) {
        self.init(caption, moon: moon, secondary: secondary, insetH: insetH, topAligned: topAligned,
                  value: value, extra: { EmptyView() })
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

/// The readout's glyphs, unchanged by Concept A: "228°" light with the point ("SW") at half size.
struct ReadoutGlyphs: View {
    var heading: Double
    var size: CGFloat
    var pointColor: Color = Color.white.opacity(Palette.Op.caption)

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(Int(heading.rounded()) % 360)°")
                .font(.system(size: size, weight: .light))
                .foregroundStyle(.white)
                .tracking(-2)
            Text(Geo.point(heading))
                .font(.system(size: size / 2, weight: .medium))
                .foregroundStyle(pointColor)
                .frame(minWidth: size, alignment: .leading)
        }
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize()
    }
}

/// "No heading" in words where the readout goes when there is no compass (Concept A, replacing the drawn
/// dash): 34 semibold, tracking −0.2, white at 55%, centred, its line box trimmed so the 12 under the dial
/// runs to the capitals' top.
struct NoHeadingReadout: View {
    var body: some View {
        Text(MainView.noHeadingText)
            .font(.system(size: LayoutPlan.noHeadingSize, weight: .semibold))
            .tracking(-0.2)
            .foregroundStyle(Color.white.opacity(Palette.Op.noHeading))
            .lineLimit(1)
            .fixedSize()
            .padding(.top, -MainView.capInset(size: LayoutPlan.noHeadingSize, semibold: true))
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

// MARK: Checks for the self-tests: what must fit (no "…" anywhere), and what is drawn

extension MainView {
    /// Measures what the tiles, the band, the strip and the location card must hold, in the system font, on
    /// every Apple device of the planner's table at Text Size 1.0 and 1.3, and checks that the strings they
    /// show never carry "…" (and that the lock row's values can't split). Each failure is one line; empty
    /// when all is well.
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
        // The lock row: "Locked 240°" and "turn 12° right" never split inside a value.
        let lock = lockParts("Locked 240° · turn 12° right")
        if lock.label.contains(" ") || lock.cue.contains(" ") || lock.label != "Locked\u{00A0}240°" {
            failures.append("The lock row's values can split: \"\(lock.label)\" / \"\(lock.cue)\"")
        }
        // Times never break: a narrow no-break space before the day period.
        for t in [Look.timeText(sunrise), Look.timeText(sunset)] where t.contains(" ") {
            failures.append("\"\(t)\" can break")
        }

        let dd = Geo.format(.dd, lat: lat, lon: lon)
        let longitude: String = { if case let .pair(_, b) = dd { return b }; return "106.94117° W" }()
        let pill = textWidth("Sample", size: 12, weight: .semibold) + 14 + 6
        // Apple's devices only (an Android font is not this one).
        for d in LayoutPlan.devices where !d.name.hasPrefix("Android") && !d.name.hasPrefix("Pixel") {
            for k in [CGFloat(1), 1.3] {
                for layout in Layout.allCases {
                    let p = LayoutPlan.plan(w: d.w, h: d.h, s: d.s, layout: layout, k: k, hasSpot: true, locked: true, mac: d.mac)
                    let name = "\(d.name) \(layout.rawValue) k\(k)"
                    let ramp = Self.ramp(p)
                    if !p.list {
                        // The location card: the sky glyph (32), the map button's slot (44) and ⋯ (44) trail; line 2
                        // holds at least the time and the Sample pill, and line 1 the full place at 0.85.
                        let mapSlot: CGFloat = p.mapButtonSlot ? 44 : 0
                        let trailing: CGFloat = mapSlot + 84
                        let room = p.columnWidth - (p.tablet ? 16 : 14) - trailing
                        if textWidth(dates.time, size: ramp.subtitle * k, weight: .regular) + pill * k > room + 0.5 {
                            failures.append("\(name): the location card's time and Sample don't fit (\(Int(room)) pt)")
                        }
                        if k == 1 && textWidth(place, size: ramp.title * Look.minScale, weight: .semibold) > room + 0.5 {
                            failures.append("\(name): \"\(place)\" doesn't fit at 0.85 (\(Int(room)) pt)")
                        }
                    }
                    // The Targets card: "Locked 240°" and "turn 12° right" side by side.
                    if !p.list {
                        let size = (p.tablet ? 19 : layout.targetsText) * k * Look.minScale
                        let labelWidth: CGFloat = textWidth("Locked 240°", size: size, weight: .regular)
                        let cueWidth: CGFloat = textWidth("turn 12° right", size: size, weight: .semibold)
                        // 14 leading, the glyph (16 × k), 8, 12 between the columns, 8, the 44 ✕, 4 trailing.
                        let chrome: CGFloat = 90 + 16 * k
                        let need: CGFloat = chrome + labelWidth + cueWidth
                        if need > p.columnWidth + 0.5 && p.columnWidth >= 320 {
                            failures.append("\(name): the lock row needs \(Int(need)) of \(Int(p.columnWidth)) pt")
                        }
                    }
                    for cell in p.cells.joined() {
                        let inset: CGFloat = p.grid == .six && !p.tablet ? 10 : ramp.insetH
                        let room = cell.width - 2 * inset
                        switch cell.tile {
                        case .sun:
                            // Some step of the Sun ladder fits (at the latest, the time over its "AM").
                            let base: CGFloat = p.tablet || p.list ? ramp.value : Look.compactValueSize
                            let size = base * k * Look.minScale
                            for t in times {
                                let clock = textWidth("↑\u{00A0}\(t.clock)", size: size, weight: .medium)
                                let period = t.period.map { textWidth($0, size: Look.periodSize * k, weight: .medium) } ?? 0
                                if max(clock, period) > room + 0.5 {
                                    failures.append("\(name): Sun \(t.clock) needs \(Int(max(clock, period))) of \(Int(room)) pt")
                                }
                            }
                        case .sunrise:
                            if let t = times.first {
                                let width = textWidth("↑\u{00A0}\(t.clock)", size: sixValue * k * Look.minScale, weight: .medium)
                                    + (t.period.map { textWidth($0, size: 12 * k, weight: .medium) + 2 } ?? 0)
                                if width > room + 0.5 { failures.append("\(name): Sunrise needs \(Int(width)) of \(Int(room)) pt") }
                            }
                        case .position where k == 1 && !p.list:
                            // Decimal degrees (the default): the longitude fits on one line at 0.85.
                            let size: CGFloat = (p.tablet ? ramp.value : Look.compactValueSize) * Look.minScale
                            let width = textWidth(longitude, size: size, weight: .medium)
                            if width > room + 0.5 { failures.append("\(name): \(longitude) needs \(Int(width)) of \(Int(room)) pt") }
                        case .longitude where k == 1:
                            let number = longitude.split(separator: " ").first.map(String.init) ?? longitude
                            let width = textWidth(number, size: sixValue * Look.minScale, weight: .medium)
                            if width > room + 0.5 { failures.append("\(name): Longitude \(number) needs \(Int(width)) of \(Int(room)) pt") }
                        default:
                            break
                        }
                    }
                    // Small's band and Extra Large's strip: the longitude and the times in their columns.
                    if p.grid == .band && k == 1 {
                        let w = p.bandWidths
                        let lonWidth = textWidth(longitude, size: 13 * Look.minScale, weight: .semibold)
                        if lonWidth > w[0] + 0.5 { failures.append("\(name): the band's \(longitude) needs \(Int(lonWidth)) of \(Int(w[0])) pt") }
                        let timeWidth = textWidth("↓\u{00A0}\(Look.timeText(sunset))", size: 13 * Look.minScale, weight: .semibold)
                        if timeWidth > w[2] + 0.5 { failures.append("\(name): the band's sunset needs \(Int(timeWidth)) of \(Int(w[2])) pt") }
                    }
                    if p.grid == .strip && k == 1 {
                        let w = p.stripWidths
                        let size: CGFloat = (p.tablet ? ramp.value : Look.compactValueSize) * Look.minScale
                        let lonWidth = textWidth(longitude, size: size, weight: .medium)
                        if lonWidth > w[0] - 24 + 0.5 { failures.append("\(name): the strip's \(longitude) needs \(Int(lonWidth)) of \(Int(w[0] - 24)) pt") }
                    }
                }
            }
        }
        return failures
    }

    /// "No heading" as drawn (Concept A, replacing the dash check): 12 under a stand-in dial, the rendered ink
    /// is centred on the column (±2), its top 12 ± 2 under the dial, its capital 24 ± 3 tall (34 semibold),
    /// 150–200 wide, white at 0.55 ± 0.03, and not a single horizontal bar. Empty when all is well.
    @MainActor
    static func noHeadingFailures() -> [String] {
        var failures: [String] = []
        let column: CGFloat = 370, dialSide: CGFloat = 100
        let slot = LayoutPlan.readoutSlot(headingSize: LayoutPlan.heading, k: 1, noCompass: true)
        let view = VStack(spacing: 0) {
            Color.clear.frame(width: dialSide, height: dialSide)
            NoHeadingReadout()
                .frame(height: slot, alignment: .top)
                .frame(maxWidth: .infinity)
                .padding(.top, LayoutPlan.dialToReadout)
            Spacer(minLength: 0)
        }
        .frame(width: column, height: 200, alignment: .top)
        .background(Color.black)
        guard let px = Pixels(render: view) else { return ["\"No heading\" didn't draw"] }
        guard let rows = px.inkRows(x0: 0, x1: column, threshold: 30),
              let columns = px.inkColumns(y0: rows.top, y1: rows.bottom, x0: 0, x1: column, threshold: 30) else {
            return ["\"No heading\" drew no ink"]
        }
        let top = rows.top - dialSide
        if abs(top - LayoutPlan.dialToReadout) > 2 {
            failures.append(String(format: "\"No heading\" starts %.1f under the dial, not 12", top))
        }
        let centre = (columns.left + columns.right) / 2
        if abs(centre - column / 2) > 2 {
            failures.append(String(format: "\"No heading\" is centred at %.1f, the column at %.0f", centre, column / 2))
        }
        let width = columns.right - columns.left
        if width < 150 || width > 200 {
            failures.append(String(format: "\"No heading\" is %.0f wide, not 150–200", width))
        }
        // The capital N alone: the first 12 pt of ink.
        if let n = px.inkRows(x0: columns.left, x1: columns.left + 12, threshold: 30) {
            let cap = n.bottom - n.top
            if abs(cap - 24) > 3 { failures.append(String(format: "\"No heading\"'s capital is %.1f tall, not 24", cap)) }
        }
        let level = CGFloat(px.maxLevel(x0: columns.left, x1: columns.right, y0: rows.top, y1: rows.bottom)) / 255
        if abs(level - CGFloat(Palette.Op.noHeading)) > 0.03 {
            failures.append(String(format: "\"No heading\" is white at %.2f, not 0.55", level))
        }
        if rows.bottom - rows.top < 20 || px.inkBands(threshold: 30).count != 1 {
            failures.append("\"No heading\" drew as a bar, not words")
        }
        return failures
    }

    /// Both Position lines at one size, as drawn: in a tile too narrow for the longer line at its size, the
    /// two lines' ink is the same height. Empty when all is well.
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
    /// live (nothing locked or marked) states: the location card starts where planned (under the status
    /// line, nothing above the dial); "No heading" sits 12 under the dial with no compass; the Targets card
    /// has a row where planned; each grid row has as many tiles as the plan's row; a map card is where
    /// planned; the empty band at the bottom is what the plan left (24 or less unless the plan centred the
    /// stack); and neighbouring layouts don't draw the same thing. `nav` is a navigator of its own (its
    /// sample state is changed). Returns failures and info lines.
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
                                           noCompass: nav.noCompass, mac: isMac, speed: nav.speed,
                                           splitPosition: nav.format == .dd)
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
                let x0 = (width - plan.columnWidth) / 2 - 4, x1 = (width + plan.columnWidth) / 2 + 4
                // The location card: its sky starts where planned, under the status line (20 in, clear of
                // its corner).
                if let top = px.firstInk(x: (width - plan.columnWidth) / 2 + 20, from: plan.statusTop, threshold: 30),
                   abs(top - plan.locationTop) > 1.5 {
                    failures.append(String(format: "%@: the location card starts at %.1f, planned %.1f", name, top, plan.locationTop))
                }
                // No compass: "No heading" 12 under the dial, centred.
                if plan.noCompass {
                    if let ink = px.inkRows(x0: width / 2 - 110, x1: width / 2 + 110, y0: plan.dialTop + plan.dial + 1,
                                            y1: plan.readoutTop + plan.readoutSlot, threshold: 30) {
                        if abs(ink.top - plan.readoutTop) > 2 {
                            failures.append(String(format: "%@: \"No heading\" starts at %.1f, planned %.1f", name, ink.top, plan.readoutTop))
                        }
                    } else {
                        failures.append("\(name): no \"No heading\" under the dial")
                    }
                }
                var signature: [Int] = []
                // The Targets card: one block per planned row.
                if plan.hasTargets {
                    let y = plan.targetsTop + plan.targetsRowHeight / 2
                    if px.segments(y: y, x0: x0, x1: x1) != 1 { failures.append("\(name): no Targets card where planned") }
                    signature.append(-plan.targetsRows)
                }
                // The grid as drawn: tiles per row at each planned row.
                var y = plan.gridTop
                for (i, row) in plan.cells.enumerated() {
                    let rowHeight = i < plan.rowHeights.count ? plan.rowHeights[i] : plan.tileHeight
                    let drawn = px.segments(y: y + rowHeight / 2, x0: x0, x1: x1)
                    signature.append(drawn)
                    if drawn != row.count {
                        failures.append("\(name): grid row \(i + 1) draws \(drawn) tile(s), planned \(row.count)")
                    }
                    y += rowHeight + plan.gap
                }
                if plan.map == .card {
                    let drawn = px.segments(y: plan.mapTop + plan.mapHeight / 2, x0: x0, x1: x1)
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
                    if plan.centred { info.append(String(format: "%@: centred, %.0f over and under the stack", name, plan.topExtra)) }
                }
                info.append("\(name): \(plan.description)")
            }
            // Neighbouring layouts never draw the same thing as the same plan.
            for (i, layout) in Layout.allCases.enumerated().dropLast() {
                let a = signatures[i], b = signatures[i + 1]
                let same = plans[i].grid == plans[i + 1].grid && plans[i].map == plans[i + 1].map
                    && abs(plans[i].dial - plans[i + 1].dial) < 0.5
                if !a.isEmpty && a == b && same {
                    failures.append("\(size) \(state.name): \(layout.rawValue) and \(Layout.allCases[i + 1].rawValue) draw the same screen \(a)")
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

    /// The top and bottom (points) of everything brighter than `threshold` between x0 and x1 and y0 and y1.
    func inkRows(x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat, threshold: Int) -> (top: CGFloat, bottom: CGFloat)? {
        let a = max(0, Int(x0 * scale)), b = min(width, Int(x1 * scale))
        let top0 = max(0, Int(y0 * scale)), bottom0 = min(height, Int((y1 * scale).rounded(.up)))
        guard a < b, top0 < bottom0 else { return nil }
        var top: Int?, bottom: Int?
        for y in top0..<bottom0 {
            for x in a..<b where level(x, y) > threshold {
                if top == nil { top = y }
                bottom = y
                break
            }
        }
        guard let top, let bottom else { return nil }
        return (CGFloat(top) / scale, CGFloat(bottom + 1) / scale)
    }

    /// The brightest level (0…255) in a box (points).
    func maxLevel(x0: CGFloat, x1: CGFloat, y0: CGFloat, y1: CGFloat) -> Int {
        let a = max(0, Int(x0 * scale)), b = min(width, Int(x1 * scale))
        let top = max(0, Int(y0 * scale)), bottom = min(height, Int((y1 * scale).rounded(.up)))
        guard a < b, top < bottom else { return 0 }
        var best = 0
        for y in top..<bottom {
            for x in a..<b { best = max(best, level(x, y)) }
        }
        return best
    }

    /// The first row at or under `from` (points) with ink brighter than `threshold` in the column at x.
    func firstInk(x: CGFloat, from: CGFloat, threshold: Int) -> CGFloat? {
        let column = Int(x * scale)
        let start = max(0, Int(from * scale))
        guard start < height else { return nil }
        for y in start..<height where level(column, y) > threshold { return CGFloat(y) / scale }
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
