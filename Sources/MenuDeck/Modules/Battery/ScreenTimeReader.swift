import Foundation

/// How long the display has actually been on, per day.
///
/// Read from `pmset -g log`, which records every display on/off transition and
/// needs no permission. The alternative is Screen Time's own knowledgeC.db, but
/// that is an undocumented private database behind Full Disk Access, so it would
/// cost the user a heavy permission for data macOS already publishes.
@MainActor
final class ScreenTimeReader: ObservableObject {
    struct Day: Identifiable, Equatable, Sendable {
        let date: Date
        let seconds: TimeInterval
        var id: Date { date }
    }

    @Published private(set) var days: [Day] = []
    @Published private(set) var isLoading = false
    /// The log only reaches back so far, so the earliest day it reports is
    /// usually a partial figure rather than a real total.
    @Published private(set) var coversFullHistory = true

    private var lastLoaded: Date?

    /// Looked up by date rather than taken from the end of the list: the last
    /// entry is the last day with data, which is not today if the log has not
    /// seen a display event since midnight.
    var today: TimeInterval {
        let start = Calendar.current.startOfDay(for: Date())
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: start) }?.seconds ?? 0
    }

    /// `pmset -g log` dumps tens of thousands of lines and takes over a second,
    /// so it is never put on a timer and the result is held for five minutes.
    func load(force: Bool = false) {
        guard !isLoading else { return }
        if !force, let lastLoaded, Date().timeIntervalSince(lastLoaded) < 300 { return }

        isLoading = true
        Task.detached(priority: .utility) {
            let result = Shell.run("/usr/bin/pmset", ["-g", "log"])
            let parsed = Self.parse(result.output, now: Date())

            await MainActor.run {
                if !parsed.days.isEmpty {
                    self.days = parsed.days
                    self.coversFullHistory = parsed.complete
                }
                self.isLoading = false
                self.lastLoaded = Date()
            }
        }
    }

    // MARK: – Parsing

    private nonisolated static let lineFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// Lines look like:
    ///
    ///     2026-09-11 12:29:51 +0200 Notification   Display is turned on
    ///
    /// Two quirks the log actually exhibits: the same transition can be reported
    /// twice in a row (two "on" with no "off" between them), and the window can
    /// open mid-session, so the first event seen may be an "off" for a stretch
    /// that began before the log starts.
    private nonisolated static func parse(
        _ log: String, now: Date
    ) -> (days: [Day], complete: Bool) {
        var onSince: Date?
        var firstEvent: Date?
        var sawLeadingOff = false
        var totals: [Date: TimeInterval] = [:]
        let calendar = Calendar.current

        for line in log.split(separator: "\n") {
            guard line.contains("Display is turned") else { continue }
            guard line.count > 29 else { continue }

            let stamp = String(line.prefix(25))
            guard let date = lineFormatter.date(from: stamp) else { continue }
            if firstEvent == nil { firstEvent = date }

            if line.contains("turned on") {
                // Ignore a repeated "on": the display was already lit, and the
                // earlier timestamp is the one that bounds the session.
                if onSince == nil { onSince = date }
            } else {
                guard let start = onSince else {
                    if firstEvent == date { sawLeadingOff = true }
                    continue
                }
                accumulate(from: start, to: date, into: &totals, calendar: calendar)
                onSince = nil
            }
        }

        // The display is still on right now, so the open session runs to `now`.
        if let start = onSince {
            accumulate(from: start, to: now, into: &totals, calendar: calendar)
        }

        let recorded = totals
            .map { Day(date: $0.key, seconds: $0.value) }
            .sorted { $0.date < $1.date }

        return (fillGaps(in: recorded, calendar: calendar), !sawLeadingOff)
    }

    /// A day the Mac spent shut down produces no events at all. Left as a hole,
    /// four days of data spread over a week would render as four adjacent bars
    /// and read as four consecutive days, so the quiet ones are made explicit.
    private nonisolated static func fillGaps(
        in recorded: [Day], calendar: Calendar
    ) -> [Day] {
        guard let first = recorded.first?.date, let last = recorded.last?.date
        else { return recorded }

        var filled: [Day] = []
        var cursor = first
        var index = 0

        while cursor <= last {
            if index < recorded.count,
               calendar.isDate(recorded[index].date, inSameDayAs: cursor) {
                filled.append(recorded[index])
                index += 1
            } else {
                filled.append(Day(date: cursor, seconds: 0))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return filled
    }

    /// Splits a session across midnight so each day gets only its own share.
    /// Without this a stretch from 23:42 to 00:17 would be counted whole against
    /// whichever day the parser happened to file it under.
    private nonisolated static func accumulate(
        from start: Date,
        to end: Date,
        into totals: inout [Date: TimeInterval],
        calendar: Calendar
    ) {
        guard end > start else { return }

        var cursor = start
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let sliceEnd = min(nextDay, end)
            totals[dayStart, default: 0] += sliceEnd.timeIntervalSince(cursor)
            cursor = sliceEnd
        }
    }

    // MARK: – Formatting

    nonisolated static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
}
