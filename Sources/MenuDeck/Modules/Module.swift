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

    /// Non-nil when something the module depends on is missing from the system —
    /// shown next to its switch in Settings so turning it on doesn't just hand
    /// the user an empty panel with no explanation.
    var requirementWarning: LocalizedStringResource? { get }

    /// Told when the user switches the module on or off. Only modules that keep
    /// working while the popover is closed need to act on this.
    func setEnabled(_ enabled: Bool)
}

extension Module {
    /// Most modules only need frameworks that ship with macOS.
    var requirementWarning: LocalizedStringResource? { nil }

    /// Most modules start and stop with their view's onAppear/onDisappear, so
    /// being switched off costs them nothing and there is nothing to do here.
    func setEnabled(_ enabled: Bool) {}
}
