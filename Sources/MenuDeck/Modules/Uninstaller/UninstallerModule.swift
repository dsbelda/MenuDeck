import SwiftUI

final class UninstallerModule: Module {
    let id = "uninstaller"
    let name: LocalizedStringResource = "Uninstall"
    let sfSymbol = "trash.square.fill"
    let tintColor: Color = .red

    @MainActor func makeContent() -> AnyView { AnyView(UninstallerView()) }
}
