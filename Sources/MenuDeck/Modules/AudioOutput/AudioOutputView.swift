import SwiftUI

struct AudioOutputView: View {
    @StateObject private var mgr = AudioOutputManager()

    var body: some View {
        VStack(spacing: 0) {
            if mgr.devices.isEmpty {
                emptyState
            } else {
                ForEach(mgr.devices) { device in
                    row(device)
                    if device.id != mgr.devices.last?.id {
                        Divider().padding(.leading, 40).opacity(0.07)
                    }
                }
            }
        }
        .padding(.vertical, 6)
        .onAppear    { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    private func row(_ device: AudioOutputManager.Device) -> some View {
        let isCurrent = device.id == mgr.currentID
        return Button {
            mgr.select(device)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: device.symbol)
                    .font(.system(size: 13, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isCurrent ? Color.blue : .secondary)
                    .frame(width: 18)

                Text(device.name)
                    .font(.system(size: 11, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "speaker.slash")
                .font(.system(size: 26, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("No output devices")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
