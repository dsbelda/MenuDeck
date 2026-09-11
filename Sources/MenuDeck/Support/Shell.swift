import Foundation

/// Runs command line tools on behalf of the modules that need them.
///
/// Every call names its executable by absolute path and builds its own
/// environment: a GUI process launched by LaunchServices inherits none of the
/// login shell's PATH, so `/usr/bin/env`-style lookups find nothing. This is the
/// single most common reason a tool that works in Terminal does nothing here.
enum Shell {
    struct Result: Sendable {
        var output: String
        var status: Int32
        var succeeded: Bool { status == 0 }
    }

    static let systemPath = "/usr/bin:/bin:/usr/sbin:/sbin"

    /// - Parameter onOutput: called with each chunk as it arrives, for commands
    ///   whose progress is worth showing before they finish.
    nonisolated static func run(
        _ executable: String,
        _ arguments: [String] = [],
        environment: [String: String] = [:],
        onOutput: (@Sendable (String) -> Void)? = nil
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        var env = [
            "PATH": systemPath,
            "HOME": NSHomeDirectory(),
        ]
        env.merge(environment) { _, custom in custom }
        process.environment = env

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return Result(output: error.localizedDescription, status: -1)
        }

        var collected = Data()
        let handle = pipe.fileHandleForReading
        while true {
            let chunk = handle.availableData
            if chunk.isEmpty { break }
            collected.append(chunk)
            if let onOutput {
                onOutput(String(decoding: chunk, as: UTF8.self))
            }
        }
        process.waitUntilExit()

        return Result(
            output: String(decoding: collected, as: UTF8.self),
            status: process.terminationStatus
        )
    }
}
