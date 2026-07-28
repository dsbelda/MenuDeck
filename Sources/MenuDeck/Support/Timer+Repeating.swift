import Foundation

extension Timer {
    /// A repeating timer added to the main run loop in `.common` mode.
    ///
    /// `Timer.scheduledTimer` installs in `.default` mode, which AppKit
    /// suspends while it tracks events — so every live readout in the app
    /// froze whenever a menu was open or a slider was being dragged.
    ///
    /// `tolerance` lets the kernel coalesce wake-ups with other timers, which
    /// is worth having in an app that runs all day in the menu bar.
    static func repeating(
        every interval: TimeInterval,
        tolerance: TimeInterval,
        _ block: @escaping @Sendable (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true, block: block)
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}
