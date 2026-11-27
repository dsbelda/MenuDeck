import SwiftUI

struct BluetoothView: View {
    @StateObject private var mgr = BluetoothManager()

    var body: some View {
        VStack(spacing: 10) {
            if mgr.devices.isEmpty {
                DeckEmptyState(
                    symbol: "dot.radiowaves.left.and.right",
                    tint: .blue,
                    title: "No paired devices",
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

            if let error = mgr.lastError {
                DeckStatusBanner(
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: Text(error)
                )
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown(mgr.start, stop: mgr.stop)
    }

    private func row(_ device: BluetoothManager.Device) -> some View {
        Button {
            mgr.toggle(device)
        } label: {
            DeckHoverRow(
                horizontalPadding: 8,
                verticalPadding: 7,
                horizontalInset: 0,
                isSelected: device.isConnected,
                tint: .blue
            ) { _ in
                HStack(spacing: 9) {
                    DeckIconBadge(
                        symbol: device.symbol,
                        tint: .blue,
                        size: 24,
                        iconSize: 11.5,
                        isActive: device.isConnected
                    )

                    Text(device.name)
                        .font(.system(size: 11.5, weight: device.isConnected ? .semibold : .medium))
                        .foregroundStyle(device.isConnected ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    if mgr.busyAddress == device.address {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                    } else if device.isConnected {
                        Text("Connected")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(Color.blue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Color.blue.opacity(0.13), in: Capsule())
                    }
                }
            }
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
        .disabled(mgr.busyAddress != nil)
        .help(device.isConnected ? "Click to disconnect" : "Click to connect")
    }
}
