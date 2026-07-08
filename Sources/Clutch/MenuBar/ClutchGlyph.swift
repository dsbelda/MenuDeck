import AppKit
import SwiftUI

/// Clutch's brand mark: three parallel diagonal bars evoking a grip texture.
/// Drawn from scratch (rather than an SF Symbol) so it renders identically as
/// an `NSImage` template in the menu bar and as a SwiftUI view in the popover.
enum ClutchGlyph {
    /// Draws the mark centered in `rect` into the current graphics context.
    static func draw(in rect: CGRect, color: NSColor) {
        let contentSize = min(rect.width, rect.height) * 0.76
        let barLength = contentSize * 0.92
        let barThickness = contentSize * 0.20
        let spacing = contentSize * 0.34
        let center = CGPoint(x: rect.midX, y: rect.midY)

        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: 45)
        transform.concat()

        color.setFill()
        for i in -1...1 {
            let y = CGFloat(i) * spacing
            let barRect = CGRect(x: -barLength / 2, y: y - barThickness / 2,
                                  width: barLength, height: barThickness)
            NSBezierPath(roundedRect: barRect, xRadius: barThickness / 2, yRadius: barThickness / 2).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    /// A menu bar–ready template image (auto-tints for light/dark menu bars).
    static func statusBarImage(pointSize: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            draw(in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// SwiftUI wrapper for use in the popover header.
struct ClutchGlyphView: View {
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let nsColor = NSColor(color)
            context.withCGContext { cg in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
                ClutchGlyph.draw(in: rect, color: nsColor)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}
