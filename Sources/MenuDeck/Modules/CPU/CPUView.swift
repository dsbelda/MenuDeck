import SwiftUI

struct CPUView: View {
    @StateObject private var mgr = CPUManager()

    var body: some View {
        VStack(spacing: 10) {
            cpuCard
            memoryCard
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    // MARK: – CPU

    private var cpuCard: some View {
        DeckCard(padding: 11) {
            VStack(spacing: 10) {
                DeckSectionHeader("CPU", icon: "cpu", tint: .indigo) {
                    Text(String(format: "%.0f%%", mgr.avgPercent))
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.indigo)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.indigo.opacity(0.12), in: Capsule())
                }

                let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
                LazyVGrid(columns: cols, spacing: 6) {
                    ForEach(mgr.cores) { core in
                        CoreBar(index: core.id, percent: core.percent)
                    }
                }
            }
        }
    }

    // MARK: – Memory

    private var memoryCard: some View {
        DeckCard(padding: 11) {
            VStack(spacing: 9) {
                DeckSectionHeader("Memory", icon: "memorychip", tint: .purple) {
                    Text(String(format: "%.0f GB", mgr.memory.totalGB))
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                stackedMemoryBar

                VStack(spacing: 6) {
                    MemRow(label: "In use", value: mgr.memory.appGB, total: mgr.memory.totalGB, color: .indigo)
                    MemRow(label: "Wired",  value: mgr.memory.wiredGB, total: mgr.memory.totalGB, color: .purple)
                    MemRow(label: "Free",   value: mgr.memory.freeGB, total: mgr.memory.totalGB, color: .green)
                }
            }
        }
    }

    private var stackedMemoryBar: some View {
        let total = max(mgr.memory.totalGB, 0.001)
        let appFrac = min(max(mgr.memory.appGB / total, 0), 1)
        let wiredFrac = min(max(mgr.memory.wiredGB / total, 0), max(0, 1 - appFrac))

        return GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                HStack(spacing: 1.5) {
                    if appFrac > 0.005 {
                        Rectangle()
                            .fill(Color.indigo.gradient)
                            .frame(width: max(4, w * appFrac))
                    }
                    if wiredFrac > 0.005 {
                        Rectangle()
                            .fill(Color.purple.gradient)
                            .frame(width: max(4, w * wiredFrac))
                    }
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 7)
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
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 22, alignment: .leading)

            DeckProgressBar(fraction: percent / 100, tint: color, height: 5)

            Text(String(format: "%2.0f%%", percent))
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .trailing)
        }
    }
}

// MARK: – Memory Row

private struct MemRow: View {
    let label: LocalizedStringKey
    let value: Double
    let total: Double
    let color: Color

    private var percent: Int {
        guard total > 0 else { return 0 }
        return Int((value / total * 100).rounded())
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color.gradient)
                .frame(width: 7, height: 7)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Text("\(percent)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 32, alignment: .trailing)

            Text(String(format: "%.1f GB", value))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .frame(width: 52, alignment: .trailing)
        }
    }
}
