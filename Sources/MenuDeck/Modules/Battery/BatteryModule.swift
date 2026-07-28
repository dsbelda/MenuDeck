import SwiftUI

final class BatteryModule: Module {
    let id = "battery"
    let name: LocalizedStringResource = "Battery"
    let sfSymbol = "battery.75"
    let tintColor: Color = .green

    @MainActor func makeContent() -> AnyView { AnyView(BatteryView()) }
}
