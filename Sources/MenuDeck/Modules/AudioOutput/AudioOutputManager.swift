import CoreAudio
import Foundation

@MainActor
final class AudioOutputManager: ObservableObject {
    struct Device: Identifiable, Equatable {
        let id: AudioDeviceID
        let name: String
        let symbol: String
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var currentID: AudioDeviceID?

    private var timer: Timer?

    // MARK: – Lifecycle

    func start() {
        refresh()
        guard timer == nil else { return }
        // Polling rather than an AudioObject property listener: the listener
        // block is invoked on an arbitrary CoreAudio thread, and enumerating
        // devices is cheap enough (unlike the per-process tap walk the volume
        // module does) that a 3s tick is the simpler correct thing.
        timer = .repeating(every: 3, tolerance: 1) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        devices = Self.outputDevices()
        currentID = Self.defaultOutput()
    }

    func select(_ device: Device) {
        guard Self.setDefaultOutput(device.id) else { return }
        currentID = device.id
    }

    // MARK: – CoreAudio

    private static func systemAddress(_ selector: AudioObjectPropertySelector)
        -> AudioObjectPropertyAddress
    {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static func outputDevices() -> [Device] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = systemAddress(kAudioHardwarePropertyDevices)

        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr
        else { return [] }

        return ids.compactMap { id in
            guard hasOutputStreams(id), let name = name(of: id) else { return nil }
            return Device(id: id, name: name, symbol: symbol(for: id))
        }
    }

    /// A device is an *output* only if its output scope actually carries
    /// channels — every input device is in the same list otherwise.
    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr,
              size > 0 else { return false }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, raw) == noErr
        else { return false }

        let buffers = UnsafeMutableAudioBufferListPointer(
            raw.assumingMemoryBound(to: AudioBufferList.self)
        )
        return buffers.contains { $0.mNumberChannels > 0 }
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var address = systemAddress(kAudioObjectPropertyName)
        var size = UInt32(MemoryLayout<CFString?>.size)
        var name: CFString?

        let status = withUnsafeMutablePointer(to: &name) {
            AudioObjectGetPropertyData(id, &address, 0, nil, &size, $0)
        }
        guard status == noErr, let name else { return nil }
        return name as String
    }

    private static func symbol(for id: AudioDeviceID) -> String {
        var address = systemAddress(kAudioDevicePropertyTransportType)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &transport) == noErr
        else { return "hifispeaker" }

        switch transport {
        case kAudioDeviceTransportTypeBuiltIn:      return "laptopcomputer"
        case kAudioDeviceTransportTypeBluetooth,
             kAudioDeviceTransportTypeBluetoothLE:  return "airpodspro"
        case kAudioDeviceTransportTypeUSB:          return "hifispeaker"
        case kAudioDeviceTransportTypeHDMI,
             kAudioDeviceTransportTypeDisplayPort:  return "tv"
        case kAudioDeviceTransportTypeAirPlay:      return "airplayaudio"
        case kAudioDeviceTransportTypeVirtual,
             kAudioDeviceTransportTypeAggregate:    return "waveform"
        default:                                    return "hifispeaker"
        }
    }

    private static func defaultOutput() -> AudioDeviceID? {
        var address = systemAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var id: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)

        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id
        ) == noErr else { return nil }
        return id
    }

    private static func setDefaultOutput(_ id: AudioDeviceID) -> Bool {
        var address = systemAddress(kAudioHardwarePropertyDefaultOutputDevice)
        var value = id
        return AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil,
            UInt32(MemoryLayout<AudioDeviceID>.size), &value
        ) == noErr
    }
}
