import Foundation

/// Toggles the handful of Finder preferences that normally need a `defaults
/// write` in Terminal followed by a relaunch.
@MainActor
final class FinderTweaksManager: ObservableObject {
    enum Tweak: String, CaseIterable, Identifiable {
        case hiddenFiles   = "AppleShowAllFiles"
        case pathBar       = "ShowPathbar"
        case statusBar     = "ShowStatusBar"
        case desktopIcons  = "CreateDesktop"

        var id: String { rawValue }

        var label: LocalizedStringResource {
            switch self {
            case .hiddenFiles:  "Show hidden files"
            case .pathBar:      "Show path bar"
            case .statusBar:    "Show status bar"
            case .desktopIcons: "Show desktop icons"
            }
        }

        var sfSymbol: String {
            switch self {
            case .hiddenFiles:  "eye"
            case .pathBar:      "point.topleft.down.to.point.bottomright.curvepath"
            case .statusBar:    "sidebar.squares.bottom"
            case .desktopIcons: "macwindow.on.rectangle"
            }
        }

        /// Whether the preference defaults to on when the key has never been
        /// written. Finder shows desktop icons out of the box; the rest are off.
        var defaultValue: Bool {
            self == .desktopIcons
        }

        /// Restarting Finder is what makes the change visible. The desktop is
        /// drawn by Finder too, so toggling icons always needs it.
        var needsRelaunch: Bool { true }
    }

    @Published private(set) var values: [Tweak: Bool] = [:]
    @Published private(set) var isApplying = false

    /// Computed, not stored: CFString is not Sendable, so a stored static on a
    /// @MainActor type could not be read from the nonisolated accessors below.
    private nonisolated static var domain: CFString { "com.apple.finder" as CFString }

    func refresh() {
        var current: [Tweak: Bool] = [:]
        for tweak in Tweak.allCases {
            current[tweak] = Self.read(tweak)
        }
        values = current
    }

    func value(for tweak: Tweak) -> Bool {
        values[tweak] ?? tweak.defaultValue
    }

    func set(_ enabled: Bool, for tweak: Tweak) {
        guard !isApplying else { return }
        values[tweak] = enabled
        Self.write(enabled, tweak)

        isApplying = true
        Task.detached(priority: .userInitiated) {
            // killall rather than a graceful quit: Finder has no scriptable
            // "reload preferences", and it is relaunched by launchd immediately.
            _ = Shell.run("/usr/bin/killall", ["Finder"])
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                self.isApplying = false
                self.refresh()
            }
        }
    }

    // MARK: – Preferences

    /// CFPreferences rather than shelling out to `defaults`: this is the same
    /// API `defaults` itself calls, minus a subprocess and output parsing.
    private nonisolated static func read(_ tweak: Tweak) -> Bool {
        guard let value = CFPreferencesCopyAppValue(tweak.rawValue as CFString, domain)
        else { return tweak.defaultValue }
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? tweak.defaultValue
    }

    private nonisolated static func write(_ enabled: Bool, _ tweak: Tweak) {
        CFPreferencesSetAppValue(
            tweak.rawValue as CFString,
            enabled as CFBoolean,
            domain
        )
        CFPreferencesAppSynchronize(domain)
    }
}
