import AppKit
import Foundation

extension Notification.Name {
    static let menuDeckClosePopover = Notification.Name("com.menudeck.closePopover")
}

// MARK: - Manager (singleton – the popover is dismissed before the capture even
// starts, so the result has to outlive the view that asked for it)

@MainActor
final class ScreenshotManager: ObservableObject {
    static let shared = ScreenshotManager()

    enum CaptureMode {
        case fullScreen, area, window
    }

    enum SaveTarget {
        case desktop, clipboard
    }

    enum CaptureResult {
        case file(URL)
        case clipboard
        case cancelled
        case failed(String)
    }

    @Published private(set) var lastResult: CaptureResult?
    @Published private(set) var isCapturing = false

    /// Because the popover is closed while capturing, the user never sees a
    /// result land — they see it on the *next* open. Without an expiry that
    /// means hours-old feedback presented as if it just happened.
    private static let resultLifetime: Duration = .seconds(30)
    private var expiryTask: Task<Void, Never>?

    private init() {}

    func capture(mode: CaptureMode, target: SaveTarget, delay: Int) {
        isCapturing = true
        setResult(nil)

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

        let destination: URL?
        switch target {
        case .clipboard:
            args.append("-c")
            destination = nil
        case .desktop:
            guard let url = Self.desktopDestination() else {
                finish(.failed("Could not locate the Desktop folder"))
                return
            }
            args.append(url.path)
            destination = url
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = args

        task.terminationHandler = { [weak self] process in
            // screencapture exits non-zero when the user presses Esc
            let succeeded = process.terminationStatus == 0
            Task { @MainActor in
                self?.finish(succeeded ? (destination.map { .file($0) } ?? .clipboard)
                                       : .cancelled)
            }
        }

        do {
            try task.run()
        } catch {
            finish(.failed(error.localizedDescription))
        }
    }

    private func finish(_ result: CaptureResult) {
        isCapturing = false
        setResult(result)
    }

    private func setResult(_ result: CaptureResult?) {
        expiryTask?.cancel()
        lastResult = result
        guard result != nil else { return }
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: Self.resultLifetime)
            guard !Task.isCancelled else { return }
            self?.lastResult = nil
        }
    }

    // MARK: – Destination

    /// Filenames must not follow the UI language: a localized date pattern
    /// gives every user a different sort order for the same folder.
    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        return f
    }()

    private static func desktopDestination() -> URL? {
        let fm = FileManager.default
        let desktop = (try? fm.url(for: .desktopDirectory, in: .userDomainMask,
                                   appropriateFor: nil, create: false))
            ?? fm.homeDirectoryForCurrentUser.appending(path: "Desktop")
        guard fm.fileExists(atPath: desktop.path) else { return nil }
        return desktop.appending(path: "Screenshot \(filenameFormatter.string(from: Date())).png")
    }
}
