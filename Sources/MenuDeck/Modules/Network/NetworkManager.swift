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

    private var throughputTimer: Timer?
    private var wirelessTimer: Timer?
    private var lastBytes: (in: UInt64, out: UInt64)?
    private var lastSampleDate: Date?

    /// Created once. Rebuilding the store on every lookup was two of the three
    /// expensive system calls this class made per second.
    private lazy var store = SCDynamicStoreCreate(nil, "MenuDeck" as CFString, nil, nil)

    func start() {
        sample()
        refreshWireless()

        throughputTimer = .repeating(every: 1, tolerance: 0.2) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        // SSID and RSSI go through CoreWLAN's IPC and barely change. Polling
        // them at 1 Hz alongside throughput was most of this module's cost.
        wirelessTimer = .repeating(every: 5, tolerance: 1) { [weak self] _ in
            Task { @MainActor in self?.refreshWireless() }
        }
    }

    func stop() {
        throughputTimer?.invalidate(); throughputTimer = nil
        wirelessTimer?.invalidate();   wirelessTimer = nil
    }

    // MARK: – Throughput and address

    private func sample() {
        guard let ifName = primaryInterfaceName(),
              let stats = Self.interfaceStats(for: ifName)
        else {
            downKBps = 0; upKBps = 0
            localIP = nil
            lastBytes = nil; lastSampleDate = nil
            return
        }

        localIP = stats.ip

        let now = Date()
        if let last = lastBytes, let lastDate = lastSampleDate {
            let dt = now.timeIntervalSince(lastDate)
            if dt > 0 {
                downKBps = Double(stats.counters.in &- last.in) / 1024 / dt
                upKBps   = Double(stats.counters.out &- last.out) / 1024 / dt
            }
        }
        lastBytes = stats.counters
        lastSampleDate = now
    }

    // MARK: – Wi-Fi

    private func refreshWireless() {
        guard let ifName = primaryInterfaceName(),
              let wifi = CWWiFiClient.shared().interface(),
              wifi.interfaceName == ifName
        else {
            ssid = nil; isWiFi = false; signalBars = 0
            return
        }

        // rssiValue() still reports signal strength even when the SSID string
        // is withheld by the system (e.g. Location Services not granted),
        // so use it — not the SSID — to detect an active Wi-Fi link.
        let rssi = wifi.rssiValue()
        isWiFi = rssi != 0
        ssid = isWiFi ? wifi.ssid() : nil
        signalBars = isWiFi ? Self.bars(forRSSI: rssi) : 0
    }

    // MARK: – System lookups

    private func primaryInterfaceName() -> String? {
        guard let store,
              let global = SCDynamicStoreCopyValue(store, "State:/Network/Global/IPv4" as CFString) as? [String: Any],
              let name = global["PrimaryInterface"] as? String
        else { return nil }
        return name
    }

    /// One getifaddrs walk for both the address (AF_INET) and the byte counters
    /// (AF_LINK). These used to be two independent walks per tick.
    private static func interfaceStats(
        for interfaceName: String
    ) -> (ip: String?, counters: (in: UInt64, out: UInt64))? {
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0 else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ip: String?
        var counters: (in: UInt64, out: UInt64)?

        var ptr = ifaddrPtr
        while let p = ptr {
            let interface = p.pointee
            ptr = interface.ifa_next

            guard String(cString: interface.ifa_name) == interfaceName,
                  let addr = interface.ifa_addr
            else { continue }

            switch Int32(addr.pointee.sa_family) {
            case AF_INET where ip == nil:
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                            &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
                ip = host.withUnsafeBufferPointer { String(cString: $0.baseAddress!) }

            case AF_LINK where counters == nil:
                guard let dataPtr = interface.ifa_data else { continue }
                let data = dataPtr.withMemoryRebound(to: if_data.self, capacity: 1) { $0.pointee }
                counters = (UInt64(data.ifi_ibytes), UInt64(data.ifi_obytes))

            default:
                continue
            }
        }

        guard let counters else { return nil }
        return (ip, counters)
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
