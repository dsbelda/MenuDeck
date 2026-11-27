import IOKit
import IOKit.ps
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
        timer = .repeating(every: 30, tolerance: 5) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: – Refresh

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

        minutesRemaining = Self.estimatedMinutes()

        // Health = AppleRawMaxCapacity / DesignCapacity, both in mAh. Newer
        // systems publish them only inside the BatteryData dictionary, which
        // left health and capacity blank. MaxCapacity is no fallback: it is a
        // percentage.
        let data: [String: Any] = get("BatteryData") ?? [:]
        let rawMax = get("AppleRawMaxCapacity") ?? data["AppleRawMaxCapacity"] as? Int ?? 0
        let design = get("DesignCapacity") ?? data["DesignCapacity"] as? Int ?? 0
        rawMaxCapacity = rawMax > 0 ? rawMax : nil
        designCapacity = design > 0 ? design : nil
        if rawMax > 0, design > 0 {
            healthPercent = min(100, Int(Double(rawMax) / Double(design) * 100))
        }

        cycleCount = get("CycleCount")
    }

    /// powerd's estimate — the figure the system's own battery menu shows.
    ///
    /// Not AppleSmartBattery's TimeRemaining: that is the charge divided by the
    /// current draw at this instant, so a Mac sitting idle reported 79 hours.
    /// powerd averages the draw over recent use.
    private static func estimatedMinutes() -> Int? {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(blob, source)?
                    .takeUnretainedValue() as? [String: Any],
                  info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let charging = info[kIOPSIsChargingKey] as? Bool ?? false
            let key = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            // -1 while the estimate is still being worked out, 0 when it does
            // not apply.
            let minutes = info[key] as? Int ?? -1
            return minutes > 0 ? minutes : nil
        }
        return nil
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
