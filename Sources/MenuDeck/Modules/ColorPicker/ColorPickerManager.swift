import AppKit
import SwiftUI

@MainActor
final class ColorPickerManager: ObservableObject {
    static let shared = ColorPickerManager()

    struct Swatch: Identifiable, Equatable {
        let id = UUID()
        let red: Double
        let green: Double
        let blue: Double

        var color: Color { Color(red: red, green: green, blue: blue) }

        var hex: String {
            String(
                format: "#%02X%02X%02X",
                Int((red   * 255).rounded()),
                Int((green * 255).rounded()),
                Int((blue  * 255).rounded())
            )
        }

        var rgb: String {
            "rgb(\(Int((red * 255).rounded())), "
            + "\(Int((green * 255).rounded())), "
            + "\(Int((blue * 255).rounded())))"
        }
    }

    private static let storageKey = "menudeck.colorHistory"
    private static let limit = 12

    @Published private(set) var history: [Swatch] = []
    @Published private(set) var isSampling = false

    /// NSColorSampler tears itself down when it deallocates, so a local would
    /// dismiss the loupe the moment `pick()` returned.
    private var sampler: NSColorSampler?

    private init() { history = Self.load() }

    // MARK: – Picking

    func pick() {
        guard !isSampling else { return }
        isSampling = true

        let sampler = NSColorSampler()
        self.sampler = sampler

        sampler.show { [weak self] picked in
            // The handler is not main-actor-annotated and NSColor is not
            // Sendable, so the components are read here and only plain Doubles
            // cross back to the actor.
            let components = picked
                .flatMap { $0.usingColorSpace(.sRGB) }
                .map { ($0.redComponent, $0.greenComponent, $0.blueComponent) }

            Task { @MainActor in
                guard let self else { return }
                self.isSampling = false
                self.sampler = nil
                guard let components else { return }   // user pressed Escape
                self.record(red: components.0, green: components.1, blue: components.2)
            }
        }
    }

    private func record(red: Double, green: Double, blue: Double) {
        let swatch = Swatch(red: red, green: green, blue: blue)
        history.removeAll { $0.hex == swatch.hex }
        history.insert(swatch, at: 0)
        if history.count > Self.limit { history.removeLast(history.count - Self.limit) }
        save()
        copy(swatch)
    }

    // MARK: – Actions

    func copy(_ swatch: Swatch) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(swatch.hex, forType: .string)
    }

    func clear() {
        history.removeAll()
        save()
    }

    // MARK: – Persistence

    private func save() {
        UserDefaults.standard.set(history.map(\.hex), forKey: Self.storageKey)
    }

    private static func load() -> [Swatch] {
        let hexes = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        return hexes.compactMap(swatch(fromHex:))
    }

    private static func swatch(fromHex hex: String) -> Swatch? {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let packed = Int(value, radix: 16) else { return nil }
        return Swatch(
            red:   Double((packed >> 16) & 0xFF) / 255,
            green: Double((packed >> 8)  & 0xFF) / 255,
            blue:  Double(packed         & 0xFF) / 255
        )
    }
}
