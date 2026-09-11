import AppKit
import Foundation

@MainActor
final class TrashManager: ObservableObject {
    enum Access: Equatable {
        case unknown
        /// ~/.Trash is readable.
        case granted
        /// TCC refused the directory listing — the app needs Full Disk Access.
        case denied
    }

    struct Contents: Equatable, Sendable {
        var itemCount: Int
        var byteSize: Int64
    }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var contents = Contents(itemCount: 0, byteSize: 0)
    @Published private(set) var isScanning = false
    @Published private(set) var isEmptying = false

    private nonisolated static var trashURL: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash")
    }

    func refresh() {
        guard !isScanning else { return }
        isScanning = true

        Task.detached(priority: .utility) {
            let scanned = Self.scan()
            await MainActor.run {
                switch scanned {
                case .success(let contents):
                    self.access = .granted
                    self.contents = contents
                case .failure:
                    self.access = .denied
                }
                self.isScanning = false
            }
        }
    }

    func empty() {
        guard access == .granted, contents.itemCount > 0, !isEmptying else { return }
        isEmptying = true

        Task.detached(priority: .userInitiated) {
            Self.removeAll()
            await MainActor.run {
                self.isEmptying = false
                self.refresh()
            }
        }
    }

    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"
        )!)
    }

    func openInFinder() {
        NSWorkspace.shared.open(Self.trashURL)
    }

    // MARK: – Filesystem

    /// Returns failure when the directory cannot be listed at all, which on a
    /// modern macOS means TCC blocked it rather than that the folder is absent —
    /// ~/.Trash is protected even though it lives in the user's own home.
    private nonisolated static func scan() -> Result<Contents, Error> {
        let manager = FileManager.default
        do {
            let entries = try manager.contentsOfDirectory(
                at: trashURL,
                includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .isDirectoryKey],
                options: []
            )
            let total = entries.reduce(into: Int64(0)) { $0 += allocatedSize(of: $1) }
            return .success(Contents(itemCount: entries.count, byteSize: total))
        } catch {
            return .failure(error)
        }
    }

    private nonisolated static func removeAll() {
        let manager = FileManager.default
        guard let entries = try? manager.contentsOfDirectory(
            at: trashURL, includingPropertiesForKeys: nil
        ) else { return }

        for entry in entries {
            // Best effort: a file locked by a running app stays put rather than
            // aborting the whole sweep.
            try? manager.removeItem(at: entry)
        }
    }

    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
