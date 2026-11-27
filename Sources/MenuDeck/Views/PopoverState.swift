import SwiftUI

/// Which module the popover is showing, and whether it is on screen at all.
///
/// Shared rather than `@State` inside the view because a global hot key has to
/// be able to say "open on the Battery module" from `MenuBarController`, before
/// the popover is even on screen.
@MainActor
final class PopoverState: ObservableObject {
    static let shared = PopoverState()

    @Published var expandedID: String?
    @Published var screen: Screen = .main
    /// Driven by the popover's delegate, so it is right however it was opened
    /// or dismissed.
    @Published var isShown = false

    enum Screen { case main, settings }

    private init() {}
}

// MARK: – Running only while on screen

extension View {
    /// Runs `start` when the view comes on screen and `stop` when it leaves.
    ///
    /// This is what `onAppear`/`onDisappear` look like they do and do not:
    /// closing an NSPopover orders its window out but leaves the SwiftUI tree
    /// installed, so neither fires. A module wired to them kept its timer — and
    /// every animation that timer fed — running for as long as the app did,
    /// which measured at 13–17% CPU with the popover shut. It also never
    /// refreshed on reopening, so the panel came back showing stale data.
    func whileShown(
        _ start: @escaping @MainActor () -> Void = {},
        stop: @escaping @MainActor () -> Void = {}
    ) -> some View {
        modifier(WhileShown(start: start, stop: stop))
    }
}

private struct WhileShown: ViewModifier {
    let start: @MainActor () -> Void
    let stop: @MainActor () -> Void

    @ObservedObject private var popover = PopoverState.shared
    @State private var isRunning = false

    func body(content: Content) -> some View {
        content
            .onAppear { sync(popover.isShown) }
            // Unconditional: every `stop` in the app is idempotent, and this is
            // the one path that must never be skipped.
            .onDisappear { isRunning = false; stop() }
            .onChange(of: popover.isShown) { _, shown in sync(shown) }
    }

    private func sync(_ shouldRun: Bool) {
        guard shouldRun != isRunning else { return }
        isRunning = shouldRun
        shouldRun ? start() : stop()
    }
}
