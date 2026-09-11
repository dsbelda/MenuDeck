import AppKit
import Foundation

/// Finds installed apps and the support files they leave behind.
///
/// Everything this module removes goes to the Trash through
/// `NSWorkspace.recycle`, never `unlink`. That is the whole safety model: an
/// uninstaller works from heuristics about which folders belong to which app,
/// heuristics are sometimes wrong, and the user must be able to put it back.
@MainActor
final class UninstallerManager: ObservableObject {
    // MARK: – Model

    struct App: Identifiable, Equatable, Sendable {
        let url: URL
        let name: String
        let bundleID: String
        let version: String?
        /// Installed by `brew install --cask`, so Homebrew keeps its own record
        /// of it that trashing the bundle would leave stale.
        let caskToken: String?

        var id: String { url.path }
    }

    struct Leftover: Identifiable, Equatable, Sendable {
        enum Match: Sendable {
            /// Named after the bundle identifier. Effectively certain.
            case bundleID
            /// Named after the app itself, like "Application Support/Code".
            /// Common, but a generic app name can collide with something else.
            case appName
        }

        let url: URL
        let category: String
        let bytes: Int64
        let match: Match

        var id: String { url.path }
        var displayName: String { url.lastPathComponent }
    }

    enum Stage: Equatable {
        case list
        case inspecting(App)
        case removing(App)
        case done(App, movedCount: Int, failed: [String])
    }

    // MARK: – State

    @Published private(set) var apps: [App] = []
    @Published private(set) var isLoadingApps = false

    @Published private(set) var stage: Stage = .list
    @Published private(set) var leftovers: [Leftover] = []
    @Published private(set) var bundleBytes: Int64 = 0
    @Published private(set) var isScanning = false
    @Published var selection: Set<String> = []
    /// True when some Library folders could not be read, so the list may be
    /// short. Saved Application State is protected even without Full Disk Access.
    @Published private(set) var scanIncomplete = false

    var selectedBytes: Int64 {
        bundleBytes + leftovers.filter { selection.contains($0.id) }.map(\.bytes).reduce(0, +)
    }

    func runningInstance(of app: App) -> NSRunningApplication? {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: app.bundleID)
            .first
    }

    // MARK: – Listing

    func loadApps() {
        guard !isLoadingApps, apps.isEmpty else { return }
        isLoadingApps = true

        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        Task.detached(priority: .userInitiated) {
            let found = Self.scanApplications(excluding: ownBundleID)
            await MainActor.run {
                self.apps = found
                self.isLoadingApps = false
            }
        }
    }

    func reloadApps() {
        apps = []
        loadApps()
    }

    /// Only the two user-facing app folders. /System/Applications is deliberately
    /// not scanned: those are part of the sealed system volume and cannot be
    /// removed, so offering them would be a button that only ever fails.
    private nonisolated static func scanApplications(excluding ownBundleID: String) -> [App] {
        let manager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Applications"),
        ]
        let caskTokens = Self.installedCaskTokens()

        var result: [App] = []
        for root in roots {
            let entries = (try? manager.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )) ?? []

            for url in entries where url.pathExtension == "app" {
                guard let bundle = Bundle(url: url),
                      let bundleID = bundle.bundleIdentifier,
                      bundleID != ownBundleID
                else { continue }

                let name = url.deletingPathExtension().lastPathComponent
                result.append(
                    App(
                        url: url,
                        name: name,
                        bundleID: bundleID,
                        version: bundle.infoDictionary?["CFBundleShortVersionString"] as? String,
                        caskToken: caskTokens[Self.slug(name)]
                    )
                )
            }
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Cask tokens are slugs of the app name — "Google Chrome" is
    /// "google-chrome" — so the Caskroom listing can be matched without asking
    /// brew anything, which keeps this off the subprocess path entirely.
    private nonisolated static func installedCaskTokens() -> [String: String] {
        let roots = ["/opt/homebrew/Caskroom", "/usr/local/Caskroom"]
        var tokens: [String: String] = [:]
        for root in roots {
            let entries = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
            for token in entries where !token.hasPrefix(".") {
                tokens[token] = token
            }
        }
        return tokens
    }

    private nonisolated static func slug(_ name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
    }

    // MARK: – Inspecting one app

    func inspect(_ app: App) {
        stage = .inspecting(app)
        leftovers = []
        selection = []
        bundleBytes = 0
        scanIncomplete = false
        isScanning = true

        Task.detached(priority: .userInitiated) {
            let bundleSize = allocatedSize(of: app.url)
            let (found, incomplete) = Self.findLeftovers(for: app)

            await MainActor.run {
                self.bundleBytes = bundleSize
                self.leftovers = found
                self.scanIncomplete = incomplete
                // Bundle-id matches are certain enough to pre-tick. Name matches
                // are left for the user to opt into after reading the path.
                self.selection = Set(
                    found.filter { $0.match == .bundleID }.map(\.id)
                )
                self.isScanning = false
            }
        }
    }

    func backToList() {
        stage = .list
        leftovers = []
        selection = []
    }

    func toggle(_ leftover: Leftover) {
        if selection.contains(leftover.id) {
            selection.remove(leftover.id)
        } else {
            selection.insert(leftover.id)
        }
    }

    private nonisolated static let searchLocations: [(path: String, category: String)] = [
        ("Library/Application Support",     "Application Support"),
        ("Library/Caches",                  "Caches"),
        ("Library/Containers",              "Containers"),
        ("Library/Group Containers",        "Group Containers"),
        ("Library/Preferences",             "Preferences"),
        ("Library/HTTPStorages",            "HTTPStorages"),
        ("Library/WebKit",                  "WebKit"),
        ("Library/Logs",                    "Logs"),
        ("Library/Cookies",                 "Cookies"),
        ("Library/Saved Application State", "Saved State"),
        ("Library/LaunchAgents",            "Launch Agents"),
    ]

    private nonisolated static func findLeftovers(for app: App) -> ([Leftover], Bool) {
        let manager = FileManager.default
        let home = URL(fileURLWithPath: NSHomeDirectory())
        var result: [Leftover] = []
        var incomplete = false

        for location in searchLocations {
            let directory = home.appendingPathComponent(location.path)
            guard let entries = try? manager.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil, options: []
            ) else {
                // Either the folder does not exist or TCC refused it. Only the
                // latter matters, and the two are indistinguishable here, so the
                // flag is raised whenever the folder is present but unreadable.
                if manager.fileExists(atPath: directory.path) { incomplete = true }
                continue
            }

            for url in entries {
                guard let match = classify(url, app: app) else { continue }
                result.append(
                    Leftover(
                        url: url,
                        category: location.category,
                        bytes: allocatedSize(of: url),
                        match: match
                    )
                )
            }
        }

        return (
            result.sorted {
                $0.match == $1.match ? $0.bytes > $1.bytes : $0.match == .bundleID
            },
            incomplete
        )
    }

    /// Decides whether a file belongs to this app.
    ///
    /// Suffixes are stripped by name rather than with `deletingPathExtension`,
    /// which would turn "com.apple.Safari" into "com.apple" — reverse-DNS
    /// folder names look like they have an extension and do not.
    private nonisolated static func classify(_ url: URL, app: App) -> Leftover.Match? {
        var stem = url.lastPathComponent
        for suffix in [".plist", ".savedState", ".binarycookies"] where stem.hasSuffix(suffix) {
            stem = String(stem.dropLast(suffix.count))
        }

        let id = app.bundleID
        if stem == id || stem.hasPrefix(id + ".") || stem.hasSuffix("." + id) {
            return .bundleID
        }
        if stem.caseInsensitiveCompare(app.name) == .orderedSame {
            return .appName
        }
        return nil
    }

    // MARK: – Removing

    func uninstall(_ app: App) {
        guard case .inspecting = stage else { return }
        guard runningInstance(of: app) == nil else { return }

        let targets = [app.url] + leftovers
            .filter { selection.contains($0.id) }
            .map(\.url)

        stage = .removing(app)

        Task {
            let failures = await Self.moveToTrash(targets)
            stage = .done(app, movedCount: targets.count - failures.count, failed: failures)
            reloadApps()
        }
    }

    /// `recycle` rather than `removeItem`: the Trash is what makes a wrong guess
    /// recoverable, and it is also the path that asks for authorisation when a
    /// bundle is not owned by the user instead of simply failing.
    private static func moveToTrash(_ urls: [URL]) async -> [String] {
        await withCheckedContinuation { continuation in
            NSWorkspace.shared.recycle(urls) { _, error in
                if error != nil {
                    continuation.resume(returning: urls.map(\.lastPathComponent))
                } else {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}
