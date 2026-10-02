import AppKit
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Frames a raw simulator screenshot for the App Store in Lantern Keeper's own
// design: night-sky gradient with seeded stars, a lantern glow on the horizon
// beneath the device, a New York serif headline and SF subline at the top, the
// screen below with a thin bezel and a soft shadow. Output keeps the input size
// (1320×2868 for the 6.9-inch iPhone).
//
//   swift compose_screenshot.swift <in.png> <out.png> "<headline>" "<subline>"

let args = CommandLine.arguments
guard args.count == 5 else {
    FileHandle.standardError.write("usage: compose_screenshot.swift in out headline subline\n".data(using: .utf8)!)
    exit(1)
}
let (inPath, outPath, headline, subline) = (args[1], args[2], args[3], args[4])

let cs = CGColorSpace(name: CGColorSpace.sRGB)!
func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [
        CGFloat((value >> 16) & 0xFF) / 255, CGFloat((value >> 8) & 0xFF) / 255, CGFloat(value & 0xFF) / 255, alpha
    ])!
}
let night = 0x06141D, deepSea = 0x0A2630, horizon = 0x244651, moon = 0xDCE7E9, mist = 0x91A8AD, lantern = 0xF3C969

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inPath) as CFURL, nil),
      let screen = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    FileHandle.standardError.write("cannot read \(inPath)\n".data(using: .utf8)!)
    exit(1)
}
let width = screen.width, height = screen.height
let W = CGFloat(width), H = CGFloat(height)
let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Sky: night at the top, deep sea towards the bottom.
let sky = CGGradient(colorsSpace: cs, colors: [hex(UInt32(night)), hex(UInt32(deepSea)), hex(UInt32(horizon), 0.9)] as CFArray,
                     locations: [0, 0.72, 1])!
ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])

// Stars, seeded so every screenshot shares one sky.
var seed: UInt64 = 0x1A7E44
func unit() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(Double(seed >> 11) / Double(1 << 53)) }
for _ in 0..<90 {
    let x = unit() * W, y = H * 0.45 + unit() * H * 0.55, r = 1.2 + unit() * 2.6
    ctx.setFillColor(hex(UInt32(moon), 0.25 + unit() * 0.6))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
}

// Lantern glow rising from behind the device.
let glow = CGGradient(colorsSpace: cs, colors: [hex(UInt32(lantern), 0.34), hex(UInt32(lantern), 0.08), hex(UInt32(lantern), 0)] as CFArray,
                      locations: [0, 0.4, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: W / 2, y: H * 0.62), startRadius: 0,
                       endCenter: CGPoint(x: W / 2, y: H * 0.62), endRadius: W * 0.95, options: [])

// Text block at the top.
func font(size: CGFloat, weight: NSFont.Weight, serif: Bool) -> CTFont {
    let base = NSFont.systemFont(ofSize: size, weight: weight)
    if serif, let descriptor = base.fontDescriptor.withDesign(.serif), let f = NSFont(descriptor: descriptor, size: size) {
        return f as CTFont
    }
    return base as CTFont
}
func draw(_ text: String, font: CTFont, color: CGColor, y: CGFloat, lineSpacing: CGFloat) -> CGFloat {
    let alignment = UnsafeMutablePointer<CTTextAlignment>.allocate(capacity: 1)
    alignment.initialize(to: .center)
    let spacing = UnsafeMutablePointer<CGFloat>.allocate(capacity: 1)
    spacing.initialize(to: lineSpacing)
    defer { alignment.deallocate(); spacing.deallocate() }
    let settings = [
        CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: alignment),
        CTParagraphStyleSetting(spec: .lineSpacingAdjustment, valueSize: MemoryLayout<CGFloat>.size, value: spacing)
    ]
    let paragraph = CTParagraphStyleCreate(settings, settings.count)
    let attributed = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph
    ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let inset: CGFloat = 120
    let box = CGSize(width: W - inset * 2, height: 700)
    let fitted = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRange(location: 0, length: 0), nil, box, nil)
    let rect = CGRect(x: inset, y: y - fitted.height, width: box.width, height: fitted.height)
    let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: rect, transform: nil), nil)
    ctx.saveGState(); ctx.textMatrix = .identity; CTFrameDraw(frame, ctx); ctx.restoreGState()
    return rect.minY
}

var cursor = H - 230
cursor = draw(headline, font: font(size: 104, weight: .regular, serif: true), color: hex(UInt32(moon)), y: cursor, lineSpacing: 8)
cursor -= 30
cursor = draw(subline, font: font(size: 46, weight: .regular, serif: false), color: hex(UInt32(mist)), y: cursor, lineSpacing: 10)

// A short lantern rule between copy and device.
cursor -= 60
ctx.setFillColor(hex(UInt32(lantern)))
ctx.fill(CGRect(x: W / 2 - 36, y: cursor, width: 72, height: 5))

// Device: scaled, rounded, bezelled, hanging off the bottom edge.
let scale: CGFloat = 0.84
let screenW = W * scale, screenH = H * scale
let screenX = (W - screenW) / 2
let screenTop = cursor - 80
let screenRect = CGRect(x: screenX, y: screenTop - screenH, width: screenW, height: screenH)
let corner: CGFloat = 130 * scale
let bezel: CGFloat = 14
let frameRect = screenRect.insetBy(dx: -bezel, dy: -bezel)
let frameCorner = corner + bezel

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -40), blur: 110, color: hex(0x000000, 0.65))
ctx.setFillColor(hex(0x0B1A22))
ctx.addPath(CGPath(roundedRect: frameRect, cornerWidth: frameCorner, cornerHeight: frameCorner, transform: nil))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(CGPath(roundedRect: screenRect, cornerWidth: corner, cornerHeight: corner, transform: nil))
ctx.clip()
ctx.draw(screen, in: screenRect)
ctx.restoreGState()

// Bezel highlight so the edge reads against the night.
ctx.saveGState()
ctx.setStrokeColor(hex(UInt32(mist), 0.35))
ctx.setLineWidth(3)
ctx.addPath(CGPath(roundedRect: frameRect.insetBy(dx: 1.5, dy: 1.5), cornerWidth: frameCorner, cornerHeight: frameCorner, transform: nil))
ctx.strokePath()
ctx.restoreGState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
