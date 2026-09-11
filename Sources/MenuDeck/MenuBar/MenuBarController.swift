import AppKit
import SwiftUI
import Darwin
import IOKit

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private var hostingController: NSHostingController<MenuDeckPopoverView>

    // Dynamic icon state
    private var displayTimer: Timer?
    private var appliedMode: String?
    private var cpuPrevTicks = [Int: (UInt32, UInt32, UInt32, UInt32)]()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        hostingController = NSHostingController(rootView: MenuDeckPopoverView())
        super.init()

        setupStatusItem()
        setupPopover()
        startDisplayTimer()
        setupHotkeys()

        NotificationCenter.default.addObserver(
            self, selector: #selector(closePopover),
            name: .menuDeckClosePopover, object: nil
        )
        // Update icon immediately when user changes the setting
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsDidChange),
            name: UserDefaults.didChangeNotification, object: nil
        )
    }

    /// didChangeNotification fires for every defaults write in the process —
    /// including the com.apple.Metal HUD toggle — and refreshing means a
    /// synchronous SMC read. Filter down to the one key the status item reads.
    @objc private func settingsDidChange() {
        guard currentMode != appliedMode else { return }
        refreshDisplay()
    }

    private var currentMode: String {
        UserDefaults.standard.string(forKey: "menudeck.menuBarMode") ?? "icon"
    }

    // MARK: – Setup

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }
        button.action = #selector(togglePopover)
        button.target = self
        applyIcon()
    }

    private func setupPopover() {
        popover.behavior = .transient
        // NSPopover's show animation is a ~0.25s fade-and-scale that runs before
        // the content is interactive, and it stacks with the SwiftUI transitions
        // inside. A menu bar panel should be on screen the instant it's clicked.
        popover.animates = false
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = .preferredContentSize
        } else {
            popover.contentSize = NSSize(width: 320, height: 440)
        }
        popover.contentViewController = hostingController
    }

    // MARK: – Global shortcuts

    private func setupHotkeys() {
        HotkeyManager.shared.onTrigger = { [weak self] moduleID in
            self?.toggle(moduleID: moduleID)
        }
    }

    /// Pressing a module's shortcut opens the popover on that module — or, if it
    /// is already the one on screen, closes it again, so the same keystroke both
    /// summons and dismisses.
    private func toggle(moduleID: String) {
        let state = PopoverState.shared

        if popover.isShown, state.screen == .main, state.expandedID == moduleID {
            popover.performClose(nil)
            return
        }

        state.screen = .main
        state.expandedID = moduleID

        guard let button = statusItem.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
        // Without this the popover appears behind whatever app the user was in,
        // and its controls stay unresponsive until they click it.
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: – Display timer

    private func startDisplayTimer() {
        refreshDisplay()
        displayTimer = .repeating(every: 5, tolerance: 1) { [weak self] _ in
            Task { @MainActor in self?.refreshDisplay() }
        }
    }

    @objc private func refreshDisplay() {
        let mode = currentMode
        appliedMode = mode

        switch mode {
        case "temp":
            // The SMC read is a blocking IOKit round-trip, so it happens on the
            // actor's executor and only comes back here to draw.
            Task { [weak self] in
                guard let t = await SMCManager.shared.currentCPUTemp() else {
                    self?.applyIcon(); return
                }
                self?.setTitle(String(format: "%.0f°", t))
            }

        case "battery":
            if let lvl = readBatteryLevel() {
                setTitle("\(lvl)%")
            } else {
                applyIcon()
            }

        case "cpu":
            setTitle(String(format: "%.0f%%", readCPUAvg()))

        case "memory":
            setTitle(String(format: "%.1fG", readUsedRAM()))

        default:   // "icon"
            applyIcon()
        }
    }

    private func setTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        button.image = nil
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attrs)
    }

    private func applyIcon() {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(string: "")
        button.image = MenuDeckGlyph.statusBarImage()
    }

    // MARK: – Popover

    @objc private func closePopover() {
        popover.performClose(nil)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // No eager CoreAudio refresh here: refresh() is @MainActor and
            // enumerating the HAL walks every audio process and its parent
            // chain, so it stalled the main thread on every single open — even
            // when the volume module was never shown. VolumeControlView already
            // refreshes in its own onAppear, which is the only time it matters.
        }
    }

    // MARK: – Inline data readers (avoids depending on module VMs)

    private func readBatteryLevel() -> Int? {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard svc != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(svc) }
        return (IORegistryEntryCreateCFProperty(svc, "CurrentCapacity" as CFString, kCFAllocatorDefault, 0)?
                    .takeRetainedValue()) as? Int
    }

    private func readCPUAvg() -> Double {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t? = nil
        var infoCount: mach_msg_type_number_t = 0

        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                                   &cpuCount, &infoArray, &infoCount) == KERN_SUCCESS,
              let info = infoArray else { return 0 }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(bitPattern: info),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let n = Int(cpuCount)
        var total = 0.0
        for i in 0..<n {
            let b = Int(CPU_STATE_MAX) * i
            let u = UInt32(info[b + Int(CPU_STATE_USER)])
            let s = UInt32(info[b + Int(CPU_STATE_SYSTEM)])
            let d = UInt32(info[b + Int(CPU_STATE_IDLE)])
            let k = UInt32(info[b + Int(CPU_STATE_NICE)])
            if let p = cpuPrevTicks[i] {
                let du = u &- p.0; let ds = s &- p.1; let dd = d &- p.2; let dk = k &- p.3
                let sum = Double(du + ds + dd + dk)
                if sum > 0 { total += Double(du + ds + dk) / sum * 100 }
            }
            cpuPrevTicks[i] = (u, s, d, k)
        }
        return n > 0 ? total / Double(n) : 0
    }

    private func readUsedRAM() -> Double {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let ok = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard ok == KERN_SUCCESS else { return 0 }
        let page = Double(sysconf(_SC_PAGESIZE))
        return (Double(stats.active_count) + Double(stats.wire_count) + Double(stats.compressor_page_count))
            * page / 1_073_741_824
    }
}
