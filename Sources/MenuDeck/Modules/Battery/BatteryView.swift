import SwiftUI

struct BatteryView: View {
    @StateObject private var mgr = BatteryManager()
    @ObservedObject private var screen = ScreenTimeReader.shared

    var body: some View {
        VStack(spacing: 10) {
            hero
            statsCard
            screenTimeCard
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown({ mgr.start(); screen.load() }, stop: mgr.stop)
    }

    // MARK: – Hero

    private var hero: some View {
        DeckCard(padding: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(mgr.level)")
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(mgr.levelColor.gradient)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.45), value: mgr.level)
                        Text("%")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    statusLabel
                }

                Spacer()

                Image(systemName: mgr.batteryIcon)
                    .font(.system(size: 38, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(mgr.levelColor.gradient)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 5) {
            if mgr.isCharging {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.green)
                if let t = mgr.timeString {
                    Text("Full in \(t)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            } else if mgr.isPluggedIn {
                Image(systemName: "powerplug.fill")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Charged")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            } else if let t = mgr.timeString {
                Image(systemName: "clock")
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(t) left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: – Stats card

    private var statsCard: some View {
        DeckCard {
            HStack(spacing: 0) {
                statCell(
                    icon: "heart.fill",
                    label: "Health",
                    value: mgr.healthPercent.map { "\($0)%" } ?? "—",
                    color: healthColor
                )
                Divider().frame(height: 34).opacity(0.12)
                statCell(
                    icon: "arrow.clockwise",
                    label: "Cycles",
                    value: mgr.cycleCount.map { "\($0)" } ?? "—",
                    color: .secondary
                )
                Divider().frame(height: 34).opacity(0.12)
                statCell(
                    icon: "bolt.horizontal.fill",
                    label: "Capacity",
                    value: capacityString,
                    color: .secondary
                )
            }
            .padding(.vertical, 10)
        }
    }

    private func statCell(icon: String, label: LocalizedStringKey, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(color == .secondary ? Color.primary : color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
    }

    // MARK: – Screen-on time card

    private var screenTimeCard: some View {
        DeckCard(padding: 10) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 0) {
                    screenCell(
                        icon: "sun.max.fill",
                        tint: .orange,
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
                    DeckHairline()
                    history
                }
            }
        }
    }

    private func screenCell(
        icon: String, tint: Color, label: LocalizedStringKey, value: String?
    ) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.35)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            if let value {
                Text(value)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded).monospacedDigit())
                    .contentTransition(.numericText())
            } else {
                ProgressView().controlSize(.small).scaleEffect(0.55).frame(height: 17)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var chargeHelp: Text {
        guard let charged = screen.lastFullCharge else { return Text("") }
        return Text("Last at 100% on \(Self.fullDateTimeFormatter.string(from: charged))")
    }

    /// The last week, most recent on the right.
    private var history: some View {
        let recent = Array(
            screen.days.dropFirst(screen.coversFullHistory ? 0 : 1).suffix(7)
        )
        let peak = max(recent.map(\.seconds).max() ?? 1, 1)

        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(recent) { day in
                let isToday = day.id == recent.last?.id
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(isToday
                              ? AnyShapeStyle(Color.green.gradient)
                              : AnyShapeStyle(Color.primary.opacity(0.15)))
                        .frame(height: max(3, 28 * day.seconds / peak))
                    Text(Self.weekdayFormatter.string(from: day.date))
                        .font(.system(size: 8, weight: isToday ? .bold : .medium))
                        .foregroundStyle(isToday ? .primary : .tertiary)
                }
                .frame(maxWidth: .infinity)
                .help("\(Self.fullDateFormatter.string(from: day.date)) · \(ScreenTimeReader.format(day.seconds))")
            }
        }
        .frame(height: 42, alignment: .bottom)
    }

    // MARK: – Helpers & cached formatters

    private var healthColor: Color {
        guard let h = mgr.healthPercent else { return .secondary }
        switch h {
        case 85...: return .green
        case 70..<85: return .orange
        default: return .red
        }
    }

    private var capacityString: String {
        if let m = mgr.rawMaxCapacity, let d = mgr.designCapacity {
            return "\(m)/\(d)"
        }
        return "—"
    }

    private static let fullDateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEdMMMHmm")
        return f
    }()

    private static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEE")
        return f
    }()

    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMM")
        return f
    }()
}
