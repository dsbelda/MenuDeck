import Foundation

/// The list of modules, and which of them the user has switched on.
///
/// Module instances are created once and held for the app's lifetime so their
/// state survives popover open/close cycles.
@MainActor
enum ModuleRegistry {
    static let all: [any Module] = [
        VolumeControlModule(),
        AudioOutputModule(),
        ThermalModule(),
        BatteryModule(),
        CPUModule(),
        DiskModule(),
        FPSModule(),
        NetworkModule(),
        CaffeineModule(),
        ScreenshotModule(),
        ClipboardModule(),
        ColorPickerModule(),
        BrewModule(),
        PortsModule(),
        ShortcutsModule(),
        BluetoothModule(),
        TrashModule(),
        FinderTweaksModule(),
    ]

    /// Stores what the user turned *off*, not what they left on, so a module
    /// added in a later version shows up instead of staying invisible until
    /// they go looking for it.
    static let hiddenIDsKey = "menudeck.hiddenModuleIds"

    static var hiddenIDs: Set<String> {
        let raw = UserDefaults.standard.string(forKey: hiddenIDsKey) ?? ""
        return Set(raw.split(separator: ",").map(String.init))
    }

    static var visible: [any Module] {
        let hidden = hiddenIDs
        return all.filter { !hidden.contains($0.id) }
    }

    /// Pushes the on/off state into every module that keeps work running in the
    /// background. Called at launch and whenever a switch is flipped — without
    /// it a module turned off in Settings would keep its timers alive for the
    /// rest of the session.
    static func syncEnabledState() {
        let hidden = hiddenIDs
        for module in all {
            module.setEnabled(!hidden.contains(module.id))
        }
    }
}
