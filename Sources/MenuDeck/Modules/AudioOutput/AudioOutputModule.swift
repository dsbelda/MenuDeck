import SwiftUI

final class AudioOutputModule: Module {
    let id = "audio-output"
    let name: LocalizedStringResource = "Output"
    let sfSymbol = "airplayaudio"
    let tintColor: Color = .blue

    @MainActor func makeContent() -> AnyView { AnyView(AudioOutputView()) }
}
