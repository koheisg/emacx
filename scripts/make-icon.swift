// Renders the app icon as a 1024x1024 PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let canvas: CGFloat = 1024
// macOS icon grid: 824pt rounded square centered in a 1024pt canvas.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let radius: CGFloat = 185

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Drop shadow under the tile.
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 24
NSGraphicsContext.saveGraphicsState()
shadow.set()
let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
NSColor.black.setFill()
tilePath.fill()
NSGraphicsContext.restoreGraphicsState()

// Purple gradient tile (Emacs motif).
NSGradient(
    starting: NSColor(srgbRed: 0.62, green: 0.45, blue: 0.86, alpha: 1),
    ending: NSColor(srgbRed: 0.30, green: 0.16, blue: 0.55, alpha: 1)
)!.draw(in: tilePath, angle: -90)

// White ⌘ (Mac motif).
let glyph = NSAttributedString(string: "⌘", attributes: [
    .font: NSFont.systemFont(ofSize: 600, weight: .bold),
    .foregroundColor: NSColor.white
])
let size = glyph.size()
glyph.draw(at: NSPoint(x: tile.midX - size.width / 2, y: tile.midY - size.height / 2))

NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: CommandLine.arguments[1])
try rep.representation(using: .png, properties: [:])!.write(to: output)
