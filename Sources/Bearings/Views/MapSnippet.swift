import MapKit
import SwiftUI

/// An Apple Maps view of where you are: a dot with the accuracy circle and a cone toward your heading,
/// north up or turning with you (docs/REFINE.md §3.2). As a **card** (and in the map sheet) the controls
/// are one vertical stack everywhere (C2.3 #10): 36 pt circles in 44 pt targets, 8 apart, 12 in from the
/// top-trailing corner: +, −, follow heading, open in Maps, or on a card under 192 tall +, − and ⋯ (follow
/// and open in Maps in its menu), in a row on a card under 148 (Small's map tile). Your speed shows top left while you're moving; the bottom stays clear for
/// Apple Maps' logo and Legal link. In the map sheet (`bleed`) it runs edge to edge under the sheet's
/// translucent bar (`topInset`). As a **thumbnail** (the Map tile, C3.4 #9) it is a still picture
/// (MKMapSnapshotter) north up with your dot and heading cone, no controls and no gestures, on a 24 pt
/// bottom scrim (clear to black at 65%) with "MAP" and an expand glyph leading and the Maps attribution trailing
/// (the snapshot's own baked-in logo is cropped off, so it never sits under "MAP"); the
/// live map's Legal link no longer lands in the middle of a 130 pt tile (the map sheet carries it). There
/// is no fade over it. At night it is grey and at 15% brightness or less, so it is never the brightest
/// thing on screen.
struct MapSnippet: View {
    var fix: Fix?
    var heading: Double?
    @Binding var followHeading: Bool
    var satellite = false
    /// "3.2 mph", while moving.
    var speed: String? = nil
    /// Night mode.
    var dimmed = false
    /// The Map tile: north up, no controls, no gestures, the "MAP" caption.
    var thumbnail = false
    /// The map sheet: no rounded frame, edge to edge.
    var bleed = false
    /// The map sheet: the height of the translucent bar over the map's top; the controls and the speed
    /// sit under it.
    var topInset: CGFloat = 0
    @Environment(\.openURL) private var openURL
    /// The column's type scale (Text Size), so the speed and caption grow with the rest.
    @Environment(\.uiScale) private var k
    @AppStorage("mapDistance") private var distance: Double = 1600
    @State private var position: MapCameraPosition = .automatic
    /// The heading the camera was last turned to, so it turns in 3° steps rather than on every reading.
    @State private var cameraHeading: Double = 0

    /// The map's brightness at night (§4.3): 15% or less.
    static let nightBrightness = 0.15

    /// A card shorter than this shows +, − and ⋯ (C2.3 #10): four 44 targets and 8 at each end.
    static let fullControlsHeight: CGFloat = 192
    /// The thumbnail's band at the bottom: "MAP" and the attribution (C3.4 #9).
    static let captionBand: CGFloat = 24

    /// The thumbnail is always north up.
    private var follows: Bool { followHeading && !thumbnail }

    var body: some View {
        if thumbnail {
            MapThumbnail(fix: fix, heading: heading, dimmed: dimmed)
                .modifier(CardFrame(bleed: false))
        } else {
            live
        }
    }

    private var live: some View {
        ZStack(alignment: .topTrailing) {
            if let fix {
                let here = CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude)
                Map(position: $position, interactionModes: []) {
                    MapCircle(center: here, radius: max(fix.accuracy, 1))
                        .foregroundStyle(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    Annotation("My Location", coordinate: here, anchor: .center) {
                        // Following the heading, the map turns instead: the cone then always points up.
                        MeDot(heading: heading.map { follows ? 0 : $0 }, scale: thumbnail ? 0.6 : 1)
                    }
                    .annotationTitles(.hidden)
                }
                .mapStyle(satellite ? MapStyle.imagery(elevation: .flat) : MapStyle.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .grayscale(dimmed ? 1 : 0)
                .colorMultiply(dimmed ? Color(white: Self.nightBrightness) : Color.white)
                .onAppear { move(to: here, animated: false) }
                .onChange(of: fix) { move(to: here, animated: true) }
                .onChange(of: distance) { move(to: here, animated: true) }
                .onChange(of: followHeading) { move(to: here, animated: true) }
                .onChange(of: heading) {
                    guard follows, let heading, abs(Geo.delta(from: cameraHeading, to: heading)) >= 3 else { return }
                    move(to: here, animated: false)
                }
                .accessibilityLabel("Map of where you are")

                if !thumbnail {
                    // One vertical stack on every card and sheet. 8 plus the 4 inside each 44 target puts
                    // the circles 12 from the corner; under 192 the stack is +, − and ⋯; under 148 (Small's
                    // map tile, a strip a tile high, or a 140 card) the same three in a row, 60 high. (Without
                    // the row, ViewThatFits fell back to the 148 stack, which made the card taller than its
                    // planned height and pushed everything under it down.)
                    ViewThatFits(in: .vertical) {
                        VStack(spacing: 0) { controls(fix) }
                            .padding(.vertical, 8)
                        VStack(spacing: 0) { shortControls(fix) }
                            .padding(.vertical, 8)
                        HStack(spacing: 0) { shortControls(fix) }
                            .padding(.vertical, 8)
                    }
                    .padding(.top, topInset)
                    .padding(.trailing, 8)

                    if let speed {
                        // A non-breaking space keeps "3.2 mph" on one line.
                        Text(speed.replacingOccurrences(of: " ", with: "\u{00A0}"))
                            .font(.system(size: 13 * k, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: Capsule())
                            .environment(\.colorScheme, .dark)
                            .padding(12)
                            .padding(.top, topInset)
                            // Top left: clear of the controls and of the attribution at the bottom.
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .accessibilityLabel("Speed, \(speed)")
                    }
                }
            } else {
                Text("The map appears once Bearings knows where you are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(Palette.Op.caption))
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.tileFill)
        .modifier(CardFrame(bleed: bleed))
    }

    /// +, − and ⋯ for a card under 192 tall: follow heading and open in Maps in the ⋯ menu.
    @ViewBuilder
    private func shortControls(_ fix: Fix) -> some View {
        MapButton(label: "Zoom In", system: "plus") { distance = max(250, distance / 2) }
        MapButton(label: "Zoom Out", system: "minus") { distance = min(64000, distance * 2) }
        Menu {
            Toggle("Follow Heading", isOn: $followHeading)
            Button("Open in Maps", systemImage: "arrow.up.right") { openURL(Navigator.mapsURL(fix)) }
        } label: {
            MapControlCircle(system: "ellipsis", highlighted: followHeading)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More Map Controls")
    }

    @ViewBuilder
    private func controls(_ fix: Fix) -> some View {
        MapButton(label: "Zoom In", system: "plus") { distance = max(250, distance / 2) }
        MapButton(label: "Zoom Out", system: "minus") { distance = min(64000, distance * 2) }
        MapButton(label: followHeading ? "North Up" : "Follow Heading",
                  system: followHeading ? "location.north.line.fill" : "location.north.line",
                  highlighted: followHeading) { followHeading.toggle() }
        MapButton(label: "Open in Maps", system: "arrow.up.right") { openURL(Navigator.mapsURL(fix)) }
    }

    private func move(to here: CLLocationCoordinate2D, animated: Bool) {
        let turn = follows ? (heading ?? 0) : 0
        cameraHeading = turn
        let camera = MapCameraPosition.camera(MapCamera(centerCoordinate: here, distance: distance, heading: turn))
        if animated { withAnimation(.easeInOut(duration: 0.4)) { position = camera } } else { position = camera }
    }
}

/// The Map tile's picture (C3.4 #9): a dark MKMapSnapshotter image of where you are, north up, your dot
/// and heading cone in the middle, and a 24 pt band with "MAP", the expand glyph and the Maps attribution.
/// The snapshot bakes Apple's Maps logo into its bottom-left corner, where it sat under "MAP". So it is
/// drawn `logoCrop` taller at each end and shown centred: its bottom 24 (the logo) and top 24 fall outside
/// the tile and the dot stays in the middle. The attribution is still on screen, as Apple-logo "Maps" in the band.
private struct MapThumbnail: View {
    var fix: Fix?
    var heading: Double?
    var dimmed: Bool
    @Environment(\.uiScale) private var k
    @State private var picture: PlatformImage?

    /// Cut off the snapshot's bottom (its baked-in logo) and, to keep you centred, as much off its top.
    static let logoCrop: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                ZStack {
                    Palette.tileFill
                    if let picture {
                        Self.image(picture)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height + 2 * Self.logoCrop)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        Image(systemName: "map")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(Color.white.opacity(Palette.Op.faint))
                            .padding(.bottom, MapSnippet.captionBand)
                    }
                    if fix != nil {
                        // The picture is centred on you.
                        MeDot(heading: heading, scale: 0.6)
                    }
                }
                .grayscale(dimmed ? 1 : 0)
                .colorMultiply(dimmed ? Color(white: MapSnippet.nightBrightness) : Color.white)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("MAP")
                        .font(.system(size: Look.tileCaptionSize * k, weight: .semibold))
                        .tracking(Look.tileCaptionTracking)
                    Spacer(minLength: 2)
                    // A still map carries its attribution itself.
                    Text("\u{F8FF}Maps")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(Palette.Op.label))
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(width: geo.size.width, height: MapSnippet.captionBand)
                // A 24 pt scrim: clear to black at 65%.
                .background(LinearGradient(colors: [Color.black.opacity(0), Color.black.opacity(0.65)],
                                           startPoint: .top, endPoint: .bottom))
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: Self.key(fix, geo.size)) {
                guard let fix, geo.size.width > 0, geo.size.height > 0 else { picture = nil; return }
                let taller = CGSize(width: geo.size.width, height: geo.size.height + 2 * Self.logoCrop)
                picture = await MapSnapshot.make(latitude: fix.latitude, longitude: fix.longitude, size: taller, span: 2000)
            }
        }
        .accessibilityHidden(true)
    }

    /// A new picture when you have moved about 10 m or the tile's size changes.
    private static func key(_ fix: Fix?, _ size: CGSize) -> String {
        guard let fix else { return "none" }
        return String(format: "%.4f,%.4f,%.0fx%.0f", fix.latitude, fix.longitude, size.width, size.height)
    }

    private static func image(_ image: PlatformImage) -> Image {
        #if os(iOS)
        return Image(uiImage: image)
        #else
        return Image(nsImage: image)
        #endif
    }
}

private struct MapButton: View {
    let label: String
    let system: String
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            MapControlCircle(system: system, highlighted: highlighted)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A map control's look: a 36 pt circle in a 44 pt target (stacked, the circles are 8 apart).
private struct MapControlCircle: View {
    let system: String
    var highlighted = false

    var body: some View {
        Image(systemName: system)
            .font(.system(size: 15, weight: .semibold))
            // On: a white circle with a black glyph, as Two Degrees' and Meridian's highlights.
            .foregroundStyle(highlighted ? Color.black : Color.white)
            .frame(width: 36, height: 36)
            .background {
                if highlighted {
                    Circle().fill(Color.white)
                } else {
                    Circle().fill(.ultraThinMaterial)
                }
            }
            .environment(\.colorScheme, .dark)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}

/// A card's rounded frame and faint edge; none in the map sheet, where the map runs edge to edge.
private struct CardFrame: ViewModifier {
    let bleed: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if bleed {
            content
        } else {
            content
                .clipShape(RoundedRectangle(cornerRadius: Look.radius, style: .continuous))
                // Two Degrees' faint edge, drawn over the map.
                .overlay(RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
                    .strokeBorder(Palette.tileStroke, lineWidth: Look.stroke)
                    .allowsHitTesting(false))
        }
    }
}

/// You on the map: a white dot with a soft dark ring, and a white cone toward your heading when the compass
/// is on.
struct MeDot: View {
    var heading: Double?
    /// Smaller in the Map tile.
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            if let heading {
                Cone()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 60 * scale, height: 60 * scale)
                    .offset(y: -30 * scale)
                    .rotationEffect(.degrees(heading))
            }
            Circle().fill(Color.white).frame(width: 16 * scale, height: 16 * scale)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 3))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
        }
        .frame(width: 120 * scale, height: 120 * scale)
        .accessibilityHidden(true)
    }
}

private struct Cone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
