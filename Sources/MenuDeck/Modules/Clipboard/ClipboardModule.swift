import SwiftUI

final class ClipboardModule: Module {
    let id = "clipboard"
    let name = "Portapapeles"
    let sfSymbol = "doc.on.clipboard"
    let tintColor: Color = .pink

    @MainActor func makeContent() -> AnyView { AnyView(ClipboardView()) }
}
