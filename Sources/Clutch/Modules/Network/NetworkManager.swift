import Darwin
import Foundation
import SystemConfiguration
import CoreWLAN

@MainActor
final class NetworkManager: ObservableObject {
    @Published var downKBps: Double = 0
    @Published var upKBps: Double = 0
    @Published var localIP: String? = nil
    @Published var ssid: String? = nil
    @Published var isWiFi: Bool = false
    @Published var signalBars: Int = 0   // 0...3, only meaningful when isWiFi

    private var timer: Timer?
    private var lastBytes: (in: UInt64, out: UInt64)?
    private var lastSampleDate: Date?

    func start() {
        refreshStaticInfo()
        sampleThroughput()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sampleThroughput()
                self?.refreshStaticInfo()
            }
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: – Static info (IP, Wi-Fi)

    private func refreshStaticInfo() {
        guard let ifName = Self.primaryInterfaceName() else {
            localIP = nil; ssid = nil; isWiFi = false; signalBars = 0
            return
        }
        localIP = Self.ipv4Address(for: ifName)

        // rssiValue() still reports signal strength even when the SSID string
        // is withheld by the system (e.g. Location Services not granted),
        // so use it — not the SSID — to detect an active Wi-Fi link.
        if let wifi = CWWiFiClient.shared().interface(), wifi.interfaceName == ifName {
            let rssi = wifi.rssiValue()
            isWiFi = rssi != 0
            ssid = isWiFi ? wifi.ssid() : nil
            signalBars = isWiFi ? Self.bars(forRSSI: rssi) : 0
        } else {
            ssid = nil
            isWiFi = false
            signalBars = 0
        }
    }

    // MARK: – Throughput

    private func sampleThroughput() {
        guard let ifName = Self.primaryInterfaceName(),
              let counters = Self.byteCounters(for: ifName)
        else {
            downKBps = 0; upKBps = 0
            lastBytes = nil; lastSampleDate = nil
            return
        }

        let now = Date()
        if let last = lastBytes, let lastDate = lastSampleDate {
            let dt = now.timeIntervalSince(lastDate)
            if dt > 0 {
                downKBps = Double(counters.in &- last.in) / 1024 / dt
                upKBps   = Double(counters.out &- last.out) / 1024 / dt
            }
        }
        lastBytes = counters
        lastSampleDate = now
    }

    // MARK: – System lookups

    private static func primaryInterfaceName() -> String? {
        guard let store = SCDynamicStoreCreate(nil, "Clutch" as CFString, nil, nil),
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let name = global["PrimaryInterface"] as? String
        else { return nil }
        return name
    }

    private static func ipv4Address(for interfaceName: String) -> String? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let interface = p.pointee
            ptr = interface.ifa_next
            guard String(cString: interface.ifa_name) == interfaceName,
                  interface.ifa_addr.pointee.sa_family == UInt8(AF_INET)
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                        &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            return host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }
        }
        return nil
    }

    private static func byteCounters(for interfaceName: String) -> (in: UInt64, out: UInt64)? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            let interface = p.pointee
            ptr = interface.ifa_next
            guard String(cString: interface.ifa_name) == interfaceName,
                  interface.ifa_addr.pointee.sa_family == UInt8(AF_LINK),
                  let dataPtr = interface.ifa_data
            else { continue }

            let data = dataPtr.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
            return (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))
        }
        return nil
    }

    private static func bars(forRSSI rssi: Int) -> Int {
        switch rssi {
        case ..<(-80): return 1
        case -80..<(-60): return 2
        case -60..<0: return 3
        default: return 0
        }
    }
}
