import AppKit
import Foundation

@MainActor
final class DiskManager: ObservableObject {
    struct Volume: Identifiable, Equatable, Sendable {
        let id: String          // mount path
        let url: URL
        let name: String
        let total: Int64
        let free: Int64
        /// A mounted disk image or installer. It is full by construction, so
        /// its usage is shown without the warning colours.
        let isReadOnly: Bool
        /// True for removable drives and mounted disk images (never `/`).
        let isEjectable: Bool
        var used: Int64 { max(0, total - free) }
        var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    @Published private(set) var volumes: [Volume] = []
    @Published private(set) var ejectingIDs: Set<String> = []
    @Published var lastError: String?

    private var timer: Timer?

    var ejectableDiskImages: [Volume] {
        volumes.filter { $0.isEjectable && $0.isReadOnly }
    }

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = .repeating(every: 10, tolerance: 3) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        // mountedVolumeURLs stats every mount, and a stalled network share can
        // block that call for seconds — never on the main thread.
        Task.detached(priority: .utility) {
            let scanned = Self.scan()
            await MainActor.run {
                if scanned != self.volumes { self.volumes = scanned }
            }
        }
    }

    func eject(_ volume: Volume) {
        guard volume.isEjectable, !ejectingIDs.contains(volume.id) else { return }
        lastError = nil
        ejectingIDs.insert(volume.id)
        let url = volume.url
        let id = volume.id
        let name = volume.name

        Task.detached(priority: .userInitiated) {
            var errorMessage: String?
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                errorMessage = String(localized: "Could not eject \(name)")
            }
            let scanned = Self.scan()
            await MainActor.run {
                self.ejectingIDs.remove(id)
                self.volumes = scanned
                if let errorMessage { self.lastError = errorMessage }
            }
        }
    }

    func ejectAllDiskImages() {
        let targets = ejectableDiskImages.filter { !ejectingIDs.contains($0.id) }
        guard !targets.isEmpty else { return }
        lastError = nil
        for v in targets { ejectingIDs.insert(v.id) }

        Task.detached(priority: .userInitiated) {
            var failedNames: [String] = []
            for volume in targets {
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: volume.url)
                } catch {
                    failedNames.append(volume.name)
                }
            }
            let scanned = Self.scan()
            await MainActor.run {
                for v in targets { self.ejectingIDs.remove(v.id) }
                self.volumes = scanned
                if let first = failedNames.first {
                    self.lastError = String(localized: "Could not eject \(first)")
                }
            }
        }
    }

    private nonisolated static func scan() -> [Volume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsBrowsableKey,
            .volumeIsReadOnlyKey,
            .volumeIsEjectableKey,
            .volumeIsRemovableKey,
            .volumeIsRootFileSystemKey,
        ]

        let mounts = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return mounts.compactMap { url -> Volume? in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.volumeIsBrowsable == true,
                  let total = values.volumeTotalCapacity, total > 0
            else { return nil }

            let free = values.volumeAvailableCapacityForImportantUsage ?? 0
            let isRoot = values.volumeIsRootFileSystem == true || url.path == "/"
            let isReadOnly = values.volumeIsReadOnly == true
            let isEjectable = !isRoot && (
                values.volumeIsEjectable == true
                || values.volumeIsRemovable == true
                || isReadOnly
            )

            return Volume(
                id: url.path,
                url: url,
                name: values.volumeName ?? url.lastPathComponent,
                total: Int64(total),
                free: free,
                isReadOnly: isReadOnly,
                isEjectable: isEjectable
            )
        }
        .sorted { lhs, rhs in
            if lhs.isReadOnly != rhs.isReadOnly { return !lhs.isReadOnly }
            return lhs.total > rhs.total
        }
    }

    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB, .useTB]
        f.countStyle = .file
        return f
    }()

    static func format(_ bytes: Int64) -> String {
        formatter.string(fromByteCount: bytes)
    }
}
