import AppKit
import UniformTypeIdentifiers

/// The apps pinned to the Dev Tools module, and the projects it can open in them.
@MainActor
final class DevAppsManager: ObservableObject {
    struct App: Identifiable, Equatable {
        let bundleID: String
        let url: URL

        var id: String { bundleID }
        var name: String { url.deletingPathExtension().lastPathComponent }
    }

    struct Project: Identifiable, Equatable, Sendable {
        let url: URL
        let modified: Date

        var id: String { url.path }
        var name: String { url.lastPathComponent }
    }

    @Published private(set) var apps: [App] = []
    @Published private(set) var projects: [Project] = []

    private static let storageKey = "menudeck.devApps"
    private static let rootKey = "menudeck.devProjectsRoot"

    /// What the module shows until the list is edited. Only the ones that are
    /// actually installed appear, so this can afford to be generous.
    private static let suggested = [
        "dev.warp.Warp-Stable",
        "com.t3tools.t3code",
        "com.anthropic.claudefordesktop",
        "com.openai.codex",
        "com.apple.dt.Xcode",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",   // Cursor
        "dev.zed.Zed",
        "com.mitchellh.ghostty",
        "com.googlecode.iterm2",
    ]

    /// Bundle identifiers rather than paths: an app that is moved, or replaced
    /// by an update that renames it, is still the same app.
    private var bundleIDs: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? Self.suggested }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.storageKey)
            refresh()
        }
    }

    /// An identifier that no longer resolves is skipped, not forgotten: the app
    /// comes back on its own if it is reinstalled.
    func refresh() {
        let fresh = bundleIDs.compactMap { id in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
                .map { App(bundleID: id, url: $0) }
        }
        if fresh != apps { apps = fresh }

        let root = projectsRoot
        Task.detached(priority: .userInitiated) {
            let found = Self.scanProjects(in: root)
            await MainActor.run {
                if found != self.projects { self.projects = found }
            }
        }
    }

    /// Launches the app, or brings it forward if it is already running.
    func open(_ app: App) {
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init())
        NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
    }

    func remove(_ app: App) {
        bundleIDs.removeAll { $0 == app.bundleID }
    }

    func add(_ urls: [URL]) {
        var ids = bundleIDs
        for id in urls.compactMap({ Bundle(url: $0)?.bundleIdentifier }) where !ids.contains(id) {
            ids.append(id)
        }
        bundleIDs = ids
    }

    // MARK: – Projects

    /// The folder whose subfolders are the projects. ~/Developer until changed.
    var projectsRoot: URL {
        UserDefaults.standard.string(forKey: Self.rootKey).map { URL(fileURLWithPath: $0) }
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Developer")
    }

    /// Most recently worked on first.
    private nonisolated static func scanProjects(in root: URL) -> [Project] {
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .contentModificationDateKey]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]
        )) ?? []

        return entries.compactMap { url -> Project? in
            guard let values = try? url.resourceValues(forKeys: keys),
                  values.isDirectory == true, values.isPackage != true
            else { return nil }

            // A folder's own date only moves when something is added or removed
            // at its top level. .git's moves on nearly every git command — the
            // index lock comes and goes inside it — so where there is one it is
            // the better record of when the project was last touched.
            let git = try? url.appendingPathComponent(".git")
                .resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            return Project(
                url: url,
                modified: max(values.contentModificationDate ?? .distantPast, git ?? .distantPast)
            )
        }
        .sorted { $0.modified > $1.modified }
    }

    /// Hands the folder to the app. What an app does with a folder is its own
    /// business: editors and terminals open it, anything else just comes forward.
    func open(_ project: Project, in app: App) {
        NSWorkspace.shared.open(
            [project.url], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration()
        )
        NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
    }

    func showInFinder(_ project: Project) {
        NSWorkspace.shared.activateFileViewerSelecting([project.url])
        NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
    }

    func chooseProjectsRoot() {
        let panel = NSOpenPanel()
        panel.directoryURL = projectsRoot
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = String(localized: "Choose")

        guard runPanel(panel), let url = panel.url else { return }
        UserDefaults.standard.set(url.path, forKey: Self.rootKey)
        refresh()
    }

    // MARK: – Panels

    func pickApps() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = true
        panel.prompt = String(localized: "Add")

        if runPanel(panel) { add(panel.urls) }
    }

    private func runPanel(_ panel: NSOpenPanel) -> Bool {
        // A transient popover closes the moment the panel takes key anyway;
        // doing it first keeps it from flashing behind the panel on the way out.
        NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
        NSApp.activate(ignoringOtherApps: true)
        return panel.runModal() == .OK
    }
}
