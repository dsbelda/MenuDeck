import Foundation

/// Toggles Apple's built-in Metal HUD (FPS, frame time, GPU stats) system-wide.
/// Any Metal-based app reads this preference at launch, so it draws the HUD
/// itself, on top of its own content — no code injection into other processes.
enum MetalHUD {
    private static let domain = "com.apple.Metal"
    private static let key = "MetalForceHudEnabled"

    static var isEnabled: Bool {
        get { run(["read", domain, key])?.trimmingCharacters(in: .whitespacesAndNewlines) == "1" }
        set { run(["write", domain, key, "-bool", newValue ? "YES" : "NO"]) }
    }

    @discardableResult
    private static func run(_ arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
