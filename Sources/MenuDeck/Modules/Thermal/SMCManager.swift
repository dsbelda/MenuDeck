import IOKit
import Foundation

// MARK: - SMC Structs (must match AppleSMC kernel layout)

private struct SMCVersion {
    var major:    UInt8  = 0
    var minor:    UInt8  = 0
    var build:    UInt8  = 0
    var reserved: UInt8  = 0
    var release:  UInt16 = 0
}

private struct SMCPLimitData {
    var version:   UInt16 = 0
    var length:    UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

private struct SMCKeyInfoData {
    var dataSize:       IOByteCount32 = 0
    var dataType:       UInt32        = 0
    var dataAttributes: UInt8         = 0
}

private struct SMCParamStruct {
    var key:        UInt32         = 0
    var vers:       SMCVersion     = SMCVersion()
    var pLimitData: SMCPLimitData  = SMCPLimitData()
    var keyInfo:    SMCKeyInfoData = SMCKeyInfoData()
    var padding:    UInt16         = 0   // required: brings struct to exactly 80 bytes
    var result:     UInt8          = 0
    var status:     UInt8          = 0
    var data8:      UInt8          = 0
    var data32:     UInt32         = 0
    var bytes: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0)
}

// MARK: - SMC Commands

private enum SMCCommand: UInt8 {
    case readKey        = 5
    case getKeyFromIndex = 8
    case getKeyInfo     = 9
}

// MARK: - Temperature Key Definitions

struct TempKey {
    let key:   String
    let label: String
    let group: Group

    enum Group { case cpu, gpu, system }
}

// Temperature keys for M1 → M5 + Intel. Keys missing on the current chip
// silently return nothing — only valid readings appear in the UI.
let knownTempKeys: [TempKey] = [

    // ── M1 ──────────────────────────────────────────────────────────────
    TempKey(key: "Tp01", label: "CPU P-Core 1",  group: .cpu),
    TempKey(key: "Tp05", label: "CPU P-Core 2",  group: .cpu),
    TempKey(key: "Tp0D", label: "CPU P-Core 3",  group: .cpu),
    TempKey(key: "Tp0H", label: "CPU P-Core 4",  group: .cpu),
    TempKey(key: "Tp0L", label: "CPU P-Core 5",  group: .cpu),
    TempKey(key: "Tp0P", label: "CPU P-Core 6",  group: .cpu),
    TempKey(key: "Tp0X", label: "CPU P-Core 7",  group: .cpu),
    TempKey(key: "Tp0b", label: "CPU P-Core 8",  group: .cpu),
    TempKey(key: "Tp09", label: "CPU E-Core 1",  group: .cpu),
    TempKey(key: "Tp0T", label: "CPU E-Core 2",  group: .cpu),
    TempKey(key: "Tg05", label: "GPU 1",         group: .gpu),
    TempKey(key: "Tg0D", label: "GPU 2",         group: .gpu),
    TempKey(key: "Tg0L", label: "GPU 3",         group: .gpu),
    TempKey(key: "Tg0T", label: "GPU 4",         group: .gpu),
    TempKey(key: "Tm02", label: "Memory 1",      group: .system),
    TempKey(key: "Tm06", label: "Memory 2",      group: .system),

    // ── M2 ──────────────────────────────────────────────────────────────
    TempKey(key: "Tp0f", label: "CPU P-Core 9",  group: .cpu),
    TempKey(key: "Tp0j", label: "CPU P-Core 10", group: .cpu),
    TempKey(key: "Tp1h", label: "CPU E-Core 3",  group: .cpu),
    TempKey(key: "Tp1t", label: "CPU E-Core 4",  group: .cpu),
    TempKey(key: "Tp1p", label: "CPU E-Core 5",  group: .cpu),
    TempKey(key: "Tp1l", label: "CPU E-Core 6",  group: .cpu),
    TempKey(key: "Tg0f", label: "GPU 5",         group: .gpu),
    TempKey(key: "Tg0j", label: "GPU 6",         group: .gpu),

    // ── M3 (CPU P-cores use Tf prefix) ──────────────────────────────────
    TempKey(key: "Te05", label: "CPU E-Core 1",  group: .cpu),
    TempKey(key: "Te0L", label: "CPU E-Core 2",  group: .cpu),
    TempKey(key: "Te0P", label: "CPU E-Core 3",  group: .cpu),
    TempKey(key: "Te0S", label: "CPU E-Core 4",  group: .cpu),
    TempKey(key: "Tf04", label: "CPU P-Core 1",  group: .cpu),
    TempKey(key: "Tf09", label: "CPU P-Core 2",  group: .cpu),
    TempKey(key: "Tf0A", label: "CPU P-Core 3",  group: .cpu),
    TempKey(key: "Tf0B", label: "CPU P-Core 4",  group: .cpu),
    TempKey(key: "Tf0D", label: "CPU P-Core 5",  group: .cpu),
    TempKey(key: "Tf0E", label: "CPU P-Core 6",  group: .cpu),
    TempKey(key: "Tf44", label: "CPU P-Core 7",  group: .cpu),
    TempKey(key: "Tf49", label: "CPU P-Core 8",  group: .cpu),
    TempKey(key: "Tf4A", label: "CPU P-Core 9",  group: .cpu),
    TempKey(key: "Tf4B", label: "CPU P-Core 10", group: .cpu),
    TempKey(key: "Tf4D", label: "CPU P-Core 11", group: .cpu),
    TempKey(key: "Tf4E", label: "CPU P-Core 12", group: .cpu),
    TempKey(key: "Tf14", label: "GPU 1",         group: .gpu),
    TempKey(key: "Tf18", label: "GPU 2",         group: .gpu),
    TempKey(key: "Tf19", label: "GPU 3",         group: .gpu),
    TempKey(key: "Tf1A", label: "GPU 4",         group: .gpu),
    TempKey(key: "Tf24", label: "GPU 5",         group: .gpu),
    TempKey(key: "Tf28", label: "GPU 6",         group: .gpu),
    TempKey(key: "Tf29", label: "GPU 7",         group: .gpu),
    TempKey(key: "Tf2A", label: "GPU 8",         group: .gpu),

    // ── M4 ──────────────────────────────────────────────────────────────
    TempKey(key: "Te09", label: "CPU E-Core 1",  group: .cpu),
    TempKey(key: "Te0H", label: "CPU E-Core 2",  group: .cpu),
    TempKey(key: "Tp0V", label: "CPU P-Core 5",  group: .cpu),
    TempKey(key: "Tp0Y", label: "CPU P-Core 6",  group: .cpu),
    TempKey(key: "Tp0e", label: "CPU P-Core 7",  group: .cpu),
    TempKey(key: "Tg0G", label: "GPU 1",         group: .gpu),
    TempKey(key: "Tg0H", label: "GPU 2",         group: .gpu),
    TempKey(key: "Tg0K", label: "GPU 3",         group: .gpu),
    TempKey(key: "Tg0d", label: "GPU 4",         group: .gpu),
    TempKey(key: "Tg0e", label: "GPU 5",         group: .gpu),
    TempKey(key: "Tg0k", label: "GPU 6",         group: .gpu),
    TempKey(key: "Tg1U", label: "GPU 7",         group: .gpu),
    TempKey(key: "Tg1k", label: "GPU 8",         group: .gpu),
    TempKey(key: "Tm0p", label: "Memory 1",      group: .system),
    TempKey(key: "Tm1p", label: "Memory 2",      group: .system),
    TempKey(key: "Tm2p", label: "Memory 3",      group: .system),

    // ── M5 ──────────────────────────────────────────────────────────────
    TempKey(key: "Tp00", label: "CPU Super 1",   group: .cpu),
    TempKey(key: "Tp04", label: "CPU Super 2",   group: .cpu),
    TempKey(key: "Tp08", label: "CPU Super 3",   group: .cpu),
    TempKey(key: "Tp0C", label: "CPU Super 4",   group: .cpu),
    TempKey(key: "Tp0G", label: "CPU Super 5",   group: .cpu),
    TempKey(key: "Tp0K", label: "CPU Super 6",   group: .cpu),
    TempKey(key: "Tp0O", label: "CPU P-Core 1",  group: .cpu),
    TempKey(key: "Tp0S", label: "CPU P-Core 2",  group: .cpu),
    TempKey(key: "Tp0W", label: "CPU P-Core 3",  group: .cpu),
    TempKey(key: "Tp0a", label: "CPU P-Core 4",  group: .cpu),
    TempKey(key: "Tp0i", label: "CPU P-Core 5",  group: .cpu),
    TempKey(key: "Tp0m", label: "CPU P-Core 6",  group: .cpu),
    TempKey(key: "Tp0q", label: "CPU P-Core 7",  group: .cpu),
    TempKey(key: "Tp0u", label: "CPU P-Core 8",  group: .cpu),
    TempKey(key: "Tp0y", label: "CPU P-Core 9",  group: .cpu),
    TempKey(key: "Tp1E", label: "CPU P-Core 10", group: .cpu),
    TempKey(key: "Tg0U", label: "GPU 1",         group: .gpu),
    TempKey(key: "Tg0X", label: "GPU 2",         group: .gpu),
    TempKey(key: "Tg0g", label: "GPU 3",         group: .gpu),
    TempKey(key: "Tg1Y", label: "GPU 4",         group: .gpu),
    TempKey(key: "Tg1c", label: "GPU 5",         group: .gpu),
    TempKey(key: "Tg1g", label: "GPU 6",         group: .gpu),

    // ── Intel ────────────────────────────────────────────────────────────
    TempKey(key: "TC0D", label: "CPU Die",       group: .cpu),
    TempKey(key: "TC0P", label: "CPU Proximity", group: .cpu),
    TempKey(key: "TCXC", label: "CPU",           group: .cpu),
    TempKey(key: "TG0D", label: "GPU Die",       group: .gpu),

    // ── System (all generations) ─────────────────────────────────────────
    TempKey(key: "TaLP", label: "Airflow L",     group: .system),
    TempKey(key: "TaRF", label: "Airflow R",     group: .system),
    TempKey(key: "Ts0S", label: "System 1",      group: .system),
    TempKey(key: "Ts1S", label: "System 2",      group: .system),
    TempKey(key: "TB0T", label: "Battery",       group: .system),
    TempKey(key: "TB1T", label: "Battery 2",     group: .system),
]

// MARK: - Result

struct TempReading: Identifiable {
    let id:    String  // key
    let label: String
    let value: Double  // Celsius
    let group: TempKey.Group
}

// MARK: - SMC Manager

/// Every read here is a blocking `IOConnectCallStructMethod` round-trip, and
/// `readTemperatures()` can make dozens of them. An actor keeps that work off
/// the main thread — the popover animates while the SMC is being polled — and
/// serializes it, so the single `io_connect_t` is never used concurrently.
actor SMCManager {
    static let shared = SMCManager()

    private var connection: io_connect_t = 0
    private let methodSelector: UInt32 = 2  // kSMCHandleYPCEvent

    private var isOpen: Bool { connection != 0 }
    private var openError: String? = nil
    private var didAttemptOpen = false

    private init() {}

    /// Opened on first use rather than in init: an actor's initializer cannot
    /// call isolated methods, and IOServiceOpen is exactly the kind of blocking
    /// work that should happen on the actor's executor anyway.
    private func ensureOpen() {
        guard !didAttemptOpen else { return }
        didAttemptOpen = true
        open()
    }

    /// Why the SMC is unavailable, or nil if it opened fine.
    func openFailure() -> String? {
        ensureOpen()
        return openError
    }

    deinit {
        if connection != 0 { IOServiceClose(connection) }
    }

    /// Fastest single-key CPU temperature read — used by the dynamic menu bar display.
    func currentCPUTemp() -> Double? {
        ensureOpen()
        guard isOpen else { return nil }
        // Try each chip generation's primary core key in order
        for key in ["Tp00", "Tf04", "Te05", "Tp01", "TC0D"] {
            if let t = readTemperature(key: key), t > 1, t < 130 { return t }
        }
        return nil
    }

    func readTemperatures() -> [TempReading] {
        ensureOpen()
        guard isOpen else { return [] }

        // Fast path: try the static key list first
        let static_ = knownTempKeys.compactMap { def -> TempReading? in
            guard let temp = readTemperature(key: def.key), temp > 1, temp < 130 else { return nil }
            return TempReading(id: def.key, label: def.label, value: temp, group: def.group)
        }
        if !static_.isEmpty { return static_ }

        // Fallback: enumerate ALL SMC keys and pick temperature ones.
        // This handles any chip generation regardless of key names.
        return enumerateTemperatureKeys()
    }

    /// Runs step-by-step diagnostics and returns a human-readable string.
    func runDiagnostics() -> String {
        ensureOpen()
        var lines: [String] = []

        guard isOpen else {
            lines.append("❌ SMC not open: \(openError ?? "unknown")")
            return lines.joined(separator: "\n")
        }
        lines.append("✅ IOServiceOpen OK (conn=\(connection))")
        lines.append("structSize=\(MemoryLayout<SMCParamStruct>.size)b stride=\(MemoryLayout<SMCParamStruct>.stride)b")

        // Probe all method selectors 0-5 to find which one works
        lines.append("--- Selector probe ---")
        for sel: UInt32 in 0...5 {
            var i = SMCParamStruct(); var o = SMCParamStruct()
            i.key = fourCC("#KEY"); i.data8 = SMCCommand.getKeyInfo.rawValue
            let kr = callSMCWithSelector(sel, input: &i, output: &o)
            let hex = String(UInt32(bitPattern: kr), radix: 16, uppercase: false)
            let mark = kr == kIOReturnSuccess ? "✅" : "❌"
            lines.append("\(mark) sel=\(sel): 0x\(hex) result=\(o.result)")
        }

        // 1. Try callSMC for getKeyInfo on a universally-present key "#KEY"
        lines.append("--- sel=\(methodSelector) detail ---")
        var input  = SMCParamStruct()
        var output = SMCParamStruct()
        input.key   = fourCC("#KEY")
        input.data8 = SMCCommand.getKeyInfo.rawValue
        let smcOK = callSMC(input: &input, output: &output)
        let kernHex = String(UInt32(bitPattern: lastKernResult), radix: 16)
        lines.append("callSMC(getKeyInfo #KEY): \(smcOK ? "✅" : "❌ 0x\(kernHex)")")
        lines.append("  output.result=\(output.result) dataSize=\(output.keyInfo.dataSize)")
        let typeBytes = output.keyInfo.dataType
        let typeChars = [UInt8((typeBytes>>24)&0xFF), UInt8((typeBytes>>16)&0xFF),
                         UInt8((typeBytes>>8)&0xFF),  UInt8(typeBytes&0xFF)]
        let typeStr = String(bytes: typeChars.filter { $0 > 0 }, encoding: .ascii) ?? "?"
        lines.append("  dataType='\(typeStr)'")

        // 2. Read #KEY count
        if smcOK && output.result == 0 {
            if let countBytes = rawReadKey("#KEY", size: output.keyInfo.dataSize) {
                let n = countBytes.prefix(4).reduce(UInt32(0)) { $0 << 8 | UInt32($1) }
                lines.append("✅ #KEY count = \(n)")

                if let k0 = keyAtIndex(0) { lines.append("Key[0] = '\(k0)'") }
                if let k1 = keyAtIndex(1) { lines.append("Key[1] = '\(k1)'") }

                // Find first 20 temperature keys via enumeration
                lines.append("--- First T* keys ---")
                var tCount = 0
                for i in 0..<min(n, 2000) {
                    guard tCount < 20, let key = keyAtIndex(i), key.hasPrefix("T") else { continue }
                    var ki = SMCParamStruct(); var ko = SMCParamStruct()
                    ki.key = fourCC(key); ki.data8 = SMCCommand.getKeyInfo.rawValue
                    if callSMC(input: &ki, output: &ko), ko.result == 0 {
                        let tc = ko.keyInfo.dataType
                        let tb = [UInt8((tc>>24)&0xFF),UInt8((tc>>16)&0xFF),UInt8((tc>>8)&0xFF),UInt8(tc&0xFF)]
                        let ts = String(bytes: tb.filter { $0 > 0 }, encoding: .ascii) ?? "?"
                        if let bytes = readKeyBytes(key: key, dataSize: ko.keyInfo.dataSize) {
                            let val = parseTemp(bytes: bytes, typeCode: ko.keyInfo.dataType)
                            let valStr = val.map { String(format:"%.1f°C", $0) } ?? "nil"
                            lines.append("'\(key)' type='\(ts)' val=\(valStr)")
                        } else {
                            lines.append("'\(key)' type='\(ts)' readFail")
                        }
                        tCount += 1
                    }
                }
            } else {
                lines.append("❌ rawReadKey(#KEY) failed")
            }
        }

        // 3. Detailed probe for known M5 temp keys — raw bytes + both endian
        lines.append("--- M5 key raw bytes ---")
        for probe in ["Tp00", "Tp0O", "Tg0U", "TB0T", "Tp01"] {
            var ki = SMCParamStruct(); var ko = SMCParamStruct()
            ki.key = fourCC(probe); ki.data8 = SMCCommand.getKeyInfo.rawValue
            guard callSMC(input: &ki, output: &ko), ko.result == 0 else {
                lines.append("⬜ '\(probe)' not found"); continue
            }
            let tc = ko.keyInfo.dataType
            let tb = [UInt8((tc>>24)&0xFF),UInt8((tc>>16)&0xFF),UInt8((tc>>8)&0xFF),UInt8(tc&0xFF)]
            let ts = String(bytes: tb.filter { $0 > 0 }, encoding: .ascii) ?? "?"
            if let bytes = readKeyBytes(key: probe, dataSize: ko.keyInfo.dataSize) {
                let hex = bytes.map { String(format:"%02X",$0) }.joined(separator:" ")
                lines.append("'\(probe)' type='\(ts)' bytes=[\(hex)]")
                if bytes.count >= 4 {
                    let be = UInt32(bytes[0])<<24 | UInt32(bytes[1])<<16 | UInt32(bytes[2])<<8 | UInt32(bytes[3])
                    let le = UInt32(bytes[3])<<24 | UInt32(bytes[2])<<16 | UInt32(bytes[1])<<8 | UInt32(bytes[0])
                    lines.append("  BE=\(Float(bitPattern: be))  LE=\(Float(bitPattern: le))")
                } else if bytes.count == 2 {
                    let sp = Double(bytes[0]) + Double(bytes[1]) / 256.0
                    lines.append("  sp78=\(sp)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }

    // MARK: – Dynamic enumeration

    private func enumerateTemperatureKeys() -> [TempReading] {
        // "#KEY" holds the total count of SMC keys (type ui32, big-endian)
        guard let countBytes = rawReadKey("#KEY", size: 4), countBytes.count >= 4 else { return [] }
        let count = UInt32(countBytes[0]) << 24 | UInt32(countBytes[1]) << 16
                  | UInt32(countBytes[2]) << 8  | UInt32(countBytes[3])
        guard count > 0 else { return [] }

        var results: [TempReading] = []
        var cpuN = 1, gpuN = 1, sysN = 1

        for i in 0..<count {
            guard let key = keyAtIndex(i) else { continue }
            // Only temperature keys (start with 'T', printable ASCII)
            guard key.hasPrefix("T"), key.count == 4 else { continue }
            guard let temp = readTemperature(key: key), temp > 1, temp < 130 else { continue }

            // Label: prefer static table, otherwise derive from prefix
            if let def = knownTempKeys.first(where: { $0.key == key }) {
                results.append(TempReading(id: key, label: def.label, value: temp, group: def.group))
            } else {
                let group = groupForUnknownKey(key)
                let label: String
                switch group {
                case .cpu:    label = "CPU \(cpuN)"; cpuN += 1
                case .gpu:    label = "GPU \(gpuN)"; gpuN += 1
                case .system: label = "System \(sysN)"; sysN += 1
                }
                results.append(TempReading(id: key, label: label, value: temp, group: group))
            }
        }
        return results
    }

    private func keyAtIndex(_ index: UInt32) -> String? {
        var input  = SMCParamStruct()
        var output = SMCParamStruct()
        input.data8  = SMCCommand.getKeyFromIndex.rawValue
        input.data32 = index
        guard callSMC(input: &input, output: &output), output.result == 0 else { return nil }
        let k = output.key
        let bytes: [UInt8] = [
            UInt8((k >> 24) & 0xFF), UInt8((k >> 16) & 0xFF),
            UInt8((k >> 8)  & 0xFF), UInt8(k         & 0xFF),
        ]
        guard bytes.allSatisfy({ $0 > 0x1F && $0 < 0x7F }) else { return nil }
        return String(bytes: bytes, encoding: .ascii)
    }

    // Read a key with a known size, bypassing getKeyInfo
    private func rawReadKey(_ key: String, size: UInt32) -> [UInt8]? {
        return readKeyBytes(key: key, dataSize: IOByteCount32(size))
    }

    private func groupForUnknownKey(_ key: String) -> TempKey.Group {
        let p = key.prefix(2)
        if p == "Tg" || p == "TG" { return .gpu }
        if p == "Tm" || p == "Ts" || p == "Ta" || p == "TB" { return .system }
        return .cpu
    }

    // MARK: – Private

    private func open() {
        var iterator: io_iterator_t = 0
        let matching = IOServiceMatching("AppleSMC")
        let searchResult = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard searchResult == kIOReturnSuccess else {
            openError = "IOServiceGetMatchingServices failed: \(searchResult)"
            return
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        guard service != MACH_PORT_NULL else {
            openError = "AppleSMC service not found"
            return
        }
        defer { IOObjectRelease(service) }

        // Connection type 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        if result != kIOReturnSuccess {
            openError = "IOServiceOpen failed: 0x\(String(UInt32(bitPattern: result), radix: 16))"
            connection = 0
            return
        }

        // kSMCUserClientOpen (selector 0) — required on macOS 26+ before
        // calling selector 2 (kSMCHandleYPCEvent). Older macOS allowed
        // skipping this, macOS 26 returns kIOReturnBadArgument without it.
        let inSize   = MemoryLayout<SMCParamStruct>.size
        var outSize  = MemoryLayout<SMCParamStruct>.size
        var dummyIn  = SMCParamStruct()
        var dummyOut = SMCParamStruct()
        IOConnectCallStructMethod(connection, 0, &dummyIn, inSize, &dummyOut, &outSize)
    }

    private func readTemperature(key: String) -> Double? {
        guard let info = getKeyInfo(key: key) else { return nil }
        guard let bytes = readKeyBytes(key: key, dataSize: info.dataSize) else { return nil }
        return parseTemp(bytes: bytes, typeCode: info.dataType)
    }

    private func getKeyInfo(key: String) -> SMCKeyInfoData? {
        var input  = SMCParamStruct()
        var output = SMCParamStruct()
        input.key   = fourCC(key)
        input.data8 = SMCCommand.getKeyInfo.rawValue

        guard callSMC(input: &input, output: &output), output.result == 0 else { return nil }
        return output.keyInfo
    }

    private func readKeyBytes(key: String, dataSize: IOByteCount32) -> [UInt8]? {
        var input  = SMCParamStruct()
        var output = SMCParamStruct()
        input.key                = fourCC(key)
        input.keyInfo.dataSize   = dataSize
        input.data8              = SMCCommand.readKey.rawValue

        guard callSMC(input: &input, output: &output), output.result == 0 else { return nil }

        return withUnsafeBytes(of: output.bytes) { ptr in
            Array(ptr.prefix(Int(dataSize)))
        }
    }

    private(set) var lastKernResult: kern_return_t = 0

    @discardableResult
    private func callSMC(input: inout SMCParamStruct, output: inout SMCParamStruct) -> Bool {
        let inSize  = MemoryLayout<SMCParamStruct>.size
        var outSize = MemoryLayout<SMCParamStruct>.size
        let r = IOConnectCallStructMethod(connection, methodSelector,
                                          &input, inSize, &output, &outSize)
        lastKernResult = r
        return r == kIOReturnSuccess
    }

    // Try a specific selector index and return kern_return_t (for diagnostics only)
    private func callSMCWithSelector(_ sel: UInt32,
                                     input: inout SMCParamStruct,
                                     output: inout SMCParamStruct) -> kern_return_t {
        let inSize  = MemoryLayout<SMCParamStruct>.size
        var outSize = MemoryLayout<SMCParamStruct>.size
        return IOConnectCallStructMethod(connection, sel, &input, inSize, &output, &outSize)
    }

    private func fourCC(_ str: String) -> UInt32 {
        str.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    private func parseTemp(bytes: [UInt8], typeCode: UInt32) -> Double? {
        // Type code is stored big-endian in the struct
        let chars = (0..<4).map { UInt8((typeCode >> ((3 - $0) * 8)) & 0xFF) }
        let typeStr = String(bytes: chars, encoding: .ascii) ?? ""

        switch typeStr {
        case "sp78":   // 2-byte signed fixed-point (8.8)
            guard bytes.count >= 2 else { return nil }
            return Double(bytes[0]) + Double(bytes[1]) / 256.0

        case "flt ":   // 4-byte IEEE 754 float — Apple Silicon SMC returns little-endian
            guard bytes.count >= 4 else { return nil }
            let bits = UInt32(bytes[3]) << 24 | UInt32(bytes[2]) << 16
                     | UInt32(bytes[1]) << 8  | UInt32(bytes[0])
            let f = Float(bitPattern: bits)
            return (f.isNaN || f.isInfinite) ? nil : Double(f)

        case "ui8 ":   // unsigned 8-bit int (sometimes used for temps)
            guard bytes.count >= 1 else { return nil }
            return Double(bytes[0])

        default:
            return nil
        }
    }
}
