import SwiftUI

final class ClipboardModule: Module {
    let id = "clipboard"
    let name: LocalizedStringResource = "Clipboard"
    let sfSymbol = "doc.on.clipboard"
    let tintColor: Color = .pink

    @MainActor func makeContent() -> AnyView { AnyView(ClipboardView()) }

    /// The one module that polls whether or not anyone is looking: clipboard
    /// history has to accrue while the popover is closed.
    @MainActor
    func setEnabled(_ enabled: Bool) {
        ClipboardManager.shared.setEnabled(enabled)
    }
}
