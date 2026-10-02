// Draws the app icon from the same palette and shapes as the in-app scene.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit
import CoreGraphics

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}
let night = 0x06141D, deepSea = 0x0A2630, horizon = 0x244651, moon = 0xDCE7E9, mist = 0x91A8AD, lantern = 0xF3C969, ink = 0x10232A

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let s = CGFloat(size)
// CoreGraphics origin is bottom-left; think in "y up".
let sky = CGGradient(colorsSpace: space, colors: [color(UInt32(night)), color(UInt32(deepSea)), color(UInt32(horizon))] as CFArray, locations: [0, 0.75, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: s * 0.38), options: [])
let horizonY = s * 0.38
let sea = CGGradient(colorsSpace: space, colors: [color(UInt32(deepSea)), color(UInt32(night))] as CFArray, locations: [0, 1])!
ctx.saveGState(); ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizonY))
ctx.drawLinearGradient(sea, start: CGPoint(x: 0, y: horizonY), end: CGPoint(x: 0, y: 0), options: []); ctx.restoreGState()

// Stars
var seed: UInt64 = 0x1A7E44
func unit() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 11) / Double(1 << 53)) }
for _ in 0..<40 {
    let x = unit() * s, y = horizonY + unit() * (s - horizonY) * 0.9, r = 1.5 + unit() * 3
    ctx.setFillColor(color(UInt32(moon), 0.3 + unit() * 0.6)); ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// Wave lines
ctx.setStrokeColor(color(UInt32(horizon), 0.7)); ctx.setLineWidth(5)
for row in 0..<6 {
    let t = CGFloat(row + 1) / 6, y = horizonY - pow(t, 1.5) * horizonY * 0.95
    let amp = 4 + 10 * t, wl = 120 + 160 * t
    ctx.move(to: CGPoint(x: -wl, y: y))
    var x: CGFloat = -wl
    while x < s + wl { x += 12; ctx.addLine(to: CGPoint(x: x, y: y + amp * sin((x + CGFloat(row) * 60) / wl * 2 * .pi))) }
    ctx.strokePath()
}

let tx = s * 0.52, baseY = horizonY + 10, towerH = s * 0.36, topY = baseY + towerH
let lanternC = CGPoint(x: tx, y: topY + 24 + 56)

// Glow
let glow = CGGradient(colorsSpace: space, colors: [color(UInt32(lantern), 0.55), color(UInt32(lantern), 0.12), color(UInt32(lantern), 0)] as CFArray, locations: [0, 0.45, 1])!
ctx.drawRadialGradient(glow, startCenter: lanternC, startRadius: 0, endCenter: lanternC, endRadius: s * 0.34, options: [])

// Beams (two, slightly downward left and right as if sweeping towards the viewer)
for dir: CGFloat in [-1, 1] {
    let len = s * 0.9, angle: CGFloat = -0.08, spread: CGFloat = 0.1
    func p(_ a: CGFloat) -> CGPoint { CGPoint(x: lanternC.x + dir * len * cos(a), y: lanternC.y + len * sin(a)) }
    ctx.saveGState()
    ctx.move(to: lanternC); ctx.addLine(to: p(angle - spread)); ctx.addLine(to: p(angle + spread)); ctx.closePath(); ctx.clip()
    let beam = CGGradient(colorsSpace: space, colors: [color(UInt32(lantern), dir < 0 ? 0.7 : 0.35), color(UInt32(lantern), 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(beam, start: lanternC, end: p(angle), options: [])
    ctx.restoreGState()
}

// Rock
ctx.setFillColor(color(UInt32(night)))
ctx.move(to: CGPoint(x: tx - 300, y: baseY - 50)); ctx.addQuadCurve(to: CGPoint(x: tx + 320, y: baseY - 55), control: CGPoint(x: tx, y: baseY + 40))
ctx.addLine(to: CGPoint(x: tx + 320, y: baseY - 90)); ctx.addLine(to: CGPoint(x: tx - 300, y: baseY - 90)); ctx.closePath(); ctx.fillPath()

// Tower
func edges(_ f: CGFloat) -> (CGFloat, CGFloat) { let half = 60 - 18 * f; return (tx - half, tx + half) }
func band(_ lo: CGFloat, _ hi: CGFloat) { let (bl, br) = edges(lo), (tl, tr) = edges(hi); ctx.move(to: CGPoint(x: bl, y: baseY + towerH * lo)); ctx.addLine(to: CGPoint(x: br, y: baseY + towerH * lo)); ctx.addLine(to: CGPoint(x: tr, y: baseY + towerH * hi)); ctx.addLine(to: CGPoint(x: tl, y: baseY + towerH * hi)); ctx.closePath(); ctx.fillPath() }
ctx.setFillColor(color(UInt32(moon))); band(0, 1)
ctx.setFillColor(color(UInt32(mist), 0.45)); let (_, br0) = edges(0), (_, tr1) = edges(1)
ctx.move(to: CGPoint(x: tx, y: baseY)); ctx.addLine(to: CGPoint(x: br0, y: baseY)); ctx.addLine(to: CGPoint(x: tr1, y: topY)); ctx.addLine(to: CGPoint(x: tx, y: topY)); ctx.closePath(); ctx.fillPath()
ctx.setFillColor(color(UInt32(horizon))); band(0.34, 0.44); band(0.62, 0.72)
ctx.fill(CGRect(x: tx - 62, y: topY, width: 124, height: 14))
ctx.setFillColor(color(UInt32(lantern))); ctx.fill(CGRect(x: tx - 34, y: topY + 14, width: 68, height: 76))
ctx.setFillColor(color(UInt32(ink), 0.45)); for m in [-11.0, 11.0] { ctx.fill(CGRect(x: tx + CGFloat(m) - 2, y: topY + 14, width: 4, height: 76)) }
ctx.setFillColor(color(UInt32(horizon))); ctx.move(to: CGPoint(x: tx - 48, y: topY + 90)); ctx.addLine(to: CGPoint(x: tx + 48, y: topY + 90)); ctx.addLine(to: CGPoint(x: tx, y: topY + 146)); ctx.closePath(); ctx.fillPath()

// Reflection
for row in 0..<6 { let t = CGFloat(row + 1) / 6, y = baseY - 110 - t * (baseY - 140), w = (20 + 80 * t) * (row % 2 == 0 ? 1 : 0.6)
    ctx.setFillColor(color(UInt32(lantern), 0.5 * (1 - t * 0.6))); ctx.fill(CGRect(x: tx - w / 2, y: y, width: w, height: 5)) }

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
let data = rep.representation(using: .png, properties: [:])!
try! data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
