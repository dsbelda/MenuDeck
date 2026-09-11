import SwiftUI

final class FinderTweaksModule: Module {
    let id = "finder"
    let name: LocalizedStringResource = "Finder"
    let sfSymbol = "folder.fill"
    let tintColor: Color = .cyan

    @MainActor func makeContent() -> AnyView { AnyView(FinderTweaksView()) }
}
