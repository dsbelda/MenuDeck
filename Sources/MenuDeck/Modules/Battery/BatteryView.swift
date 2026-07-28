import SwiftUI

struct BatteryView: View {
    @StateObject private var mgr = BatteryManager()

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider().opacity(0.08)
            stats
        }
        .onAppear  { mgr.start() }
        .onDisappear { mgr.stop() }
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
