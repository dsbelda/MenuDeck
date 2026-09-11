import SwiftUI

struct BatteryView: View {
    @StateObject private var mgr = BatteryManager()
    @StateObject private var screen = ScreenTimeReader()

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider().opacity(0.08)
            stats
            Divider().opacity(0.08)
            screenTime
        }
        .onAppear  { mgr.start(); screen.load() }
        .onDisappear { mgr.stop() }
    }

    // MARK: – Screen-on time

    private var screenTime: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                screenCell(
                    icon: "sun.max.fill",
                    tint: .yellow,
                    label: "Screen on today",
                    value: screen.isLoading && screen.days.isEmpty
                        ? nil
                        : ScreenTimeReader.format(screen.today)
                )

                Divider().frame(height: 26).opacity(0.12)

                if let since = screen.sinceFullCharge {
                    screenCell(
                        icon: "bolt.badge.clock.fill",
                        tint: .green,
                        label: "Since full charge",
                        value: ScreenTimeReader.format(since)
                    )
                    .help(chargeHelp)
                } else {
                    // pmset's log only reaches back a few days, so a Mac that
                    // has not been topped up recently has nothing to measure
                    // from and the cell would otherwise show a bare dash.
                    screenCell(
                        icon: "bolt.badge.clock",
                        tint: .secondary,
                        label: "Since full charge",
                        value: screen.isLoading ? nil : "—"
                    )
                    .help("No full charge inside the log's window")
                }
            }

            if !screen.days.isEmpty {
                history
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func screenCell(
        icon: String, tint: Color, label: LocalizedStringKey, value: String?
    ) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            } else {
                ProgressView().controlSize(.small).scaleEffect(0.55).frame(height: 17)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chargeHelp: Text {
        guard let charged = screen.lastFullCharge else { return Text("") }
        return Text("Last at 100% on \(Self.fullDateTime(charged))")
    }

    private static func fullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMMHmm")
        return formatter.string(from: date)
    }

    /// The last week, most recent on the right. The oldest bar is dropped when
    /// the log window opened mid-session, because its total would be partial and
    /// would read as a genuinely quiet day.
    private var history: some View {
        let recent = Array(
            screen.days.dropFirst(screen.coversFullHistory ? 0 : 1).suffix(7)
        )
        let peak = max(recent.map(\.seconds).max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(recent) { day in
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(day.id == recent.last?.id
                              ? AnyShapeStyle(Color.green.gradient)
                              : AnyShapeStyle(Color.primary.opacity(0.14)))
                        .frame(height: max(2, 26 * day.seconds / peak))
                    Text(Self.weekday(day.date))
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.quaternary)
                }
                .frame(maxWidth: .infinity)
                .help("\(Self.fullDate(day.date)) · \(ScreenTimeReader.format(day.seconds))")
            }
        }
        .frame(height: 38, alignment: .bottom)
    }

    private static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    private static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        return formatter.string(from: date)
    }

    // MARK: – Hero

    private var hero: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(mgr.level)")
                        .font(.system(size: 38, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(mgr.levelColor.gradient)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5), value: mgr.level)
                    Text("%")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .offset(y: -2)
                }
                statusLabel
            }

            Spacer()

            Image(systemName: mgr.batteryIcon)
                .font(.system(size: 44, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(mgr.levelColor.gradient)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var statusLabel: some View {
        HStack(spacing: 5) {
            if mgr.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
                if let t = mgr.timeString {
                    Text("Full in \(t)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if mgr.isPluggedIn {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("Charged")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if let t = mgr.timeString {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("\(t) left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: – Stats grid

    private var stats: some View {
        HStack(spacing: 0) {
            statCell(
                icon: "heart.fill",
                label: "Health",
                value: mgr.healthPercent.map { "\($0)%" } ?? "—",
                color: healthColor
            )
            Divider().frame(height: 40).opacity(0.12)
            statCell(
                icon: "arrow.clockwise",
                label: "Cycles",
                value: mgr.cycleCount.map { "\($0)" } ?? "—",
                color: .secondary
            )
            Divider().frame(height: 40).opacity(0.12)
            statCell(
                icon: "bolt.horizontal.fill",
                label: "Capacity",
                value: capacityString,
                color: .secondary
            )
        }
        .padding(.vertical, 12)
    }

    private func statCell(icon: String, label: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color == .secondary ? Color.primary : color)
        }
        .frame(maxWidth: .infinity)
    }

    private var healthColor: Color {
        guard let h = mgr.healthPercent else { return .secondary }
        switch h {
        case 85...: return .green
        case 70..<85: return .yellow
        default: return .red
        }
    }

    private var capacityString: String {
        if let m = mgr.rawMaxCapacity, let d = mgr.designCapacity {
            return "\(m)/\(d)"
        }
        return "—"
    }
}
