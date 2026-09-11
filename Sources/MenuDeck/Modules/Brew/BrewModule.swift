import SwiftUI

final class BrewModule: Module {
    let id = "brew"
    let name: LocalizedStringResource = "Brew"
    /// Homebrew's own mark is a beer mug.
    let sfSymbol = "mug.fill"
    let tintColor: Color = .orange

    @MainActor func makeContent() -> AnyView { AnyView(BrewView()) }

    @MainActor
    var requirementWarning: LocalizedStringResource? {
        BrewManager.shared.availability == .missing ? "Requires Homebrew" : nil
    }
}
