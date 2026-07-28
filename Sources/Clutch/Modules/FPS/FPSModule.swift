import SwiftUI

final class FPSModule: Module {
    let id = "fps"
    let name = "FPS"
    let sfSymbol = "gauge.with.dots.needle.67percent"
    let tintColor: Color = .mint

    @MainActor func makeContent() -> AnyView { AnyView(FPSView()) }
}
