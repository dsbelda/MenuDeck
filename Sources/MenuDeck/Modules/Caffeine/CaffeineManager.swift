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
    @Published var remainingSeconds: Int? = nil
    @Published var selectedDurationIndex: Int = durations.count - 1  // "Indefinido" by default

    static let durations: [(label: LocalizedStringResource, seconds: TimeInterval?)] = [
        ("15 min", 15 * 60),
        ("30 min", 30 * 60),
        ("1 hour", 60 * 60),
        ("2 hours", 2 * 60 * 60),
        ("Indefinite", nil),
    ]

    private var assertionID: IOPMAssertionID = 0
    private var countdownTimer: Timer?

    private init() {}

    private func activate() {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "MenuDeck is keeping the Mac awake" as CFString,
            &id
        )
        guard result == kIOReturnSuccess else { isActive = false; return }
        assertionID = id

        if let duration = Self.durations[selectedDurationIndex].seconds {
            remainingSeconds = Int(duration)
            countdownTimer = .repeating(every: 1, tolerance: 0.1) { [weak self] _ in
                Task { @MainActor in self?.tickCountdown() }
            }
        } else {
            remainingSeconds = nil
        }
    }

    private func tickCountdown() {
        guard let remaining = remainingSeconds else { return }
        if remaining <= 1 {
            isActive = false
        } else {
            remainingSeconds = remaining - 1
        }
    }

    private func deactivate() {
        if assertionID != 0 {
            IOPMAssertionRelease(assertionID)
            assertionID = 0
        }
        countdownTimer?.invalidate()
        countdownTimer = nil
        remainingSeconds = nil
    }
}
