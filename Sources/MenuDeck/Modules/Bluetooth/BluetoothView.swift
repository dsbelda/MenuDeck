import SwiftUI

struct BluetoothView: View {
    @StateObject private var mgr = BluetoothManager()

    var body: some View {
        VStack(spacing: 0) {
            if mgr.devices.isEmpty {
                emptyState
            } else {
                ForEach(mgr.devices) { device in
                    row(device)
                    if device.id != mgr.devices.last?.id {
                        Divider().padding(.leading, 40).opacity(0.06)
                    }
                }
            }

            if let error = mgr.lastError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
        .onAppear    { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    private func row(_ device: BluetoothManager.Device) -> some View {
        Button {
            mgr.toggle(device)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: device.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(device.isConnected ? Color.blue : .secondary)
                    .frame(width: 18)

                Text(device.name)
                    .font(.system(size: 11, weight: device.isConnected ? .semibold : .regular))
                    .foregroundStyle(device.isConnected ? .primary : .secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                if mgr.busyAddress == device.address {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                } else if device.isConnected {
                    Text("Connected")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(mgr.busyAddress != nil)
        .help(device.isConnected ? "Click to disconnect" : "Click to connect")
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("No paired devices")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}
