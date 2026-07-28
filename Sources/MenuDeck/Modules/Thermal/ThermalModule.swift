import SwiftUI

final class ThermalModule: Module {
    let id = "thermal"
    let name = "Temperatures"
    let sfSymbol = "thermometer.medium"
    let tintColor: Color = .orange

    @MainActor
    func makeContent() -> AnyView {
        AnyView(ThermalView())
    }
}
