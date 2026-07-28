import SwiftUI

final class VolumeControlModule: Module {
    let id = "volume-control"
    let name = "Volume"
    let sfSymbol = "speaker.wave.2.fill"
    let tintColor: Color = .blue

    @MainActor
    func makeContent() -> AnyView {
        AnyView(VolumeControlView())
    }
}
