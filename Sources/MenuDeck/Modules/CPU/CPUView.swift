import SwiftUI

struct CPUView: View {
    @StateObject private var mgr = CPUManager()

    var body: some View {
        VStack(spacing: 0) {
            cpuSection
            Divider().opacity(0.08)
            memorySection
        }
        .onAppear  { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    // MARK: – CPU

    private var cpuSection: some View {
        VStack(spacing: 10) {
            // Header row
            HStack {
                Label("CPU", systemImage: "cpu")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(String(format: "%.0f%%", mgr.avgPercent))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.indigo)
                    .contentTransition(.numericText())
                    .animation(.easeOut(duration: 0.4), value: mgr.avgPercent)
            }

            // Core grid — 2 columns
            let cols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(mgr.cores) { core in
                    CoreBar(index: core.id, percent: core.percent)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: – Memory

    private var memorySection: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Memoria", systemImage: "memorychip")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(String(format: "%.0f GB total", mgr.memory.totalGB))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 5) {
                MemBar(label: "En uso",
                       value: mgr.memory.appGB,
                       total: mgr.memory.totalGB,
                       color: .indigo)
                MemBar(label: "Cableada",
                       value: mgr.memory.wiredGB,
                       total: mgr.memory.totalGB,
                       color: .purple)
                MemBar(label: "Libre",
                       value: mgr.memory.freeGB,
                       total: mgr.memory.totalGB,
                       color: .green)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: – Core Bar

private struct CoreBar: View {
    let index: Int
    let percent: Double

    private var color: Color {
        switch percent {
        case ..<40: return .indigo
        case ..<70: return .orange
        default:    return .red
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text("C\(index + 1)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 18, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.07)).frame(height: 5)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(4, geo.size.width * percent / 100), height: 5)
                        .animation(.easeOut(duration: 0.4), value: percent)
                }
            }
            .frame(height: 5)

            Text(String(format: "%2.0f%%", percent))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.4), value: percent)
        }
    }
}

// MARK: – Memory Bar

private struct MemBar: View {
    let label: String
    let value: Double
    let total: Double
    let color: Color

    private var fraction: Double {
        guard total > 0 else { return 0 }
        return min(value / total, 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.07)).frame(height: 6)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(6, geo.size.width * fraction), height: 6)
                        .animation(.easeOut(duration: 0.5), value: fraction)
                }
            }
            .frame(height: 6)

            Text(String(format: "%.1f GB", value))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(color)
                .frame(width: 46, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.5), value: value)
        }
    }
}
