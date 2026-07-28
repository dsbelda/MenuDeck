import SwiftUI

final class CPUModule: Module {
    let id = "cpu"
    let name = "CPU / RAM"
    let sfSymbol = "cpu"
    let tintColor: Color = .indigo

    @MainActor func makeContent() -> AnyView { AnyView(CPUView()) }
}
