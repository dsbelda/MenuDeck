import SwiftUI

final class DiskModule: Module {
    let id = "disk"
    let name: LocalizedStringResource = "Storage"
    let sfSymbol = "internaldrive"
    let tintColor: Color = Color(red: 0.90, green: 0.62, blue: 0.06)

    @MainActor func makeContent() -> AnyView { AnyView(DiskView()) }
}
