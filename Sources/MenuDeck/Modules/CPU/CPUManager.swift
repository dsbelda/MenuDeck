import Darwin
import Foundation

struct CoreUsage: Identifiable {
    let id: Int
    let percent: Double
}

struct MemoryInfo {
    var totalGB: Double = 0
    var appGB: Double = 0      // active + wired (in use by apps)
    var wiredGB: Double = 0    // non-evictable kernel memory
    var compressedGB: Double = 0
    var freeGB: Double = 0
}

@MainActor
final class CPUManager: ObservableObject {
    @Published var cores: [CoreUsage] = []
    @Published var avgPercent: Double = 0
    @Published var memory = MemoryInfo()

    private var prevTicks: [(user: UInt32, sys: UInt32, idle: UInt32, nice: UInt32)] = []
    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: – Refresh

    private func refresh() {
        refreshCPU()
        refreshMemory()
    }

    private func refreshCPU() {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                   &cpuCount, &infoArray, &infoCount) == KERN_SUCCESS,
              let info = infoArray else { return }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let n = Int(cpuCount)
        if prevTicks.count != n { prevTicks = Array(repeating: (0,0,0,0), count: n) }

        var newCores: [CoreUsage] = []
        var total = 0.0

        for i in 0..<n {
            let base = Int(CPU_STATE_MAX) * i
            let u = UInt32(info[base + Int(CPU_STATE_USER)])
            let s = UInt32(info[base + Int(CPU_STATE_SYSTEM)])
            let d = UInt32(info[base + Int(CPU_STATE_IDLE)])
            let k = UInt32(info[base + Int(CPU_STATE_NICE)])

            let p = prevTicks[i]
            let du = u &- p.user; let ds = s &- p.sys
            let dd = d &- p.idle; let dk = k &- p.nice
            let sum = Double(du + ds + dd + dk)
            let pct = sum > 0 ? Double(du + ds + dk) / sum * 100 : 0

            prevTicks[i] = (u, s, d, k)
            newCores.append(CoreUsage(id: i, percent: pct))
            total += pct
        }

        cores = newCores
        avgPercent = n > 0 ? total / Double(n) : 0
    }

    private func refreshMemory() {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return }

        let page = Double(sysconf(_SC_PAGESIZE))  // thread-safe alternative to vm_kernel_page_size
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let gb: (Double) -> Double = { $0 / 1_073_741_824 }

        let wired      = Double(stats.wire_count) * page
        let active     = Double(stats.active_count) * page
        let compressed = Double(stats.compressor_page_count) * page
        let free       = Double(stats.free_count) * page

        memory = MemoryInfo(
            totalGB:      gb(total),
            appGB:        gb(active + compressed),
            wiredGB:      gb(wired),
            compressedGB: gb(compressed),
            freeGB:       gb(free)
        )
    }
}
