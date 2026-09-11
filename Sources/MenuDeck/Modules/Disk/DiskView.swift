import SwiftUI

struct DiskView: View {
    @StateObject private var mgr = DiskManager()

    var body: some View {
        VStack(spacing: 0) {
            if mgr.volumes.isEmpty {
                emptyState
            } else {
                ForEach(mgr.volumes) { volume in
                    row(volume)
                    if volume.id != mgr.volumes.last?.id {
                        Divider().padding(.horizontal, 14).opacity(0.07)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear    { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    private func row(_ volume: DiskManager.Volume) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(volume.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text("\(Int((volume.usedFraction * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(tint(for: volume.usedFraction))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule()
                        .fill(tint(for: volume.usedFraction).gradient)
                        .frame(width: max(4, geo.size.width * volume.usedFraction))
                }
            }
            .frame(height: 6)

            Text("\(DiskManager.format(volume.free)) free of \(DiskManager.format(volume.total))")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func tint(for fraction: Double) -> Color {
        switch fraction {
        case ..<0.75: .yellow
        case ..<0.90: .orange
        default:      .red
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "internaldrive")
                .font(.system(size: 26, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("Reading volumes…")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
