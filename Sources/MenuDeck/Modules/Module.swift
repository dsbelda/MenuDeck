import SwiftUI

@MainActor
protocol Module: AnyObject {
    var id: String { get }
    /// Not a plain String: Text(someString) renders the string as-is, so a
    /// String here would silently ship untranslated tile labels.
    var name: LocalizedStringResource { get }
    var sfSymbol: String { get }
    var tintColor: Color { get }
    func makeContent() -> AnyView
}
