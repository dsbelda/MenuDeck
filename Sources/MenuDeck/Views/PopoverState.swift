import SwiftUI

/// Which module the popover is showing.
///
/// Shared rather than `@State` inside the view because a global hot key has to
/// be able to say "open on the Battery module" from `MenuBarController`, before
/// the popover is even on screen.
@MainActor
final class PopoverState: ObservableObject {
    static let shared = PopoverState()

    @Published var expandedID: String?
    @Published var screen: Screen = .main

    enum Screen { case main, settings }

    private init() {}
}
