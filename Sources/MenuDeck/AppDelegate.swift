import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBarController = MenuBarController()
    }

    // Process taps and aggregate devices are registered with coreaudiod, not
    // owned by our address space — without this they outlive the app.
    func applicationWillTerminate(_ notification: Notification) {
        CoreAudioManager.shared.shutdown()
    }
}
