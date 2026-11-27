import AppKit
import SwiftUI

struct ShortcutsView: View {
    @ObservedObject private var mgr = ShortcutsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            DeckModuleToolbar {
                Text("\(mgr.items.count) shortcuts")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            } trailing: {
                DeckIconButton(
                    symbol: "arrow.clockwise",
                    size: 22,
                    iconSize: 10,
                    weight: .semibold,
                    action: { mgr.reload() }
                )
                .disabled(mgr.isLoading)
                .opacity(mgr.isLoading ? 0.45 : 1)
            }

            if mgr.isLoading && mgr.items.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if mgr.items.isEmpty {
                DeckEmptyState(
                    symbol: "square.stack.3d.up.slash",
                    tint: .purple,
                    title: "No shortcuts yet",
                    minHeight: 220
                ) {
                    DeckActionButton(
                        variant: .tinted(.purple),
                        cornerRadius: 16,
                        horizontalPadding: 12,
                        verticalPadding: 5
                    ) {
                        NSWorkspace.shared.open(URL(string: "shortcuts://")!)
                    } label: {
                        Text("Open Shortcuts")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                }
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(mgr.items) { item in
                            ShortcutRow(item: item, state: mgr.runState) {
                                mgr.run(item)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }

            statusLine
        }
        .onAppear { mgr.loadIfNeeded() }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch mgr.runState {
        case .idle, .running:
            EmptyView()
        case .succeeded(let name):
            DeckStatusBanner(
                icon: "checkmark.circle.fill",
                tint: .green,
                title: Text("\(name) finished")
            )
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.bottom, 8)
        case .failed(_, let message):
            DeckStatusBanner(
                icon: "exclamationmark.triangle.fill",
                tint: .orange,
                title: Text(message)
            )
            .padding(.horizontal, DeckMetrics.horizontalPadding)
            .padding(.bottom, 8)
        }
    }
}

// MARK: – Row

private struct ShortcutRow: View {
    let item: ShortcutsManager.Item
    let state: ShortcutsManager.RunState
    let onRun: () -> Void

    private var isRunning: Bool {
        if case .running(let name) = state { return name == item.name }
        return false
    }

    var body: some View {
        Button(action: onRun) {
            DeckHoverRow(
                horizontalPadding: 8,
                verticalPadding: 6,
                horizontalInset: 6,
                isSelected: isRunning,
                tint: .purple
            ) { isHovered in
                HStack(spacing: 9) {
                    DeckIconBadge(
                        symbol: "square.stack.3d.up.fill",
                        tint: .purple,
                        size: 22,
                        iconSize: 10.5,
                        cornerRadius: 6
                    )

                    Text(item.name)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if isRunning {
                        ProgressView().controlSize(.small).scaleEffect(0.6)
                    } else if isHovered {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.purple)
                    }
                }
            }
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
    }
}
