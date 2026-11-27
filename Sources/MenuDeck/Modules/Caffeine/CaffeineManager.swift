import Foundation
import IOKit.pwr_mgt

// MARK: - Manager (singleton – the sleep assertion must survive popover close)

@MainActor
final class CaffeineManager: ObservableObject {
    static let shared = CaffeineManager()

    @Published var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else { return }
            isActive ? activate() : deactivate()
        }
    }
    /// When a timed session ends. Nil while idle or running indefinitely.
    @Published private(set) var endDate: Date?
    @Published var selectedDurationIndex: Int = durations.count - 1  // "Indefinido" by default

    static let durations: [(label: LocalizedStringResource, seconds: TimeInterval?)] = [
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("1 hour", 60 * 60),
        ("2 hours", 2 * 60 * 60),
        ("Indefinite", nil),
    ]

    private var assertionID: IOPMAssertionID = 0
    private var expiryTimer: Timer?

    private init() {}

    private func activate() {
        var id: IOPMAssertionID = 0
        // The display assertion keeps the screen on *and* implies the system
        // one, which PreventUserIdleSystemSleep alone does not: with that type
        // the Mac stays up but the display still dims and locks.
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MenuDeck is keeping the Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { isActive = false; return }
        assertionID = id

        guard let duration = Self.durations[selectedDurationIndex].seconds else { return }
        let end = Date().addingTimeInterval(duration)
        endDate = end

        // One wake-up when the session ends, not one a second for the whole of
        // it: a two-hour session used to tick 7,200 times to count down a
        // number nobody could see with the popover shut. The view draws the
        // countdown from `endDate` on its own, and only while it is on screen.
        let timer = Timer(fire: end, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.isActive = false }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        expiryTimer = timer
    }

    private func deactivate() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        expiryTimer?.invalidate()
        expiryTimer = nil
        endDate = nil
    }
}
