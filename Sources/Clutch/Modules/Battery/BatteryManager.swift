import IOKit
import SwiftUI

@MainActor
final class BatteryManager: ObservableObject {
    @Published var level: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var minutesRemaining: Int? = nil   // to empty or to full
    @Published var cycleCount: Int? = nil
    @Published var healthPercent: Int? = nil
    @Published var rawMaxCapacity: Int? = nil
    @Published var designCapacity: Int? = nil

    private var timer: Timer?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: – Refresh (AppleSmartBattery only — avoids IOPowerSources SPM issues)

    private func refresh() {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != MACH_PORT_NULL else { return }
        defer { IOObjectRelease(svc) }

        func get<T>(_ key: String) -> T? {
            (IORegistryEntryCreateCFProperty(svc, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue()) as? T
        }

        // On Apple Silicon, CurrentCapacity and MaxCapacity are both in percent (0-100).
        // AppleRawMaxCapacity is in mAh — do NOT use it to compute the percentage.
        let current: Int = get("CurrentCapacity") ?? 0
        let maxC: Int    = get("MaxCapacity") ?? 100
        level = maxC > 0 ? max(0, min(100, current * 100 / maxC)) : 0

        // Charging / plugged in
        isCharging  = get("IsCharging") ?? false
        isPluggedIn = get("ExternalConnected") ?? get("ExternalChargeCapable") ?? false

        // Time remaining (0xFFFF = calculating or N/A)
        let t: Int = get("TimeRemaining") ?? 65535
        minutesRemaining = (t > 0 && t < 65535) ? t : nil

        // Health = AppleRawMaxCapacity / DesignCapacity
        let rawMax: Int = get("AppleRawMaxCapacity") ?? get("MaxCapacity") ?? 0
        let design: Int = get("DesignCapacity") ?? 0
        rawMaxCapacity = rawMax > 0 ? rawMax : nil
        designCapacity = design > 0 ? design : nil
        if rawMax > 0, design > 0 {
            healthPercent = min(100, Int(Double(rawMax) / Double(design) * 100))
        }

        cycleCount = get("CycleCount")
    }

    // MARK: – Computed display helpers

    var batteryIcon: String {
        if isPluggedIn && isCharging { return "battery.100percent.bolt" }
        if isPluggedIn               { return "battery.100percent" }
        switch level {
        case 0..<15:  return "battery.0percent"
        case 15..<40: return "battery.25percent"
        case 40..<65: return "battery.50percent"
        case 65..<90: return "battery.75percent"
        default:      return "battery.100percent"
        }
    }

    var levelColor: Color {
        if isPluggedIn || isCharging { return .green }
        switch level {
        case 0..<15:  return .red
        case 15..<30: return .orange
        case 30..<50: return .yellow
        default:      return .green
        }
    }

    var timeString: String? {
        guard let m = minutesRemaining else { return nil }
        let h = m / 60; let min = m % 60
        return h > 0 ? "\(h) h \(min) min" : "\(min) min"
    }
}
