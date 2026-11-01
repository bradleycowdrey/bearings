import MapKit
import SwiftUI

/// An Apple Maps view of where you are: a dot with the accuracy circle and a cone toward your heading,
/// north up or turning with you. +, − and the heading button sit top right with the button that opens
/// the place in Maps; your speed shows bottom left while you're moving.
struct MapSnippet: View {
    var fix: Fix?
    var heading: Double?
    @Binding var followHeading: Bool
    var satellite = false
    /// "3.2 mph", while moving.
    var speed: String? = nil
    var dimmed = false
    @Environment(\.openURL) private var openURL
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
                        .foregroundStyle(Palette.accent.opacity(0.16))
                        .stroke(Palette.accent.opacity(0.5), lineWidth: 1)
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
                .padding(4)

                if let speed {
                    Text(speed)
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.cream)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(Palette.bg.opacity(0.86)))
                        .overlay(Capsule().stroke(Palette.border, lineWidth: 0.5))
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .accessibilityLabel("Speed, \(speed)")
                }
            } else {
                Text("The map appears once Bearings knows where you are.")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.tile)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(highlighted ? Palette.accent : Palette.cream)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Palette.bg.opacity(0.86)))
                .overlay(Circle().stroke(Palette.border, lineWidth: 0.5))
                // 32 drawn, 40 to tap.
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// You on the map: a crimson-pink dot, and a cone toward your heading when the compass is on.
struct MeDot: View {
    var heading: Double?

    var body: some View {
        ZStack {
            if let heading {
                Cone()
                    .fill(LinearGradient(colors: [Palette.accent.opacity(0.55), Palette.accent.opacity(0)], startPoint: .bottom, endPoint: .top))
                    .frame(width: 60, height: 60)
                    .offset(y: -30)
                    .rotationEffect(.degrees(heading))
            }
            Circle().fill(Palette.accent).frame(width: 16, height: 16)
                .overlay(Circle().stroke(.white, lineWidth: 3))
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
