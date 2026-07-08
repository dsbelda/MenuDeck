import CoreAudio
import AppKit
import Darwin

// MARK: - Model

struct AudioApp: Identifiable {
    let id: AudioObjectID    // HAL process object ID
    let pid: pid_t
    let name: String
    var volume: Float        // 0..1, reflects last set value
    var isMuted: Bool
    var isControlled: Bool   // PerAppController active
    var controlError: String?
}

// MARK: - Manager (singleton – controllers survive popover close)

@MainActor
final class CoreAudioManager: ObservableObject {
    static let shared = CoreAudioManager()

    @Published var apps: [AudioApp] = []
    /// Set once any tap creation fails — there is no public API to check the
    /// "Audio Capture" TCC permission ahead of time, so we only learn about
    /// it from a failed activation. The first activation attempt is what
    /// triggers the system's permission prompt.
    @Published var lastPermissionError: String?

    private var controllers: [AudioObjectID: PerAppController] = [:]

    private init() {}

    // MARK: – Public

    func refresh() {
        let fresh = fetchAudioApps()
        apps = fresh.map { app in
            var a = app
            if let ctrl = controllers[app.id] {
                a.isControlled = true
                a.volume       = ctrl.volume
                a.isMuted      = ctrl.isMuted
            }
            return a
        }
    }

    func openPrivacySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        )
    }

    func setVolume(_ volume: Float, for app: AudioApp) {
        let v = max(0, min(1, volume))
        let ctrl = ensureController(for: app)
        ctrl?.setVolume(v)
        mutate(app.id) { $0.volume = v; $0.isMuted = v == 0 }
    }

    func toggleMute(for app: AudioApp) {
        let nowMuted = !app.isMuted
        let ctrl = ensureController(for: app)
        ctrl?.setMuted(nowMuted)
        mutate(app.id) { $0.isMuted = nowMuted }
    }

    // MARK: – Private

    /// Returns existing or newly created controller for the app.
    /// First call ever made triggers macOS's "Clutch wants to use Audio
    /// Capture" system prompt (no public API exists to pre-check this).
    @discardableResult
    private func ensureController(for app: AudioApp) -> PerAppController? {
        if let existing = controllers[app.id] { return existing }

        let ctrl = PerAppController()
        do {
            try ctrl.activate(objectID: app.id, name: app.name)
            controllers[app.id] = ctrl
            mutate(app.id) { $0.isControlled = true; $0.controlError = nil }
            lastPermissionError = nil
            return ctrl
        } catch {
            let msg = error.localizedDescription
            mutate(app.id) { $0.controlError = msg }
            lastPermissionError = msg
            return nil
        }
    }

    private func mutate(_ id: AudioObjectID, transform: (inout AudioApp) -> Void) {
        guard let i = apps.firstIndex(where: { $0.id == id }) else { return }
        transform(&apps[i])
    }

    // MARK: – Enumerate audio apps

    private func fetchAudioApps() -> [AudioApp] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioObjectID>.size
        var ids   = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &ids) == noErr
        else { return [] }

        let all = ids.compactMap { buildApp(objectID: $0) }

        // Deduplicate by resolved name.
        // Priority: process actively running audio output > .regular policy > anything else.
        // This collapses "Safari" + "Safari Graphics an..." → one "Safari" entry that
        // uses the helper's AudioObjectID (since the helper is the one with audio).
        var byName: [String: AudioApp] = [:]
        for app in all {
            let runsOutput = isRunningOutput(objectID: app.id)
            if let existing = byName[app.name] {
                let existingRuns = isRunningOutput(objectID: existing.id)
                // Prefer the actual audio-producing process for the tap
                if runsOutput && !existingRuns { byName[app.name] = app }
            } else {
                byName[app.name] = app
            }
        }
        return byName.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func buildApp(objectID: AudioObjectID) -> AudioApp? {
        guard let pid = halPID(for: objectID),
              pid != ProcessInfo.processInfo.processIdentifier else { return nil }
        guard let name = resolvedName(pid: pid, objectID: objectID) else { return nil }

        let running   = isRunning(objectID: objectID)
        let isUserApp = NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular
        guard running || isUserApp else { return nil }

        return AudioApp(id: objectID, pid: pid, name: name,
                        volume: 1, isMuted: false, isControlled: false, controlError: nil)
    }

    // MARK: – CoreAudio helpers

    private func halPID(for id: AudioObjectID) -> pid_t? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyPID,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var v: pid_t = 0; var sz = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &sz, &v) == noErr else { return nil }
        return v
    }

    private func isRunning(objectID: AudioObjectID) -> Bool {
        for sel in [kAudioProcessPropertyIsRunning, kAudioProcessPropertyIsRunningOutput] {
            var addr = AudioObjectPropertyAddress(mSelector: sel,
                                                  mScope: kAudioObjectPropertyScopeGlobal,
                                                  mElement: kAudioObjectPropertyElementMain)
            var v: UInt32 = 0; var sz = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(objectID, &addr, 0, nil, &sz, &v) == noErr, v != 0 { return true }
        }
        return false
    }

    private func bundleID(for id: AudioObjectID) -> String? {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyBundleID,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var ref: Unmanaged<CFString>? = nil; var sz = UInt32(MemoryLayout<CFString?>.size)
        guard AudioObjectGetPropertyData(id, &addr, 0, nil, &sz, &ref) == noErr else { return nil }
        return ref?.takeRetainedValue() as String?
    }

    private func resolvedName(pid: pid_t, objectID: AudioObjectID) -> String? {
        if let app = NSRunningApplication(processIdentifier: pid) {
            // Main .regular app → use its name directly
            if app.activationPolicy == .regular, let n = app.localizedName { return n }

            // Helper inside a .app bundle → use the outermost app name
            if let url = app.bundleURL, let n = outermostApp(in: url.path) { return n }

            // Helper NOT in a .app bundle (e.g. WebKit in /System/Library/…):
            // Walk up the parent-PID chain looking for the owning .regular app
            if let n = parentRegularAppName(for: pid) { return n }

            // Last resort: use the process's own localizedName
            if let n = app.localizedName, !n.isEmpty { return n }
        }

        var buf = [UInt8](repeating: 0, count: 4096)
        if proc_pidpath(pid, &buf, 4096) > 0 {
            let path = String(decoding: buf.prefix(while: { $0 != 0 }), as: UTF8.self)
            if let n = outermostApp(in: path) { return n }
        }

        if let bid = bundleID(for: objectID) {
            guard !bid.hasPrefix("com.apple.") else { return nil }
            return bid.components(separatedBy: ".").last.map { $0.capitalized }
        }
        return nil
    }

    /// Walk up the process tree (via PROC_PIDTBSDINFO.pbi_ppid) until we find
    /// a .regular NSRunningApplication — that's the user-visible parent app.
    private func parentRegularAppName(for pid: pid_t) -> String? {
        var current = pid
        var depth   = 0
        repeat {
            var info = proc_bsdinfo()
            let ret  = proc_pidinfo(current, PROC_PIDTBSDINFO, 0,
                                    &info, Int32(MemoryLayout<proc_bsdinfo>.size))
            guard ret > 0 else { return nil }
            let ppid = pid_t(info.pbi_ppid)
            guard ppid > 1 else { return nil }         // 1 = launchd, stop here
            if let parent = NSRunningApplication(processIdentifier: ppid),
               parent.activationPolicy == .regular,
               let name = parent.localizedName { return name }
            current = ppid
            depth  += 1
        } while depth < 5
        return nil
    }

    private func outermostApp(in path: String) -> String? {
        var url = URL(fileURLWithPath: path); var outer: String? = nil
        while url.path != "/" {
            if url.lastPathComponent.hasSuffix(".app") { outer = url.deletingPathExtension().lastPathComponent }
            url = url.deletingLastPathComponent()
        }
        return outer
    }

    /// Whether this process is actively outputting audio right now.
    private func isRunningOutput(objectID: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(mSelector: kAudioProcessPropertyIsRunningOutput,
                                              mScope: kAudioObjectPropertyScopeGlobal,
                                              mElement: kAudioObjectPropertyElementMain)
        var v: UInt32 = 0; var sz = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(objectID, &addr, 0, nil, &sz, &v) == noErr && v != 0
    }
}
