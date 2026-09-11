import AppKit
import Carbon.HIToolbox

/// Registers one system-wide hot key per module.
///
/// Carbon's `RegisterEventHotKey` rather than an `NSEvent` global monitor: the
/// monitor route needs Accessibility permission and sees every keystroke the
/// user types anywhere, which is a lot to ask for a menu bar utility. Carbon hot
/// keys need no permission and only fire for the exact combinations registered.
@MainActor
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    /// Called with a module id when its hot key is pressed.
    var onTrigger: ((String) -> Void)?

    @Published private(set) var shortcuts: [String: Shortcut] = [:]

    private var registrations: [String: EventHotKeyRef] = [:]
    private var moduleIDsByHotKeyID: [UInt32: String] = [:]
    private var nextHotKeyID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private static let defaultsKey = "menudeck.shortcuts"
    /// Four-char code identifying our hot keys: 'MDCK'.
    private static let signature: OSType = 0x4D_44_43_4B

    private init() {
        shortcuts = Self.load()
        installEventHandler()
        for (moduleID, shortcut) in shortcuts {
            register(shortcut, for: moduleID)
        }
    }

    // MARK: – Public

    func shortcut(for moduleID: String) -> Shortcut? { shortcuts[moduleID] }

    /// Assigns a shortcut, or clears it when `shortcut` is nil.
    /// Returns false if another module already owns the combination.
    @discardableResult
    func set(_ shortcut: Shortcut?, for moduleID: String) -> Bool {
        if let shortcut,
           let conflicting = shortcuts.first(where: { $0.value == shortcut && $0.key != moduleID }) {
            _ = conflicting
            return false
        }

        unregister(moduleID)
        shortcuts[moduleID] = shortcut

        if let shortcut, !register(shortcut, for: moduleID) {
            // Another app holds it. Don't keep a shortcut we can't honour.
            shortcuts[moduleID] = nil
            save()
            return false
        }

        save()
        return true
    }

    func moduleOwning(_ shortcut: Shortcut, excluding moduleID: String) -> String? {
        shortcuts.first { $0.value == shortcut && $0.key != moduleID }?.key
    }

    // MARK: – Carbon registration

    @discardableResult
    private func register(_ shortcut: Shortcut, for moduleID: String) -> Bool {
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: nextHotKeyID)
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else { return false }

        registrations[moduleID] = ref
        moduleIDsByHotKeyID[nextHotKeyID] = moduleID
        nextHotKeyID += 1
        return true
    }

    private func unregister(_ moduleID: String) {
        guard let ref = registrations.removeValue(forKey: moduleID) else { return }
        UnregisterEventHotKey(ref)
        moduleIDsByHotKeyID = moduleIDsByHotKeyID.filter { $0.value != moduleID }
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetEventDispatcherTarget(),
            hotKeyEventHandler,
            1,
            &spec,
            nil,
            &eventHandler
        )
    }

    fileprivate func handle(hotKeyID: UInt32) {
        guard let moduleID = moduleIDsByHotKeyID[hotKeyID] else { return }
        onTrigger?(moduleID)
    }

    // MARK: – Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(shortcuts) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }

    private static func load() -> [String: Shortcut] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Shortcut].self, from: data)
        else { return [:] }
        return decoded
    }
}

/// C callback: runs on the main thread as part of AppKit's event dispatch, but
/// is not main-actor-annotated, so it hops onto the actor explicitly.
private func hotKeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let id = hotKeyID.id
    Task { @MainActor in HotkeyManager.shared.handle(hotKeyID: id) }
    return noErr
}
