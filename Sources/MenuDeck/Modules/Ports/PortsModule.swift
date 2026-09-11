import SwiftUI

final class PortsModule: Module {
    let id = "ports"
    let name: LocalizedStringResource = "Ports"
    let sfSymbol = "network.badge.shield.half.filled"
    let tintColor: Color = .indigo

    @MainActor func makeContent() -> AnyView { AnyView(PortsView()) }
}
