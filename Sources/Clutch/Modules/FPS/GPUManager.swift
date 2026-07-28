import IOKit
import Foundation

@MainActor
final class GPUManager: ObservableObject {
    @Published var utilizationPercent: Int? = nil
    @Published var hudEnabled: Bool = false {
        didSet {
            guard hudEnabled != oldValue else { return }
            MetalHUD.isEnabled = hudEnabled
        }
    }

    private var timer: Timer?

    func start() {
        hudEnabled = MetalHUD.isEnabled
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func refresh() {
        utilizationPercent = Self.readGPUUtilization()
    }

    // MARK: – IOAccelerator performance statistics (Apple Silicon GPU)

    private static func readGPUUtilization() -> Int? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer {
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            var propsUnmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &propsUnmanaged, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let props = propsUnmanaged?.takeRetainedValue() as? [String: Any],
                  let stats = props["PerformanceStatistics"] as? [String: Any],
                  let utilization = stats["Device Utilization %"] as? Int
            else { continue }
            return utilization
        }
        return nil
    }
}
