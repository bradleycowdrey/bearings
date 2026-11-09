import SwiftUI

/// The sun and moon as Bearings draws them: on the dial, in the Sun tile and in the widgets.
enum SkyMarks {
    static let sun = Color(red: 0xF5 / 255, green: 0xB0 / 255, blue: 0x3C / 255)
    static let moon = Palette.cream
    static let moonDark = Color(red: 0x4A / 255, green: 0x44 / 255, blue: 0x3D / 255)

    /// The lit part of the moon for its phase (0 new, 0.5 full): the limb on the lit side, then back along
    /// the terminator, an ellipse that sweeps from that limb (new) through the middle (quarter) to the
    /// other limb (full). Lit on the right while waxing, as seen from the northern hemisphere.
    static func moonLit(center c: CGPoint, radius r: CGFloat, phase: Double) -> Path {
        let side: CGFloat = phase < 0.5 ? 1 : -1
        let k = CGFloat(cos(2 * Double.pi * phase))
        let steps = 24
        var p = Path()
        for i in 0...steps {
            let t = Double.pi * Double(i) / Double(steps)
            let pt = CGPoint(x: c.x + side * r * CGFloat(sin(t)), y: c.y - r * CGFloat(cos(t)))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        for i in stride(from: steps, through: 0, by: -1) {
            let t = Double.pi * Double(i) / Double(steps)
            p.addLine(to: CGPoint(x: c.x + side * r * k * CGFloat(sin(t)), y: c.y - r * CGFloat(cos(t))))
        }
        p.closeSubpath()
        return p
    }

    /// The sun: a disc with eight short rays.
    static func drawSun(_ ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, color: Color = SkyMarks.sun) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(color))
        var rays = Path()
        for i in 0..<8 {
            let a = Double(i) * Double.pi / 4
            let dx = CGFloat(sin(a)), dy = CGFloat(-cos(a))
            rays.move(to: CGPoint(x: c.x + dx * r * 1.45, y: c.y + dy * r * 1.45))
            rays.addLine(to: CGPoint(x: c.x + dx * r * 2.0, y: c.y + dy * r * 2.0))
        }
        ctx.stroke(rays, with: .color(color), style: StrokeStyle(lineWidth: max(1, r * 0.32), lineCap: .round))
    }

    /// The moon: its dark disc, faint, and the lit part over it.
    static func drawMoon(_ ctx: GraphicsContext, at c: CGPoint, radius r: CGFloat, phase: Double, color: Color = SkyMarks.moon) {
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)), with: .color(moonDark))
        ctx.fill(moonLit(center: c, radius: r, phase: phase), with: .color(color))
    }
}

/// The moon for its phase, as a small glyph beside text.
struct MoonGlyph: View {
    var phase: Double
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, s in
            SkyMarks.drawMoon(ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), radius: min(s.width, s.height) / 2, phase: phase)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The sun as a small glyph.
struct SunGlyph: View {
    var size: CGFloat = 14

    var body: some View {
        Canvas { ctx, s in
            SkyMarks.drawSun(ctx, at: CGPoint(x: s.width / 2, y: s.height / 2), radius: min(s.width, s.height) / 4)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
