import SwiftUI

final class BluetoothModule: Module {
    let id = "bluetooth"
    let name: LocalizedStringResource = "Bluetooth"
    let sfSymbol = "dot.radiowaves.left.and.right"
    let tintColor: Color = .blue

    @MainActor func makeContent() -> AnyView { AnyView(BluetoothView()) }
}
