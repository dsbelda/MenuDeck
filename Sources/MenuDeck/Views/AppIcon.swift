import AppKit
import SwiftUI

/// NSWorkspace hits the disk for each icon, so they are resolved once rather
/// than on every row redraw — in an NSCache, so the system can take them back
/// when memory is tight instead of the app holding sixty-odd images for good.
struct AppIcon: View {
    let path: String
    let size: CGFloat

    @MainActor private static let cache = NSCache<NSString, NSImage>()

    var body: some View {
        Image(nsImage: icon)
            .resizable()
            .frame(width: size, height: size)
    }

    private var icon: NSImage {
        if let cached = Self.cache.object(forKey: path as NSString) { return cached }
        let image = NSWorkspace.shared.icon(forFile: path)
        Self.cache.setObject(image, forKey: path as NSString)
        return image
    }
}
