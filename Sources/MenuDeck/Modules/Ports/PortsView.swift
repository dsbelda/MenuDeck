import SwiftUI

struct PortsView: View {
    @StateObject private var mgr = PortsManager()
    @State private var pendingKill: Int?

    var body: some View {
        VStack(spacing: 0) {
            DeckModuleToolbar {
                Text("\(mgr.listeners.count) listening")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            } trailing: {
                DeckIconButton(
                    symbol: "arrow.clockwise",
                    size: 22,
                    iconSize: 10,
                    weight: .semibold,
                    action: { mgr.refresh() }
                )
                .disabled(mgr.isLoading)
                .opacity(mgr.isLoading ? 0.45 : 1)
            }

            if mgr.listeners.isEmpty {
                DeckEmptyState(
                    symbol: "network.badge.shield.half.filled",
                    tint: .indigo,
                    title: "Nothing is listening",
                    minHeight: 220
                )
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(mgr.listeners) { listener in
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
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            if let error = mgr.lastError {
                DeckStatusBanner(
                    icon: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: Text(error)
                )
                .padding(.horizontal, DeckMetrics.horizontalPadding)
                .padding(.bottom, 8)
            }
        }
        .whileShown(mgr.start, stop: mgr.stop)
    }
}

// MARK: – Row

private struct PortRow: View {
    let listener: PortsManager.Listener
    let isPendingKill: Bool
    let onRequestKill: () -> Void
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        if isPendingKill {
            confirmation
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
        } else {
            DeckHoverRow(horizontalPadding: 8, verticalPadding: 6, horizontalInset: 6) { isHovered in
                HStack(spacing: 9) {
                    Text(verbatim: ":\(listener.port)")
                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.indigo)
                        .frame(width: 54)
                        .padding(.vertical, 3.5)
                        .background(
                            Color.indigo.opacity(0.13),
                            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 1.5) {
                        Text(listener.command)
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                        Text(verbatim: "\(listener.address) · pid \(listener.pid)")
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if isHovered && listener.isOwnedByUser {
                        DeckIconButton(
                            symbol: "stop.circle.fill",
                            size: 22,
                            iconSize: 12,
                            hoverTint: .red,
                            action: onRequestKill
                        )
                        .help("Stop this process")
                    }
                }
            }
        }
    }

    private var confirmation: some View {
        HStack(spacing: 6) {
            Text("Stop \(listener.command)?")
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            DeckActionButton(
                variant: .neutral,
                cornerRadius: 6,
                horizontalPadding: 8,
                verticalPadding: 4,
                action: onCancel
            ) {
                Text("Cancel").font(.system(size: 10, weight: .medium))
            }

            DeckActionButton(
                variant: .solid(.red),
                cornerRadius: 6,
                horizontalPadding: 8,
                verticalPadding: 4,
                action: onConfirm
            ) {
                Text("Stop").font(.system(size: 10, weight: .semibold))
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.red.opacity(0.20), lineWidth: 0.5)
        )
    }
}
