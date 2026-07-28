import SwiftUI

final class ScreenshotModule: Module {
    let id = "screenshot"
    let name = "Capturas"
    let sfSymbol = "camera.viewfinder"
    let tintColor: Color = .teal

    @MainActor
    func makeContent() -> AnyView {
        AnyView(ScreenshotView())
    }
}
