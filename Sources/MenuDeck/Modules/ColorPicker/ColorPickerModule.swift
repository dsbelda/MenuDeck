import SwiftUI

final class ColorPickerModule: Module {
    let id = "color-picker"
    let name: LocalizedStringResource = "Colour"
    let sfSymbol = "eyedropper"
    let tintColor: Color = .purple

    @MainActor func makeContent() -> AnyView { AnyView(ColorPickerView()) }
}
