import SwiftUI

final class NetworkModule: Module {
    let id = "network"
    let name = "Red"
    let sfSymbol = "wifi"
    let tintColor: Color = .cyan

    @MainActor func makeContent() -> AnyView { AnyView(NetworkView()) }
}
