import Foundation

/// Drives the `brew` CLI.
///
/// Everything here runs off the main thread through `Process`. Note that this
/// module is fundamentally incompatible with App Store distribution — the
/// sandbox forbids invoking external binaries — which is fine for a directly
/// distributed app but is the reason it stays self-contained and easy to drop.
@MainActor
final class BrewManager: ObservableObject {
    static let shared = BrewManager()

    // MARK: – Model

    struct Package: Identifiable, Equatable, Sendable {
        let name: String
        let desc: String?
        let installedVersion: String
        let latestVersion: String
        let isCask: Bool
        let isOutdated: Bool
        let isPinned: Bool
        /// The user asked for this one, rather than it arriving as a dependency.
        let requestedByUser: Bool
        /// Installed formulae that depend on this one.
        let dependents: [String]

        var id: String { (isCask ? "cask:" : "formula:") + name }
    }

    enum Availability: Equatable {
        case checking
        case missing
        case found(path: String)
    }

    struct Job: Equatable {
        var title: String
        var output: String
        var isFinished: Bool
        var succeeded: Bool
        /// Shown verbatim so a failed job can be re-run in Terminal.
        var command: String
    }

    // MARK: – State

    @Published private(set) var availability: Availability = .checking
    @Published private(set) var packages: [Package] = []
    @Published private(set) var isLoading = false
    @Published private(set) var job: Job?

    private var lastLoaded: Date?

    var outdated: [Package] { packages.filter(\.isOutdated) }
    var requested: [Package] { packages.filter(\.requestedByUser) }

    var isBusy: Bool {
        guard let job else { return false }
        return !job.isFinished
    }

    private init() {
        availability = Self.locateBrew().map { .found(path: $0) } ?? .missing
    }

    // MARK: – Loading

    /// Refreshes the package list. Skipped if the cache is younger than five
    /// minutes unless `force` is set — reopening the popover shouldn't spawn a
    /// subprocess every time.
    func load(force: Bool = false) {
        guard case .found(let brew) = availability, !isLoading else { return }
        if !force, let lastLoaded, Date().timeIntervalSince(lastLoaded) < 300 { return }

        isLoading = true
        Task.detached(priority: .userInitiated) {
            let result = Self.run(brew: brew, ["info", "--json=v2", "--installed"])
            let parsed = result.status == 0 ? Self.parse(result.output) : []
            await MainActor.run {
                if !parsed.isEmpty || result.status == 0 { self.packages = parsed }
                self.isLoading = false
                self.lastLoaded = Date()
            }
        }
    }

    // MARK: – Actions

    func updateIndex() {
        // The one command that deliberately hits the network to refresh taps.
        start(title: String(localized: "Updating package index"), arguments: ["update"])
    }

    func upgradeAll() {
        start(title: String(localized: "Upgrading everything"), arguments: ["upgrade"])
    }

    func upgrade(_ package: Package) {
        start(
            title: String(localized: "Upgrading \(package.name)"),
            arguments: package.isCask
                ? ["upgrade", "--cask", package.name]
                : ["upgrade", package.name]
        )
    }

    func uninstall(_ package: Package) {
        start(
            title: String(localized: "Removing \(package.name)"),
            arguments: package.isCask
                ? ["uninstall", "--cask", package.name]
                : ["uninstall", package.name]
        )
    }

    func dismissJob() {
        guard job?.isFinished == true else { return }
        job = nil
    }

    private func start(title: String, arguments: [String]) {
        guard case .found(let brew) = availability, !isBusy else { return }

        job = Job(
            title: title,
            output: "",
            isFinished: false,
            succeeded: false,
            command: "brew " + arguments.joined(separator: " ")
        )

        Task.detached(priority: .userInitiated) {
            let result = Self.run(brew: brew, arguments) { chunk in
                Task { @MainActor in Self.shared.append(chunk) }
            }
            await MainActor.run {
                self.job?.isFinished = true
                self.job?.succeeded = result.status == 0
                self.load(force: true)
            }
        }
    }

    private func append(_ text: String) {
        guard job != nil else { return }
        job?.output += text
        // Compiling a large formula emits megabytes; only the tail is ever read.
        if let output = job?.output, output.count > 12_000 {
            job?.output = String(output.suffix(8_000))
        }
    }

    // MARK: – Locating brew

    /// A GUI process gets none of the shell's PATH, so `brew` is never on it.
    /// These are the two prefixes Homebrew itself installs to.
    private static func locateBrew() -> String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    // MARK: – Process

    private nonisolated static func run(
        brew: String,
        _ arguments: [String],
        onOutput: (@Sendable (String) -> Void)? = nil
    ) -> Shell.Result {
        // brew shells out to git and curl, so its own prefix has to be on the
        // PATH it is handed.
        let binDirectory = (brew as NSString).deletingLastPathComponent

        return Shell.run(
            brew,
            arguments,
            environment: [
                "PATH": "\(binDirectory):\(Shell.systemPath)",
                // No controlling terminal here: without this brew blocks forever
                // on a confirmation prompt nobody can answer.
                "NONINTERACTIVE": "1",
                "HOMEBREW_NO_AUTO_UPDATE": "1",
                "HOMEBREW_NO_ANALYTICS": "1",
                "HOMEBREW_NO_COLOR": "1",
                "HOMEBREW_NO_EMOJI": "1",
                "HOMEBREW_NO_ENV_HINTS": "1",
            ],
            onOutput: onOutput
        )
    }

    // MARK: – Parsing

    private struct Payload: Decodable {
        struct Formula: Decodable {
            struct Installed: Decodable {
                struct RuntimeDependency: Decodable { let fullName: String? }
                let version: String
                let installedOnRequest: Bool?
                let runtimeDependencies: [RuntimeDependency]?
            }
            struct Versions: Decodable { let stable: String? }

            let name: String
            let desc: String?
            let versions: Versions
            let installed: [Installed]
            let outdated: Bool
            let pinned: Bool
        }

        struct Cask: Decodable {
            let token: String
            let desc: String?
            let version: String
            let installed: String?
            let outdated: Bool
            let pinned: Bool
        }

        let formulae: [Formula]
        let casks: [Cask]
    }

    private nonisolated static func parse(_ json: String) -> [Package] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        guard let data = json.data(using: .utf8),
              let payload = try? decoder.decode(Payload.self, from: data)
        else { return [] }

        // Reverse dependency map, built from the same payload. `brew uses` would
        // mean another subprocess and a tap scan for information already here.
        var dependents: [String: [String]] = [:]
        for formula in payload.formulae {
            for dependency in formula.installed.first?.runtimeDependencies ?? [] {
                guard let name = dependency.fullName else { continue }
                dependents[name, default: []].append(formula.name)
            }
        }

        let formulae = payload.formulae.compactMap { formula -> Package? in
            guard let installed = formula.installed.first else { return nil }
            return Package(
                name: formula.name,
                desc: formula.desc,
                installedVersion: installed.version,
                latestVersion: formula.versions.stable ?? installed.version,
                isCask: false,
                isOutdated: formula.outdated,
                isPinned: formula.pinned,
                requestedByUser: installed.installedOnRequest ?? false,
                dependents: (dependents[formula.name] ?? []).sorted()
            )
        }

        let casks = payload.casks.map { cask in
            Package(
                name: cask.token,
                desc: cask.desc,
                installedVersion: cask.installed ?? "—",
                latestVersion: cask.version,
                isCask: true,
                isOutdated: cask.outdated,
                isPinned: cask.pinned,
                // Casks are never pulled in as dependencies of a formula.
                requestedByUser: true,
                dependents: []
            )
        }

        return (formulae + casks).sorted { $0.name < $1.name }
    }
}
