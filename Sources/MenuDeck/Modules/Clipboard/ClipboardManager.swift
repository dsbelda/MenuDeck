import AppKit
import Foundation

struct ClipboardItem: Identifiable {
    let id = UUID()
    let text: String
    let date: Date
}

// MARK: - Manager (singleton – keeps polling the pasteboard after popover close)

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var history: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int
    private let maxItems = 25

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    /// Polling has to outlive the popover — history is useless if it only
    /// accrues while the panel is open — but it must not outlive the *module*.
    /// Turning Clipboard off in Settings used to leave this timer running for
    /// the rest of the session, the one piece of the app that kept working for
    /// nobody.
    func setEnabled(_ enabled: Bool) {
        guard enabled != (timer != nil) else { return }

        if enabled {
            lastChangeCount = NSPasteboard.general.changeCount
            timer = .repeating(every: 1.5, tolerance: 0.3) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
        } else {
            timer?.invalidate()
            timer = nil
        }
    }

    private func poll() {
        let count = NSPasteboard.general.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        guard let text = NSPasteboard.general.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              history.first?.text != text
        else { return }

        history.insert(ClipboardItem(text: text, date: Date()), at: 0)
        if history.count > maxItems { history.removeLast() }
    }

    func copy(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.text, forType: .string)
        lastChangeCount = NSPasteboard.general.changeCount  // ignore our own write
    }

    func delete(_ item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
    }

    func clear() { history.removeAll() }
}
