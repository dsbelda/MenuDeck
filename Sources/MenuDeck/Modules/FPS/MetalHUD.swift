import Foundation

/// Toggles Apple's built-in Metal HUD (FPS, frame time, GPU stats) system-wide.
/// Any Metal-based app reads this preference at launch, so it draws the HUD
/// itself, on top of its own content — no code injection into other processes.
///
/// Reads and writes the preference directly rather than shelling out to
/// `defaults`: both go through CFPreferences and see each other's writes, but
/// `Process` + `waitUntilExit()` blocked the main thread on every read.
enum MetalHUD {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "com.apple.Metal") }
    private static let key = "MetalForceHudEnabled"

    static var isEnabled: Bool {
        get { defaults?.bool(forKey: key) ?? false }
        set { defaults?.set(newValue, forKey: key) }
    }
}
