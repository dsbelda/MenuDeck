import Foundation

/// Allocated size of a file, or of everything under a directory.
///
/// `totalFileAllocatedSize` rather than `fileSize`: it counts the blocks the
/// file actually occupies, which is what freeing it gives back.
nonisolated func allocatedSize(of url: URL) -> Int64 {
    let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .isDirectoryKey]
    guard let values = try? url.resourceValues(forKeys: keys) else { return 0 }

    guard values.isDirectory == true else {
        return Int64(values.totalFileAllocatedSize ?? 0)
    }

    guard let walker = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: Array(keys),
        options: []
    ) else { return 0 }

    var total: Int64 = 0
    for case let child as URL in walker {
        let childValues = try? child.resourceValues(forKeys: keys)
        if childValues?.isDirectory != true {
            total += Int64(childValues?.totalFileAllocatedSize ?? 0)
        }
    }
    return total
}

nonisolated func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}
