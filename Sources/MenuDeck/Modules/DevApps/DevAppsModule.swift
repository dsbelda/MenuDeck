import SwiftUI

final class DevAppsModule: Module {
    let id = "dev-apps"
    let name: LocalizedStringResource = "Dev Tools"
    let sfSymbol = "terminal.fill"
    let tintColor: Color = .green

    @MainActor func makeContent() -> AnyView { AnyView(DevAppsView()) }

    /// The Apps / Projects switch stays put while the project list scrolls.
    let providesOwnScrolling = true
}
