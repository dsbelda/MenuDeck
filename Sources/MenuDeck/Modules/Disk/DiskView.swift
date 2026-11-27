import SwiftUI

struct DiskView: View {
    @StateObject private var mgr = DiskManager()

    var body: some View {
        VStack(spacing: 8) {
            if mgr.volumes.isEmpty {
                DeckEmptyState(
                    symbol: "internaldrive",
                    tint: .orange,
                    title: "Reading volumes…",
                    minHeight: DeckMetrics.moduleHeight - 24
                )
            } else {
                let writable = mgr.volumes.filter { !$0.isReadOnly }
                let images = mgr.volumes.filter { $0.isReadOnly }

                ForEach(writable) { volume in
                    writableVolumeCard(volume)
                }

                if !images.isEmpty {
                    HStack {
                        DeckSectionHeader("Disk images", icon: "opticaldiscdrive", tint: .secondary)
                        if images.count > 1 {
                            Button {
                                mgr.ejectAllDiskImages()
                            } label: {
                                Text("Eject all")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                            .disabled(!mgr.ejectingIDs.isEmpty)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, writable.isEmpty ? 0 : 4)

                    DeckGroupedList(dividerInset: 42) {
                        ForEach(images) { volume in
                            diskImageRow(volume)
                        }
                    }
                }

                if let error = mgr.lastError {
                    DeckStatusBanner(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        title: Text(error)
                    )
                }
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    private func writableVolumeCard(_ volume: DiskManager.Volume) -> some View {
        let color = tint(for: volume)
        let pct = Int((volume.usedFraction * 100).rounded())
        let isEjecting = mgr.ejectingIDs.contains(volume.id)

        return DeckCard(padding: 11) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    DeckIconBadge(
                        symbol: volume.isEjectable ? "externaldrive.fill" : "internaldrive.fill",
                        tint: color,
                        size: 24,
                        iconSize: 11
                    )

                    VStack(alignment: .leading, spacing: 1) {
                        Text(volume.name)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Text("\(DiskManager.format(volume.free)) free of \(DiskManager.format(volume.total))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Text("\(pct)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(color)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2.5)
                        .background(color.opacity(0.12), in: Capsule())

                    if volume.isEjectable {
                        ejectControl(for: volume, isEjecting: isEjecting)
                    }
                }

                DeckProgressBar(fraction: volume.usedFraction, tint: color, height: 6)
            }
        }
    }

    private func diskImageRow(_ volume: DiskManager.Volume) -> some View {
        let isEjecting = mgr.ejectingIDs.contains(volume.id)

        return HStack(spacing: 9) {
            DeckIconBadge(
                symbol: "opticaldiscdrive.fill",
                tint: .secondary,
                size: 24,
                iconSize: 11,
                isActive: false
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(volume.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(DiskManager.format(volume.total))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if volume.isEjectable {
                ejectControl(for: volume, isEjecting: isEjecting)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    @ViewBuilder
    private func ejectControl(for volume: DiskManager.Volume, isEjecting: Bool) -> some View {
        if isEjecting {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.6)
                .frame(width: 24, height: 24)
        } else {
            DeckIconButton(
                symbol: "eject.fill",
                size: 24,
                iconSize: 10,
                tint: .secondary,
                hoverTint: .orange,
                restingFill: 0.06
            ) {
                mgr.eject(volume)
            }
            .help(Text("Eject"))
        }
    }

    private func tint(for volume: DiskManager.Volume) -> Color {
        if volume.isReadOnly { return .secondary }
        switch volume.usedFraction {
        case ..<0.75: return Color(red: 0.90, green: 0.62, blue: 0.06)
        case ..<0.90: return .orange
        default:      return .red
        }
    }
}
