import SwiftUI

struct AudioOutputView: View {
    @StateObject private var mgr = AudioOutputManager()

    var body: some View {
        VStack(spacing: 0) {
            if mgr.devices.isEmpty {
                DeckEmptyState(
                    symbol: "speaker.slash",
                    tint: .blue,
                    title: "No output devices",
                    minHeight: DeckMetrics.moduleHeight - 24
                )
            } else {
                DeckCard(padding: 4) {
                    VStack(spacing: 2) {
                        ForEach(mgr.devices) { device in
                            row(device)
                        }
                    }
                }
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    private func row(_ device: AudioOutputManager.Device) -> some View {
        let isCurrent = device.id == mgr.currentID
        return Button {
            mgr.select(device)
        } label: {
            DeckHoverRow(
                horizontalPadding: 8,
                verticalPadding: 7,
                horizontalInset: 0,
                isSelected: isCurrent,
                tint: .blue
            ) { _ in
                HStack(spacing: 9) {
                    DeckIconBadge(
                        symbol: device.symbol,
                        tint: .blue,
                        size: 24,
                        iconSize: 11.5,
                        isActive: isCurrent
                    )

                    Text(device.name)
                        .font(.system(size: 11.5, weight: isCurrent ? .semibold : .medium))
                        .foregroundStyle(isCurrent ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.blue)
                    }
                }
            }
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
    }
}
