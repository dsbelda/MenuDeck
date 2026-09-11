import SwiftUI

struct PortsView: View {
    @StateObject private var mgr = PortsManager()
    @State private var pendingKill: Int?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.08)

            if mgr.listeners.isEmpty {
                emptyState
            } else {
                ForEach(mgr.listeners) { listener in
                    row(listener)
                    if listener.id != mgr.listeners.last?.id {
                        Divider().padding(.leading, 12).opacity(0.06)
                    }
                }
            }

            if let error = mgr.lastError {
                Text(error)
                    .font(.system(size: 9))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
            }
        }
        .padding(.bottom, 4)
        .onAppear    { mgr.start() }
        .onDisappear { mgr.stop() }
    }

    private var toolbar: some View {
        HStack {
            Text("\(mgr.listeners.count) listening")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button { mgr.refresh() } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .disabled(mgr.isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private func row(_ listener: PortsManager.Listener) -> some View {
        PortRow(
            listener: listener,
            isPendingKill: pendingKill == listener.id,
            onRequestKill: { pendingKill = listener.id },
            onCancel: { pendingKill = nil },
            onConfirm: {
                pendingKill = nil
                mgr.quit(listener)
            }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "app.dashed")
                .font(.system(size: 24, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("Nothing is listening")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
    }
}

// MARK: – Row

private struct PortRow: View {
    let listener: PortsManager.Listener
    let isPendingKill: Bool
    let onRequestKill: () -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    @State private var isHovered = false

    var body: some View {
        Group {
            if isPendingKill {
                confirmation
            } else {
                normal
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered && !isPendingKill ? Color.primary.opacity(0.04) : .clear)
        .onHover { isHovered = $0 }
    }

    private var normal: some View {
        HStack(spacing: 9) {
            Text("\(listener.port)")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.indigo)
                .frame(width: 46, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(listener.command)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text("\(listener.address) · pid \(listener.pid)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if isHovered && listener.isOwnedByUser {
                Button(action: onRequestKill) {
                    Image(systemName: "stop.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Stop this process")
            }
        }
    }

    private var confirmation: some View {
        HStack(spacing: 8) {
            Text("Stop \(listener.command)?")
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Button("Stop", action: onConfirm)
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.red)
        }
    }
}
