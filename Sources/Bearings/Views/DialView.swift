import SwiftUI

/// The compass card: ticks every 2°, numbers every 30°, the four points, the sun and moon, a marked spot
/// and a lock mark. It turns opposite to the phone, under a fixed lubber line at the top. In the middle
/// sits a bubble level. Drawn as Two Degrees would: a faint white disc with white ticks and letters, pink
/// only for north (as on the app icon's needle), and white for the marked spot, the lock and the lubber line.
struct DialView: View {
    /// Something in the sky, placed on the card.
    struct SkyMark: Equatable {
        /// Degrees on the card (already turned to the card's north).
        var angle: Double
        var aboveHorizon: Bool
    }

    /// The card's rotation (Navigator.cardRotation), degrees.
    var rotation: Double
    var heading: Double?
    var lock: Double?
    /// Gravity across the screen, -1…1 (nil hides the bubble).
    var tilt: CGVector?
    var sun: SkyMark? = nil
    var moon: SkyMark? = nil
    var moonPhase: Double = 0
    /// The marked spot's direction on the card.
    var spot: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let k = side / 400
            ZStack {
                Circle().fill(Palette.tileFill)
                Circle().strokeBorder(Palette.tileStroke, lineWidth: Look.stroke)
                card(k: k)
                    .rotationEffect(.degrees(rotation))
                fixedParts(k: k)
                bubble(k: k)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func card(k: CGFloat) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            for d in stride(from: 0, to: 360, by: 2) {
                let major = d % 30 == 0, mid = d % 10 == 0
                let len: CGFloat = major ? 18 : mid ? 12 : 6
                let width: CGFloat = major ? 2.4 : mid ? 1.4 : 1
                let color = d == 0 ? Palette.north : major ? Color.white : mid ? Color.white.opacity(Palette.Op.caption) : Color.white.opacity(Palette.Op.minor)
                var c2 = ctx
                c2.translateBy(x: c.x, y: c.y)
                c2.rotate(by: .degrees(Double(d)))
                var tick = Path()
                tick.move(to: CGPoint(x: 0, y: (-188) * k))
                tick.addLine(to: CGPoint(x: 0, y: (-188 + len) * k))
                c2.stroke(tick, with: .color(color), style: StrokeStyle(lineWidth: width * k, lineCap: .round))
            }
            func label(_ text: String, _ deg: Double, radius: CGFloat, size: CGFloat, weight: Font.Weight, color: Color) {
                var c2 = ctx
                c2.translateBy(x: c.x, y: c.y)
                c2.rotate(by: .degrees(deg))
                c2.draw(Text(text).font(.system(size: size * k, weight: weight)).foregroundColor(color), at: CGPoint(x: 0, y: -radius * k))
            }
            for d in stride(from: 30, to: 360, by: 30) where d % 90 != 0 {
                label("\(d)", Double(d), radius: 149, size: 15, weight: .medium, color: Color.white.opacity(Palette.Op.caption))
            }
            for (l, d) in [("NE", 45.0), ("SE", 135), ("SW", 225), ("NW", 315)] {
                label(l, d, radius: 147, size: 13, weight: .semibold, color: Color.white.opacity(Palette.Op.points))
            }
            label("N", 0, radius: 147, size: 30, weight: .semibold, color: Palette.north)
            for (l, d) in [("E", 90.0), ("S", 180), ("W", 270)] {
                label(l, d, radius: 147, size: 26, weight: .semibold, color: .white)
            }
            // The sun and moon at their azimuths, inside the numbers; faint below the horizon.
            func onCard(_ deg: Double, _ radius: CGFloat) -> CGPoint {
                let a = deg * Double.pi / 180
                return CGPoint(x: c.x + CGFloat(sin(a)) * radius * k, y: c.y - CGFloat(cos(a)) * radius * k)
            }
            if let moon {
                var m = ctx
                m.opacity = moon.aboveHorizon ? 1 : 0.35
                SkyMarks.drawMoon(m, at: onCard(moon.angle, 118), radius: 10 * k, phase: moonPhase)
            }
            if let sun {
                var m = ctx
                m.opacity = sun.aboveHorizon ? 1 : 0.35
                SkyMarks.drawSun(m, at: onCard(sun.angle, 118), radius: 8 * k)
            }
            // A marked spot: a white teardrop on the outer ring, its point toward the middle.
            if let spot {
                var c2 = ctx
                c2.translateBy(x: c.x, y: c.y)
                c2.rotate(by: .degrees(spot))
                var pin = Path()
                let head = CGPoint(x: 0, y: -176 * k), r = 8 * k
                pin.addArc(center: head, radius: r, startAngle: .degrees(150), endAngle: .degrees(30), clockwise: false)
                pin.addLine(to: CGPoint(x: 0, y: -160 * k))
                pin.closeSubpath()
                c2.fill(pin, with: .color(.white))
                c2.stroke(pin, with: .color(.black), lineWidth: 1.5 * k)
                c2.fill(Path(ellipseIn: CGRect(x: -3 * k, y: -179 * k, width: 6 * k, height: 6 * k)), with: .color(.black))
            }
            // A locked bearing: a mark on the card and an arc to where the phone points.
            if let lock {
                var c2 = ctx
                c2.translateBy(x: c.x, y: c.y)
                c2.rotate(by: .degrees(lock))
                var mark = Path()
                mark.move(to: CGPoint(x: 0, y: -190 * k)); mark.addLine(to: CGPoint(x: 7 * k, y: -200 * k)); mark.addLine(to: CGPoint(x: -7 * k, y: -200 * k)); mark.closeSubpath()
                c2.fill(mark, with: .color(.white))
                if let heading {
                    let sweep = Geo.delta(from: lock, to: heading)
                    if abs(sweep) >= 0.5 {
                        var arc = Path()
                        arc.addArc(center: c, radius: 190 * k, startAngle: .degrees(lock - 90), endAngle: .degrees(lock + sweep - 90), clockwise: sweep < 0)
                        ctx.stroke(arc, with: .color(Color.white.opacity(Palette.Op.body)), style: StrokeStyle(lineWidth: 6 * k, lineCap: .round))
                    }
                }
            }
        }
    }

    private func fixedParts(k: CGFloat) -> some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var lubber = Path()
            lubber.move(to: CGPoint(x: c.x, y: 0)); lubber.addLine(to: CGPoint(x: c.x + 9 * k, y: 16 * k)); lubber.addLine(to: CGPoint(x: c.x - 9 * k, y: 16 * k)); lubber.closeSubpath()
            ctx.fill(lubber, with: .color(.white))
            var cross = Path()
            cross.move(to: CGPoint(x: c.x, y: c.y - 112 * k)); cross.addLine(to: CGPoint(x: c.x, y: c.y + 112 * k))
            cross.move(to: CGPoint(x: c.x - 112 * k, y: c.y)); cross.addLine(to: CGPoint(x: c.x + 112 * k, y: c.y))
            ctx.stroke(cross, with: .color(Color.white.opacity(0.07)), lineWidth: 1)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 40 * k, y: c.y - 40 * k, width: 80 * k, height: 80 * k)), with: .color(Color.white.opacity(Palette.Op.track)), lineWidth: 1.5)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - 13 * k, y: c.y - 13 * k, width: 26 * k, height: 26 * k)), with: .color(Color.white.opacity(Palette.Op.track)), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func bubble(k: CGFloat) -> some View {
        if let tilt {
            // The bubble rises to the high side: opposite to gravity, 30° of tilt to the ring's edge.
            let degX = asin(max(-1, min(1, tilt.dx))) * 180 / .pi, degY = asin(max(-1, min(1, tilt.dy))) * 180 / .pi
            let x = max(-1, min(1, -degX / 30)), y = max(-1, min(1, -degY / 30))
            let len = (x * x + y * y).squareRoot(), scale = len > 1 ? 1 / len : 1
            let level = (degX * degX + degY * degY).squareRoot() < 2
            Circle()
                .fill(level ? Palette.level : Color.white)
                .frame(width: 22 * k, height: 22 * k)
                .offset(x: x * scale * 40 * k, y: y * scale * 40 * k)
                .accessibilityHidden(true)
        }
    }
}
