import AppKit
import Carbon.HIToolbox

/// A recorded global key combination.
///
/// Carbon modifier masks are stored rather than `NSEvent.ModifierFlags` because
/// `RegisterEventHotKey` speaks Carbon, and converting once at record time keeps
/// the conversion out of the hot path.
struct Shortcut: Codable, Equatable, Sendable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    /// Builds a shortcut from a key-down event, or nil if the combination is not
    /// usable as a global hot key.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }

        // Shift alone is not enough: ⇧A would swallow capital letters system
        // wide. Require at least one of ⌘ ⌥ ⌃.
        let hasHardModifier = flags.contains(.command)
            || flags.contains(.option)
            || flags.contains(.control)
        guard hasHardModifier else { return nil }

        self.keyCode = UInt32(event.keyCode)
        self.carbonModifiers = carbon
    }

    // MARK: – Display

    var displayString: String {
        var result = ""
        if carbonModifiers & UInt32(controlKey) != 0 { result += "⌃" }
        if carbonModifiers & UInt32(optionKey)  != 0 { result += "⌥" }
        if carbonModifiers & UInt32(shiftKey)   != 0 { result += "⇧" }
        if carbonModifiers & UInt32(cmdKey)     != 0 { result += "⌘" }
        return result + Self.keyName(for: keyCode)
    }

    /// Named keys first, then whatever the *current* keyboard layout produces
    /// for that physical key — so a French layout shows A where a US one shows Q.
    private static func keyName(for keyCode: UInt32) -> String {
        if let named = namedKeys[Int(keyCode)] { return named }
        return layoutCharacter(for: keyCode) ?? "?"
    }

    private static let namedKeys: [Int: String] = [
        kVK_Return: "↩",       kVK_Tab: "⇥",          kVK_Space: "Space",
        kVK_Delete: "⌫",       kVK_ForwardDelete: "⌦", kVK_Escape: "⎋",
        kVK_LeftArrow: "←",    kVK_RightArrow: "→",   kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",    kVK_Home: "↖",         kVK_End: "↘",
        kVK_PageUp: "⇞",       kVK_PageDown: "⇟",
        kVK_F1: "F1",   kVK_F2: "F2",   kVK_F3: "F3",   kVK_F4: "F4",
        kVK_F5: "F5",   kVK_F6: "F6",   kVK_F7: "F7",   kVK_F8: "F8",
        kVK_F9: "F9",   kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static func layoutCharacter(for keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?
                .takeRetainedValue(),
              let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }

        let data = Unmanaged<CFData>.fromOpaque(raw).takeUnretainedValue() as Data

        return data.withUnsafeBytes { buffer -> String? in
            guard let layout = buffer.baseAddress?
                .assumingMemoryBound(to: UCKeyboardLayout.self)
            else { return nil }

            var deadKeyState: UInt32 = 0
            var length = 0
            var characters = [UniChar](repeating: 0, count: 4)

            let status = UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,                                  // no modifiers: the bare key
                UInt32(LMGetKbdType()),
                UInt32(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
            guard status == noErr, length > 0 else { return nil }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }
}
