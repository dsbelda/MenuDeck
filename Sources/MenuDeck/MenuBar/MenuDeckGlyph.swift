import AppKit
import SwiftUI

/// MenuDeck's brand mark: a bento of one tall panel beside two stacked tiles —
/// the app's own layout in miniature, a module expanded next to the deck it
/// came from.
///
/// Drawn from scratch rather than composed from an SF Symbol so the exact same
/// geometry renders as an `NSImage` template in the menu bar, as a SwiftUI view
/// in the popover header, and as the 1024pt app icon.
///
/// The layout is vertically symmetric, so these fractions read the same whether
/// the context puts y at the top (SwiftUI) or the bottom (AppKit).
enum MenuDeckGlyph {
    /// The mark laid out in a 1×1 box, as fractions of its content square.
    /// A 0.56-wide panel, a 0.12 gutter, then a 0.32 column of two tiles.
    ///
    /// An earlier pass put two squares over one wide bar; at icon size that
    /// arrangement read unmistakably as two eyes and a mouth.
    private static let unitTiles: [CGRect] = [
        CGRect(x: 0,    y: 0,    width: 0.56, height: 1.00),   // expanded panel
        CGRect(x: 0.68, y: 0.56, width: 0.32, height: 0.44),   // tile
        CGRect(x: 0.68, y: 0,    width: 0.32, height: 0.44),   // tile
    ]

    private static let unitCornerRadius: CGFloat = 0.13

    /// Draws the mark centered in `rect`.
    ///
    /// - Parameter inset: fraction of the square kept as breathing room. The
    ///   menu bar wants the mark close to the full height; the app icon wants
    ///   the generous margin Apple's grid expects.
    static func draw(in rect: CGRect, color: NSColor, inset: CGFloat = 0.06) {
        let side = min(rect.width, rect.height) * (1 - inset * 2)
        let origin = CGPoint(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2
        )
        let radius = unitCornerRadius * side

        color.setFill()
        for tile in unitTiles {
            let scaled = CGRect(
                x: origin.x + tile.minX * side,
                y: origin.y + tile.minY * side,
                width:  tile.width  * side,
                height: tile.height * side
            )
            NSBezierPath(roundedRect: scaled, xRadius: radius, yRadius: radius).fill()
        }
    }

    /// A menu bar–ready template image (auto-tints for light/dark menu bars).
    static func statusBarImage(pointSize: CGFloat = 17) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize), flipped: false) { rect in
            draw(in: rect, color: .black, inset: 0.04)
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// SwiftUI wrapper for use in the popover header.
struct MenuDeckGlyphView: View {
    var color: Color = .white

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let nsColor = NSColor(color)
            context.withCGContext { cg in
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: false)
                MenuDeckGlyph.draw(in: rect, color: nsColor, inset: 0)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}
