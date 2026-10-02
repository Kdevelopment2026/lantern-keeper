import SwiftUI

/// Deterministic drawing of the lighthouse scene. Decorative only: no text, no state that
/// is not also expressed by an accessible view.
struct LighthouseDrawing {
    let state: LighthouseSceneState
    let frame: LighthouseFrame
    let highContrast: Bool

    private var isDawn: Bool { state == .dawn }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let layout = Layout(size: size)
        drawSky(&context, layout)
        drawStars(&context, layout)
        if !isDawn { drawMoon(&context, layout) }
        drawGlow(&context, layout)
        drawBeams(&context, layout)
        drawSea(&context, layout)
        drawFog(&context, layout)
        drawReflection(&context, layout)
        if state.showsShip { drawShip(&context, layout) }
        drawRock(&context, layout)
        drawTower(&context, layout)
    }

    // MARK: Layout

    struct Layout {
        let size: CGSize
        /// One design point, scaled from a 390 × 844 reference.
        let u: CGFloat
        let horizonY: CGFloat
        let towerX: CGFloat
        let towerBaseY: CGFloat
        let towerHeight: CGFloat
        let lanternCenter: CGPoint

        init(size: CGSize) {
            self.size = size
            u = max(0.1, min(size.width / 390, size.height / 844))
            horizonY = size.height * 0.6
            towerX = size.width * 0.68
            towerBaseY = horizonY + 22 * u
            towerHeight = 230 * u
            let towerTop = towerBaseY - towerHeight
            lanternCenter = CGPoint(x: towerX, y: towerTop - 6 * u - 14 * u)
        }

        /// Left and right x of the tapered tower at a fraction of its height.
        func towerEdges(at fraction: CGFloat) -> (CGFloat, CGFloat) {
            let half = (22 - 7 * fraction) * u
            return (towerX - half, towerX + half)
        }

        func towerY(at fraction: CGFloat) -> CGFloat {
            towerBaseY - towerHeight * fraction
        }
    }

    // MARK: Colours (derived from palette tokens)

    private var skyGradient: Gradient {
        isDawn
            ? Gradient(stops: [
                .init(color: Palette.horizon, location: 0),
                .init(color: Palette.mist, location: 0.55),
                .init(color: Palette.dawn, location: 1),
            ])
            : Gradient(stops: [
                .init(color: Palette.night, location: 0),
                .init(color: Palette.deepSea, location: 0.7),
                .init(color: Palette.horizon, location: 1),
            ])
    }

    private var seaGradient: Gradient {
        isDawn
            ? Gradient(colors: [Palette.horizon, Palette.deepSea])
            : Gradient(colors: [Palette.deepSea, Palette.night])
    }

    // MARK: Layers

    private func drawSky(_ context: inout GraphicsContext, _ layout: Layout) {
        let sky = CGRect(x: 0, y: 0, width: layout.size.width, height: layout.horizonY + 1)
        context.fill(Path(sky), with: .linearGradient(
            skyGradient,
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: layout.horizonY)
        ))
        if frame.nightDepth > 0 {
            context.fill(Path(sky), with: .color(Palette.night.opacity(0.45 * frame.nightDepth)))
        }
    }

    private func drawStars(_ context: inout GraphicsContext, _ layout: Layout) {
        var generator = SeededGenerator(seed: 0x1A7E_44)
        let baseOpacity = isDawn ? 0.12 : 0.55 + 0.25 * frame.nightDepth
        for _ in 0..<46 {
            let x = CGFloat(generator.unit()) * layout.size.width
            let y = CGFloat(generator.unit()) * layout.horizonY * 0.88
            let radius = (0.6 + CGFloat(generator.unit()) * 0.9) * layout.u
            let twinkle = 0.4 + generator.unit() * 0.6
            let star = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(star, with: .color(Palette.moon.opacity(baseOpacity * twinkle)))
        }
    }

    private func drawMoon(_ context: inout GraphicsContext, _ layout: Layout) {
        let r = 17 * layout.u
        let center = CGPoint(x: layout.size.width * 0.84, y: layout.size.height * 0.1)
        let disc = Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let bite = Path(ellipseIn: CGRect(x: center.x - r + 9 * layout.u, y: center.y - r - 5 * layout.u,
                                          width: r * 2, height: r * 2))
        context.fill(disc.subtracting(bite), with: .color(Palette.moon.opacity(0.9)))
    }

    private func drawGlow(_ context: inout GraphicsContext, _ layout: Layout) {
        guard frame.lanternIntensity > 0 else { return }
        let radius = 120 * layout.u
        let c = layout.lanternCenter
        context.fill(
            Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [Palette.lantern.opacity(0.42 * frame.lanternIntensity), Palette.lantern.opacity(0)]),
                center: c, startRadius: 0, endRadius: radius
            )
        )
    }

    private func drawBeams(_ context: inout GraphicsContext, _ layout: Layout) {
        let opacity = state.isBeamVisible ? frame.beamOpacity * frame.lanternIntensity : 0
        guard opacity > 0 else { return }
        let origin = layout.lanternCenter
        let length = layout.size.width * 1.5
        let spread = 6.5 * Double.pi / 180

        func beam(angle: Double, direction: CGFloat, strength: Double) {
            let a = angle * Double.pi / 180
            func point(_ theta: Double) -> CGPoint {
                CGPoint(x: origin.x + direction * length * CGFloat(cos(theta)),
                        y: origin.y - length * CGFloat(sin(theta)))
            }
            var path = Path()
            path.move(to: origin)
            path.addLine(to: point(a - spread))
            path.addLine(to: point(a + spread))
            path.closeSubpath()
            context.fill(path, with: .linearGradient(
                Gradient(colors: [Palette.lantern.opacity(strength * opacity), Palette.lantern.opacity(0)]),
                startPoint: origin,
                endPoint: point(a)
            ))
        }

        beam(angle: frame.beamAngle, direction: -1, strength: highContrast ? 0.75 : 0.6)
        beam(angle: frame.beamAngle * 0.5 - 4, direction: 1, strength: 0.22)
    }

    private func drawSea(_ context: inout GraphicsContext, _ layout: Layout) {
        let sea = CGRect(x: 0, y: layout.horizonY, width: layout.size.width,
                         height: layout.size.height - layout.horizonY)
        context.fill(Path(sea), with: .linearGradient(
            seaGradient,
            startPoint: CGPoint(x: 0, y: layout.horizonY),
            endPoint: CGPoint(x: 0, y: layout.size.height)
        ))

        let rows = 10
        let lineColor = isDawn ? Palette.moon : Palette.horizon
        for row in 0..<rows {
            let t = CGFloat(row + 1) / CGFloat(rows)
            let y = layout.horizonY + (layout.size.height - layout.horizonY) * pow(t, 1.6)
            let amplitude = (1 + 3 * t) * layout.u
            let wavelength = (36 + 70 * t) * layout.u
            let phase = (CGFloat(frame.seaPhase) + CGFloat(row) * 0.37) * wavelength
            var path = Path()
            var x: CGFloat = -wavelength
            path.move(to: CGPoint(x: x, y: y))
            while x <= layout.size.width + wavelength {
                x += 6 * layout.u
                let waveY = y + amplitude * sin((x + phase) / wavelength * 2 * .pi)
                path.addLine(to: CGPoint(x: x, y: waveY))
            }
            let opacity = (highContrast ? 0.9 : 0.35 + 0.4 * Double(t)) * (isDawn ? 0.55 : 1)
            context.stroke(path, with: .color(lineColor.opacity(opacity)), lineWidth: max(1, layout.u))
        }
    }

    private func drawFog(_ context: inout GraphicsContext, _ layout: Layout) {
        let span = layout.size.width * 1.6
        for band in 0..<2 {
            let offset = (CGFloat(frame.fogOffset) + CGFloat(band) * 0.55).truncatingRemainder(dividingBy: 1)
            let centerX = offset * span - layout.size.width * 0.3
            let centerY = layout.horizonY - 8 * layout.u + CGFloat(band) * 16 * layout.u
            let width = 280 * layout.u
            let height = 26 * layout.u
            let rect = CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
            context.fill(Path(ellipseIn: rect), with: .radialGradient(
                Gradient(colors: [Palette.moon.opacity(isDawn ? 0.18 : 0.07), Palette.moon.opacity(0)]),
                center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: width / 2
            ))
        }
    }

    private func drawReflection(_ context: inout GraphicsContext, _ layout: Layout) {
        guard frame.lanternIntensity > 0.05 else { return }
        for row in 0..<9 {
            let t = CGFloat(row + 1) / 9
            let y = layout.towerBaseY + 22 * layout.u + (layout.size.height - layout.towerBaseY - 40 * layout.u) * pow(t, 1.4)
            let width = (8 + 30 * t) * layout.u * (row.isMultiple(of: 2) ? 1 : 0.6)
            let rect = CGRect(x: layout.towerX - width / 2, y: y, width: width, height: max(1, 1.5 * layout.u))
            let opacity = 0.5 * frame.lanternIntensity * Double(1 - t * 0.6)
            context.fill(Path(rect), with: .color(Palette.lantern.opacity(opacity)))
        }
    }

    private func drawShip(_ context: inout GraphicsContext, _ layout: Layout) {
        let u = layout.u
        let base = CGPoint(x: layout.size.width * 0.24, y: layout.horizonY + 10 * u)
        var hull = Path()
        hull.move(to: CGPoint(x: base.x - 26 * u, y: base.y - 6 * u))
        hull.addLine(to: CGPoint(x: base.x + 26 * u, y: base.y - 6 * u))
        hull.addLine(to: CGPoint(x: base.x + 18 * u, y: base.y + 2 * u))
        hull.addLine(to: CGPoint(x: base.x - 20 * u, y: base.y + 2 * u))
        hull.closeSubpath()
        var sail = Path()
        sail.move(to: CGPoint(x: base.x + 2 * u, y: base.y - 44 * u))
        sail.addLine(to: CGPoint(x: base.x + 20 * u, y: base.y - 9 * u))
        sail.addLine(to: CGPoint(x: base.x + 2 * u, y: base.y - 9 * u))
        sail.closeSubpath()
        var jib = Path()
        jib.move(to: CGPoint(x: base.x - 1 * u, y: base.y - 36 * u))
        jib.addLine(to: CGPoint(x: base.x - 1 * u, y: base.y - 9 * u))
        jib.addLine(to: CGPoint(x: base.x - 16 * u, y: base.y - 9 * u))
        jib.closeSubpath()
        let shading = GraphicsContext.Shading.color(Palette.ink)
        context.fill(hull, with: shading)
        context.fill(sail, with: shading)
        context.fill(jib, with: shading)
    }

    private func drawRock(_ context: inout GraphicsContext, _ layout: Layout) {
        let u = layout.u
        let x = layout.towerX
        let y = layout.towerBaseY
        var rock = Path()
        rock.move(to: CGPoint(x: x - 110 * u, y: y + 18 * u))
        rock.addQuadCurve(to: CGPoint(x: x - 34 * u, y: y - 4 * u), control: CGPoint(x: x - 80 * u, y: y + 2 * u))
        rock.addQuadCurve(to: CGPoint(x: x + 46 * u, y: y - 2 * u), control: CGPoint(x: x + 4 * u, y: y - 10 * u))
        rock.addQuadCurve(to: CGPoint(x: x + 116 * u, y: y + 20 * u), control: CGPoint(x: x + 90 * u, y: y + 4 * u))
        rock.addQuadCurve(to: CGPoint(x: x - 110 * u, y: y + 18 * u), control: CGPoint(x: x, y: y + 30 * u))
        rock.closeSubpath()
        context.fill(rock, with: .color(isDawn ? Palette.ink : Palette.night))
        if highContrast {
            context.stroke(rock, with: .color(Palette.mist), lineWidth: max(1, u))
        }
    }

    private func drawTower(_ context: inout GraphicsContext, _ layout: Layout) {
        let u = layout.u

        func band(from lower: CGFloat, to upper: CGFloat) -> Path {
            let (bl, br) = layout.towerEdges(at: lower)
            let (tl, tr) = layout.towerEdges(at: upper)
            var path = Path()
            path.move(to: CGPoint(x: bl, y: layout.towerY(at: lower)))
            path.addLine(to: CGPoint(x: br, y: layout.towerY(at: lower)))
            path.addLine(to: CGPoint(x: tr, y: layout.towerY(at: upper)))
            path.addLine(to: CGPoint(x: tl, y: layout.towerY(at: upper)))
            path.closeSubpath()
            return path
        }

        let body = band(from: 0, to: 1)
        context.fill(body, with: .color(Palette.moon))

        // Right-hand shading gives the tower volume.
        var shade = Path()
        let (_, br) = layout.towerEdges(at: 0)
        let (_, tr) = layout.towerEdges(at: 1)
        shade.move(to: CGPoint(x: layout.towerX, y: layout.towerY(at: 0)))
        shade.addLine(to: CGPoint(x: br, y: layout.towerY(at: 0)))
        shade.addLine(to: CGPoint(x: tr, y: layout.towerY(at: 1)))
        shade.addLine(to: CGPoint(x: layout.towerX, y: layout.towerY(at: 1)))
        shade.closeSubpath()
        context.fill(shade, with: .color(Palette.mist.opacity(0.45)))

        // Bands use structure colours, never red.
        let bandColor = highContrast ? Palette.ink : Palette.horizon
        context.fill(band(from: 0.34, to: 0.44), with: .color(bandColor))
        context.fill(band(from: 0.62, to: 0.72), with: .color(bandColor))

        if highContrast {
            context.stroke(body, with: .color(Palette.ink), lineWidth: max(1, u))
        }

        // Gallery, lantern room and roof.
        let topY = layout.towerY(at: 1)
        let gallery = CGRect(x: layout.towerX - 22 * u, y: topY - 5 * u, width: 44 * u, height: 5 * u)
        context.fill(Path(gallery), with: .color(Palette.horizon))

        let room = CGRect(x: layout.towerX - 12 * u, y: gallery.minY - 28 * u, width: 24 * u, height: 28 * u)
        context.fill(Path(room), with: .color(Palette.horizon))
        if frame.lanternIntensity > 0 {
            context.fill(Path(room), with: .color(Palette.lantern.opacity(frame.lanternIntensity)))
        }
        for mullion in [-4.0, 4.0] {
            let line = CGRect(x: layout.towerX + CGFloat(mullion) * u - 0.5 * u, y: room.minY,
                              width: max(1, u), height: room.height)
            context.fill(Path(line), with: .color(Palette.ink.opacity(0.45)))
        }

        var roof = Path()
        roof.move(to: CGPoint(x: layout.towerX - 17 * u, y: room.minY))
        roof.addLine(to: CGPoint(x: layout.towerX + 17 * u, y: room.minY))
        roof.addLine(to: CGPoint(x: layout.towerX, y: room.minY - 20 * u))
        roof.closeSubpath()
        context.fill(roof, with: .color(isDawn ? Palette.ink : (highContrast ? Palette.mist : Palette.horizon)))
    }
}

/// Small deterministic generator so stars land in the same place on every frame and run.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func unit() -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Double(state >> 11) / Double(1 << 53)
    }
}
