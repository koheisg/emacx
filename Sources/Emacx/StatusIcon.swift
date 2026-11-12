import AppKit

enum StatusIcon {
    /// Menu bar icon: a filled circle (Emacs motif) with a knocked-out ⌘ (Mac motif).
    static func make(size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let circle = rect.insetBy(dx: size * 0.03, dy: size * 0.03)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: circle).fill()

            context.setBlendMode(.destinationOut)
            let glyph = NSAttributedString(string: "⌘", attributes: [
                .font: NSFont.systemFont(ofSize: size * 0.72, weight: .bold),
                .foregroundColor: NSColor.black
            ])
            let glyphSize = glyph.size()
            glyph.draw(at: NSPoint(x: rect.midX - glyphSize.width / 2,
                                   y: rect.midY - glyphSize.height / 2))
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Emacx"
        return image
    }
}
