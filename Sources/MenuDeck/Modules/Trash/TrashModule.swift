import SwiftUI

final class TrashModule: Module {
    let id = "trash"
    let name: LocalizedStringResource = "Trash"
    let sfSymbol = "trash.fill"
    let tintColor: Color = .gray

    @MainActor func makeContent() -> AnyView { AnyView(TrashView()) }
}
