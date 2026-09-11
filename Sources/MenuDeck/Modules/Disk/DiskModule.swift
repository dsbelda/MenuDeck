import SwiftUI

final class DiskModule: Module {
    let id = "disk"
    let name: LocalizedStringResource = "Storage"
    let sfSymbol = "internaldrive"
    let tintColor: Color = .yellow

    @MainActor func makeContent() -> AnyView { AnyView(DiskView()) }
}
