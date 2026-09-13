import AppKit
import ServiceManagement

/// Whether macOS starts MenuDeck at login.
///
/// `SMAppService.mainApp` is the modern route — no helper bundle, no LaunchAgent
/// plist to write and keep in sync. The system is the source of truth: the
/// status is read back rather than mirrored into our own preference, so turning
/// the item off in System Settings is respected instead of being undone the next
/// time the app launches.
@MainActor
final class LoginItemManager: ObservableObject {
    static let shared = LoginItemManager()

    @Published private(set) var status: SMAppService.Status = .notRegistered
    @Published private(set) var lastError: String?

    private init() { refresh() }

    /// `notFound` is what an app that has never registered reports, so it counts
    /// as off rather than as a problem.
    var isEnabled: Bool { status == .enabled }

    /// macOS can accept the registration but hold it until the user approves it
    /// in System Settings, in which case nothing happens at login until they do.
    var needsApproval: Bool { status == .requiresApproval }

    /// The registration records the bundle's current path. Launching at login
    /// from a build directory works until that copy is moved or rebuilt, and
    /// then it silently stops — worth saying before it happens.
    var isInApplications: Bool {
        Bundle.main.bundleURL.path.hasPrefix("/Applications/")
    }

    func refresh() {
        status = SMAppService.mainApp.status
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openLoginItemsSettings() {
        NSWorkspace.shared.open(URL(
            string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        )!)
    }
}
