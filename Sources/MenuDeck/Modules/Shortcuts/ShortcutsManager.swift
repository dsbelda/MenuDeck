import Foundation

@MainActor
final class ShortcutsManager: ObservableObject {
    static let shared = ShortcutsManager()

    struct Item: Identifiable, Equatable, Sendable {
        let name: String
        var id: String { name }
    }

    enum RunState: Equatable {
        case idle
        case running(String)
        case succeeded(String)
        case failed(String, message: String)
    }

    @Published private(set) var items: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var runState: RunState = .idle

    private nonisolated static let tool = "/usr/bin/shortcuts"
    private var loaded = false

    private init() {}

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: Self.tool)
    }

    func loadIfNeeded() {
        guard !loaded else { return }
        reload()
    }

    func reload() {
        guard isAvailable, !isLoading else { return }
        isLoading = true

        Task.detached(priority: .userInitiated) {
            let result = Shell.run(Self.tool, ["list"])
            let names = result.output
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map(Item.init(name:))

            await MainActor.run {
                self.items = names
                self.isLoading = false
                self.loaded = true
            }
        }
    }

    func run(_ item: Item) {
        // One at a time: the CLI happily runs concurrent shortcuts, but a single
        // status line can only describe one of them.
        if case .running = runState { return }
        runState = .running(item.name)

        Task.detached(priority: .userInitiated) {
            // A shortcut can take as long as it likes; nothing here times out,
            // and the popover may well be closed by the time it lands.
            let result = Shell.run(Self.tool, ["run", item.name])
            let message = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

            await MainActor.run {
                self.runState = result.succeeded
                    ? .succeeded(item.name)
                    : .failed(item.name, message: message.isEmpty
                        ? String(localized: "The shortcut reported an error")
                        : message)
                self.clearStateLater()
            }
        }
    }

    private func clearStateLater() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            if case .running = runState { return }
            runState = .idle
        }
    }
}
