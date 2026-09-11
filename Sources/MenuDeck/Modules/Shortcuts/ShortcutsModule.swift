import SwiftUI

final class ShortcutsModule: Module {
    let id = "shortcuts"
    let name: LocalizedStringResource = "Shortcuts"
    let sfSymbol = "square.stack.3d.up.fill"
    let tintColor: Color = .purple

    @MainActor func makeContent() -> AnyView { AnyView(ShortcutsView()) }

    @MainActor
    var requirementWarning: LocalizedStringResource? {
        ShortcutsManager.shared.isAvailable ? nil : "Requires the Shortcuts app"
    }
}
