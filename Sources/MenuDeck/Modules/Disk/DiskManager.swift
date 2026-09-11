import Foundation

@MainActor
final class DiskManager: ObservableObject {
    struct Volume: Identifiable, Equatable, Sendable {
        let id: String          // mount path
        let name: String
        let total: Int64
        let free: Int64
        var used: Int64 { max(0, total - free) }
        var usedFraction: Double { total > 0 ? Double(used) / Double(total) : 0 }
    }

    @Published private(set) var volumes: [Volume] = []

    private var timer: Timer?

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
            await MainActor.run { self.volumes = scanned }
        }
    }

    private nonisolated static func scan() -> [Volume] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeIsBrowsableKey,
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

            // ForImportantUsage is what Finder reports as "available": it counts
            // purgeable space the system would reclaim under pressure, so it is
            // usually larger than volumeAvailableCapacity.
            let free = values.volumeAvailableCapacityForImportantUsage ?? 0

            return Volume(
                id: url.path,
                name: values.volumeName ?? url.lastPathComponent,
                total: Int64(total),
                free: free
            )
        }
        .sorted { $0.total > $1.total }
    }

    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
