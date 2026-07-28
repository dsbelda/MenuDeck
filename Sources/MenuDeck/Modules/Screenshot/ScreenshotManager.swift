import AppKit
import Foundation

extension Notification.Name {
    static let menuDeckClosePopover = Notification.Name("com.menudeck.closePopover")
}

@MainActor
final class ScreenshotManager: ObservableObject {

    enum CaptureMode {
        case fullScreen, area, window
    }

    enum SaveTarget {
        case desktop, clipboard
    }

    @Published var lastCapturePath: String? = nil
    @Published var isCapturing = false
    @Published var lastError: String? = nil

    func capture(mode: CaptureMode, target: SaveTarget, delay: Int) {
        isCapturing = true
        lastError = nil

        // Signal MenuBarController to close the popover before capturing
        NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)

        // Give the popover animation time to finish before screencapture takes over
        let settle: Double = delay > 0 ? 0.3 : 0.45
        DispatchQueue.main.asyncAfter(deadline: .now() + settle) { [weak self] in
            self?.runScreencapture(mode: mode, target: target, delay: delay)
        }
    }

    private func runScreencapture(mode: CaptureMode, target: SaveTarget, delay: Int) {
        var args: [String] = []

        switch mode {
        case .area:   args.append("-s")
        case .window: args.append("-w")
        case .fullScreen: break
        }

        if delay > 0 { args += ["-T\(delay)"] }

        let savedPath: String?
        if target == .clipboard {
            args.append("-c")
            savedPath = nil
        } else {
            let path = desktopPath()
            args.append(path)
            savedPath = path
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = args

        // Capture immutable copy for Sendable closure
        let capturedPath = savedPath
        task.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isCapturing = false
                if process.terminationStatus == 0 {
                    self.lastCapturePath = capturedPath ?? "Portapapeles"
                    self.lastError = nil
                } else {
                    self.lastError = "Captura cancelada"
                    self.lastCapturePath = nil
                }
            }
        }

        do {
            try task.run()
        } catch {
            isCapturing = false
            lastError = error.localizedDescription
        }
    }

    private func desktopPath() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'a las' HH.mm.ss"
        let name = "Captura \(formatter.string(from: Date())).png"
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        return desktop.appendingPathComponent(name).path
    }
}
