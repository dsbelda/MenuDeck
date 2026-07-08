import AppKit
import Foundation

struct ClipboardItem: Identifiable {
    let id = UUID()
    let text: String
    let date: Date
}

@MainActor
final class ClipboardManager: ObservableObject {
    @Published var history: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private let maxItems = 25

    func start() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

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
