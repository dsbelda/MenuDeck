import CoreAudio
import AudioToolbox
import Foundation

// MARK: - Error

enum ControllerError: Error, LocalizedError {
    case tapFailed(OSStatus)
    case formatUnavailable
    case aggregateFailed(OSStatus)
    case ioProcFailed(OSStatus)
    case startFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .tapFailed(let s):       return String(localized: "Process tap failed (\(s)). First use should trigger a system permission prompt — check Privacy & Security → Audio Capture.")
        case .formatUnavailable:      return String(localized: "Could not read tap audio format.")
        case .aggregateFailed(let s): return String(localized: "Aggregate device failed (\(s)).")
        case .ioProcFailed(let s):    return String(localized: "I/O proc setup failed (\(s)).")
        case .startFailed(let s):     return String(localized: "Device start failed (\(s)).")
        }
    }
}

// MARK: - Controller

/// Intercepts one app's audio via a CoreAudio Process Tap, wraps it in an
/// Aggregate Device (together with the real output device), and re-writes
/// the captured samples scaled by `volume` directly to the output in the
/// raw IOProc callback. This is the same architecture used by Apple's
/// AudioCap sample (insidegui/AudioCap) — AVAudioEngine cannot be retargeted
/// to a tap-backed aggregate device, so we drive it with
/// AudioDeviceCreateIOProcIDWithBlock instead.
final class PerAppController {

    var volume: Float = 1.0
    var isMuted: Bool = false

    private var tapID: AudioObjectID = .unknown
    private var aggregateDeviceID: AudioObjectID = .unknown
    private var deviceProcID: AudioDeviceIOProcID?
    private var running = false

    init() {}
    deinit { deactivate() }

    // MARK: – Public

    func activate(objectID: AudioObjectID, name: String) throws {
        // 1. Tap description — explicit UUID is required by the aggregate device later
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [objectID])
        tapDescription.uuid = UUID()
        tapDescription.name = "MenuDeck.\(name)"
        tapDescription.muteBehavior = .muted   // original app is always silenced; we re-output ourselves

        var tap: AudioObjectID = .unknown
        let tapStatus = AudioHardwareCreateProcessTap(tapDescription, &tap)
        guard tapStatus == noErr, tap.isValid else { throw ControllerError.tapFailed(tapStatus) }
        tapID = tap

        // 2. Tap's stream format (needed to size buffers correctly, sanity check)
        guard (try? readTapFormat(tap)) != nil else {
            AudioHardwareDestroyProcessTap(tap); tapID = .unknown
            throw ControllerError.formatUnavailable
        }

        // 3. Aggregate device combining: the real output device (so audio reaches
        //    speakers) + our tap (so we receive the captured samples each cycle)
        let outputDeviceID = try readDefaultOutputDevice()
        let outputUID = try readDeviceUID(outputDeviceID)

        let aggDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MenuDeck.\(name)",
            kAudioAggregateDeviceUIDKey: "com.menudeck.agg.\(UUID().uuidString)",
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid.uuidString,
                ]
            ],
        ]

        var agg: AudioObjectID = .unknown
        let aggStatus = AudioHardwareCreateAggregateDevice(aggDescription as CFDictionary, &agg)
        guard aggStatus == noErr, agg.isValid else {
            AudioHardwareDestroyProcessTap(tapID); tapID = .unknown
            throw ControllerError.aggregateFailed(aggStatus)
        }
        aggregateDeviceID = agg

        // 4. Raw IOProc: copy captured samples to the output buffer, scaled by volume
        var procID: AudioDeviceIOProcID?
        let ioStatus = AudioDeviceCreateIOProcIDWithBlock(&procID, agg, nil) { [weak self] _, inInputData, _, outOutputData, _ in
            guard let self else { return }
            let gain = self.isMuted ? 0 : self.volume
            PerAppController.copy(from: inInputData, to: outOutputData, gain: gain)
        }
        guard ioStatus == noErr, let validProc = procID else {
            AudioHardwareDestroyAggregateDevice(agg); aggregateDeviceID = .unknown
            AudioHardwareDestroyProcessTap(tapID); tapID = .unknown
            throw ControllerError.ioProcFailed(ioStatus)
        }
        deviceProcID = validProc

        let startStatus = AudioDeviceStart(agg, validProc)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(agg, validProc); deviceProcID = nil
            AudioHardwareDestroyAggregateDevice(agg); aggregateDeviceID = .unknown
            AudioHardwareDestroyProcessTap(tapID); tapID = .unknown
            throw ControllerError.startFailed(startStatus)
        }

        running = true
    }

    func deactivate() {
        if running, aggregateDeviceID.isValid, let proc = deviceProcID {
            AudioDeviceStop(aggregateDeviceID, proc)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, proc)
        }
        deviceProcID = nil
        if aggregateDeviceID.isValid { AudioHardwareDestroyAggregateDevice(aggregateDeviceID); aggregateDeviceID = .unknown }
        if tapID.isValid { AudioHardwareDestroyProcessTap(tapID); tapID = .unknown }
        running = false
    }

    func setVolume(_ v: Float) { volume = max(0, min(1, v)) }
    func setMuted(_ m: Bool)   { isMuted = m }

    // MARK: – Sample copy (Float32 PCM, scaled by gain)

    private static func copy(from input: UnsafePointer<AudioBufferList>, to output: UnsafeMutablePointer<AudioBufferList>, gain: Float) {
        let inList  = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        let outList = UnsafeMutableAudioBufferListPointer(output)
        for i in 0..<min(inList.count, outList.count) {
            guard let inData = inList[i].mData, let outData = outList[i].mData else { continue }
            let frameCount = Int(inList[i].mDataByteSize) / MemoryLayout<Float>.size
            let inSamples  = inData.assumingMemoryBound(to: Float.self)
            let outSamples = outData.assumingMemoryBound(to: Float.self)
            if gain == 0 {
                outSamples.update(repeating: 0, count: frameCount)
            } else {
                for f in 0..<frameCount { outSamples[f] = inSamples[f] * gain }
            }
        }
    }

    // MARK: – CoreAudio helpers

    private func readTapFormat(_ tap: AudioObjectID) throws -> AudioStreamBasicDescription {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioTapPropertyFormat,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var fmt = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let status = AudioObjectGetPropertyData(tap, &addr, 0, nil, &size, &fmt)
        guard status == noErr else { throw ControllerError.formatUnavailable }
        return fmt
    }

    private func readDefaultOutputDevice() throws -> AudioObjectID {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultSystemOutputDevice,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var dev: AudioObjectID = .unknown
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID.system, &addr, 0, nil, &size, &dev)
        guard status == noErr, dev.isValid else { throw ControllerError.aggregateFailed(status) }
        return dev
    }

    private func readDeviceUID(_ device: AudioObjectID) throws -> String {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var ref: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<CFString?>.size)
        let status = AudioObjectGetPropertyData(device, &addr, 0, nil, &size, &ref)
        guard status == noErr, let uid = ref?.takeRetainedValue() as String? else {
            throw ControllerError.aggregateFailed(status)
        }
        return uid
    }
}

// MARK: - AudioObjectID convenience

private extension AudioObjectID {
    static let system: AudioObjectID = AudioObjectID(kAudioObjectSystemObject)
    static let unknown: AudioObjectID = kAudioObjectUnknown
    var isValid: Bool { self != .unknown }
}
