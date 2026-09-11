import SwiftUI

final class UninstallerModule: Module {
    let id = "uninstaller"
    let name: LocalizedStringResource = "Uninstall"
    let sfSymbol = "trash.square.fill"
    let tintColor: Color = .red

    @MainActor func makeContent() -> AnyView { AnyView(UninstallerView()) }

    /// The filter field and the confirm bar have to stay put while sixty-odd
    /// apps scroll between them.
    let providesOwnScrolling = true
}
