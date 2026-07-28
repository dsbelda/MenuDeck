import SwiftUI

final class CaffeineModule: Module {
    let id = "caffeine"
    let name: LocalizedStringResource = "Awake"
    let sfSymbol = "cup.and.saucer.fill"
    let tintColor: Color = .brown

    @MainActor func makeContent() -> AnyView { AnyView(CaffeineView()) }
}
