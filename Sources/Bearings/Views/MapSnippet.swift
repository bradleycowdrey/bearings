import MapKit
import SwiftUI

/// An Apple Maps view of where you are: a dot with the accuracy circle and a cone toward your heading,
/// north up or turning with you. +, − and the heading button sit top right with the button that opens
/// the place in Maps; your speed shows top left while you're moving (bottom left is where Apple Maps puts
/// its logo and Legal link, which must stay visible and reachable).
struct MapSnippet: View {
    var fix: Fix?
    var heading: Double?
    @Binding var followHeading: Bool
    var satellite = false
    /// "3.2 mph", while moving.
    var speed: String? = nil
    var dimmed = false
    @Environment(\.openURL) private var openURL
    /// The column's type scale (Text Size, and the wider iPad and Mac column), so the speed grows with the rest.
    @Environment(\.uiScale) private var k
    @AppStorage("mapDistance") private var distance: Double = 1600
    @State private var position: MapCameraPosition = .automatic
    /// The heading the camera was last turned to, so it turns in 3° steps rather than on every reading.
    @State private var cameraHeading: Double = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let fix {
                let here = CLLocationCoordinate2D(latitude: fix.latitude, longitude: fix.longitude)
                Map(position: $position, interactionModes: []) {
                    MapCircle(center: here, radius: max(fix.accuracy, 1))
                        .foregroundStyle(Color.white.opacity(0.1))
                        .stroke(Color.white.opacity(0.4), lineWidth: 1)
                    Annotation("My Location", coordinate: here, anchor: .center) {
                        // Following the heading, the map turns instead: the cone then always points up.
                        MeDot(heading: heading.map { followHeading ? 0 : $0 })
                    }
                    .annotationTitles(.hidden)
                }
                .mapStyle(satellite ? MapStyle.imagery(elevation: .flat) : MapStyle.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .brightness(dimmed ? -0.25 : 0)
                .onAppear { move(to: here, animated: false) }
                .onChange(of: fix) { move(to: here, animated: true) }
                .onChange(of: distance) { move(to: here, animated: true) }
                .onChange(of: followHeading) { move(to: here, animated: true) }
                .onChange(of: heading) {
                    guard followHeading, let heading, abs(Geo.delta(from: cameraHeading, to: heading)) >= 3 else { return }
                    move(to: here, animated: false)
                }
                .accessibilityLabel("Map of where you are")

                // A column down the right; a row across the top when the map is too short for one.
                ViewThatFits(in: .vertical) {
                    VStack(spacing: 0) { controls(fix) }
                    HStack(spacing: 0) { controls(fix) }
                }
                // 2 plus the button's 6 inset puts the drawn circles 8 from the edges.
                .padding(2)

                if let speed {
                    // A non-breaking space keeps "3.2 mph" on one line.
                    Text(speed.replacingOccurrences(of: " ", with: "\u{00A0}"))
                        .font(.system(size: 13 * k, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .environment(\.colorScheme, .dark)
                        .padding(8)
                        // Top left: free in both the column and the row of controls, and clear of the
                        // map's attribution at the bottom left.
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .accessibilityLabel("Speed, \(speed)")
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
        .clipShape(RoundedRectangle(cornerRadius: Look.radius, style: .continuous))
        // Two Degrees' faint edge, drawn over the map.
        .overlay(RoundedRectangle(cornerRadius: Look.radius, style: .continuous)
            .strokeBorder(Palette.tileStroke, lineWidth: Look.stroke)
            .allowsHitTesting(false))
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
        let turn = followHeading ? (heading ?? 0) : 0
        cameraHeading = turn
        let camera = MapCameraPosition.camera(MapCamera(centerCoordinate: here, distance: distance, heading: turn))
        if animated { withAnimation(.easeInOut(duration: 0.4)) { position = camera } } else { position = camera }
    }
}

private struct MapButton: View {
    let label: String
    let system: String
    var highlighted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                // On: a white circle with a black glyph, as Two Degrees' and Meridian's highlights.
                .foregroundStyle(highlighted ? Color.black : Color.white)
                .frame(width: 32, height: 32)
                .background {
                    if highlighted {
                        Circle().fill(Color.white)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                    }
                }
                .environment(\.colorScheme, .dark)
                // 32 drawn, 44 to tap.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// You on the map: a white dot with a soft dark ring, and a white cone toward your heading when the compass
/// is on.
struct MeDot: View {
    var heading: Double?

    var body: some View {
        ZStack {
            if let heading {
                Cone()
                    .fill(LinearGradient(colors: [Color.white.opacity(0.45), Color.white.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 60, height: 60)
                    .offset(y: -30)
                    .rotationEffect(.degrees(heading))
            }
            Circle().fill(Color.white).frame(width: 16, height: 16)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 3))
                .shadow(color: .black.opacity(0.5), radius: 3, y: 1)
        }
        .frame(width: 120, height: 120)
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
