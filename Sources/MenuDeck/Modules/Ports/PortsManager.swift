import Darwin
import Foundation

@MainActor
final class PortsManager: ObservableObject {
    struct Listener: Identifiable, Equatable, Sendable {
        let pid: Int32
        let command: String
        let port: Int
        let address: String
        /// The process belongs to the user running MenuDeck, so signalling it
        /// will actually work. Anything else needs root and is shown read-only.
        let isOwnedByUser: Bool

        var id: Int { port &* 100_000 &+ Int(pid) }
    }

    @Published private(set) var listeners: [Listener] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var timer: Timer?

    func start() {
        refresh()
        guard timer == nil else { return }
        timer = .repeating(every: 5, tolerance: 2) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true

        let user = NSUserName()
        Task.detached(priority: .userInitiated) {
            let result = Shell.run(
                "/usr/sbin/lsof",
                // -nP keeps numeric hosts and ports so nothing has to be
                // resolved: name lookups made this take seconds on a busy box.
                ["-nP", "-iTCP", "-sTCP:LISTEN"]
            )
            let parsed = Self.parse(result.output, currentUser: user)
            await MainActor.run {
                self.listeners = parsed
                self.isLoading = false
            }
        }
    }

    /// Sends SIGTERM, then SIGKILL if the process is still there a moment later.
    func quit(_ listener: Listener) {
        guard listener.isOwnedByUser else { return }
        lastError = nil

        guard kill(listener.pid, SIGTERM) == 0 else {
            lastError = String(localized: "Could not stop \(listener.command)")
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(700))
            // kill(pid, 0) probes for existence without signalling.
            if kill(listener.pid, 0) == 0 {
                _ = kill(listener.pid, SIGKILL)
            }
            refresh()
        }
    }

    // MARK: – Parsing

    /// lsof output is columnar text:
    ///
    ///     COMMAND  PID   USER  FD  TYPE  DEVICE  SIZE/OFF  NODE  NAME
    ///     node   12345 dsbelda 22u IPv6  0x…     0t0       TCP   *:3000 (LISTEN)
    ///
    /// A process listening on both stacks produces one row per family, so the
    /// same port shows up twice; they are collapsed by pid + port.
    private nonisolated static func parse(_ output: String, currentUser: String) -> [Listener] {
        var seen = Set<Int>()
        var result: [Listener] = []

        for line in output.split(separator: "\n").dropFirst() {
            let columns = line.split(separator: " ", omittingEmptySubsequences: true)
            guard columns.count >= 9,
                  let pid = Int32(columns[1]) else { continue }

            let command = String(columns[0])
            let user = String(columns[2])
            let name = String(columns[columns.count - 2])   // e.g. *:3000 or 127.0.0.1:5432

            guard let separator = name.lastIndex(of: ":"),
                  let port = Int(name[name.index(after: separator)...])
            else { continue }

            let key = Int(pid) &* 100_000 &+ port
            guard seen.insert(key).inserted else { continue }

            result.append(
                Listener(
                    pid: pid,
                    command: command,
                    port: port,
                    address: String(name[..<separator]),
                    isOwnedByUser: user == currentUser
                )
            )
        }

        return result.sorted { $0.port < $1.port }
    }
}
