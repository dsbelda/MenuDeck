import AppKit
import Carbon.HIToolbox
import SwiftUI

/// A compact field that records one global shortcut.
///
/// Click to arm, then press a combination. ⎋ cancels, ⌫ clears.
struct ShortcutRecorder: View {
    let moduleID: String
    var isEnabled: Bool = true

    @ObservedObject private var hotkeys = HotkeyManager.shared
    @State private var isRecording = false
    @State private var isHovered = false
    @State private var monitor: Any?
    @State private var rejected = false

    private var shortcut: Shortcut? { hotkeys.shortcut(for: moduleID) }

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(foreground)
                .lineLimit(1)
                .frame(minWidth: 50)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isRecording ? 1 : 0.5)
                )
        }
        .buttonStyle(DeckPressStyle(scale: 0.95))
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .help(helpText)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isRecording)
        // A recorder left armed would keep swallowing keystrokes after the
        // popover closes.
        .whileShown(stop: stopRecording)
        .onChange(of: isEnabled) { _, enabled in
            if !enabled { stopRecording() }
        }
    }

    // MARK: – Appearance

    private var label: String {
        if isRecording { return rejected ? "⌘⌥⌃…" : "…" }
        return shortcut?.displayString ?? "＋"
    }

    private var foreground: Color {
        if isRecording { return rejected ? .orange : .accentColor }
        return shortcut == nil ? (isHovered ? .primary : .secondary) : .primary
    }

    private var background: Color {
        if isRecording {
            return (rejected ? Color.orange : Color.accentColor).opacity(0.14)
        }
        return Color.primary.opacity(isHovered ? 0.10 : 0.055)
    }

    private var borderColor: Color {
        if isRecording {
            return (rejected ? Color.orange : Color.accentColor).opacity(0.55)
        }
        return Color.primary.opacity(isHovered ? 0.16 : 0.09)
    }

    private var helpText: String {
        if isRecording {
            return String(localized: "Press a combination · esc to cancel")
        }
        return shortcut == nil
            ? String(localized: "Click to record a shortcut")
            : String(localized: "Click to change · delete to clear")
    }

    // MARK: – Recording

    private func startRecording() {
        guard monitor == nil else { return }
        isRecording = true
        rejected = false

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        rejected = false
    }

    private func handle(_ event: NSEvent) {
        switch Int(event.keyCode) {
        case kVK_Escape:
            stopRecording()
            return
        case kVK_Delete, kVK_ForwardDelete:
            hotkeys.set(nil, for: moduleID)
            stopRecording()
            return
        default:
            break
        }

        guard let candidate = Shortcut(event: event) else {
            rejected = true
            return
        }

        guard hotkeys.set(candidate, for: moduleID) else {
            rejected = true
            return
        }
        stopRecording()
    }
}
