import SwiftUI

struct TrashView: View {
    @StateObject private var mgr = TrashManager()
    @State private var isConfirming = false

    var body: some View {
        VStack(spacing: 0) {
            switch mgr.access {
            case .unknown:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: DeckMetrics.moduleHeight - 24)
            case .denied:
                permissionState
            case .granted:
                contents
            }
        }
        .padding(DeckMetrics.horizontalPadding)
        .whileShown { mgr.refresh() }
    }

    // MARK: – Granted

    private var contents: some View {
        let hasItems = mgr.contents.itemCount > 0
        return VStack(spacing: 12) {
            DeckCard(padding: 16) {
                VStack(spacing: 8) {
                    DeckIconBadge(
                        symbol: hasItems ? "trash.fill" : "trash",
                        tint: hasItems ? .red : .secondary,
                        size: 40,
                        iconSize: 18,
                        isActive: hasItems,
                        cornerRadius: 11
                    )

                    Text(TrashManager.format(mgr.contents.byteSize))
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(hasItems ? Color.primary : Color.secondary)
                        .contentTransition(.numericText())

                    Text("\(mgr.contents.itemCount) items in the Trash")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            if hasItems {
                if isConfirming {
                    confirmation
                } else {
                    actions
                }
            } else {
                Text("Nothing to empty")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: DeckMetrics.moduleHeight - 24)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            DeckActionButton(variant: .neutral, cornerRadius: 9, verticalPadding: 8, fullWidth: true) {
                mgr.openInFinder()
            } label: {
                Label("Open", systemImage: "folder")
                    .font(.system(size: 11.5, weight: .medium))
            }

            DeckActionButton(variant: .tinted(.red), cornerRadius: 9, verticalPadding: 8, fullWidth: true) {
                withAnimation(.easeOut(duration: 0.15)) { isConfirming = true }
            } label: {
                Label("Empty", systemImage: "trash")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .disabled(mgr.isEmptying)
        }
    }

    private var confirmation: some View {
        DeckCard(radius: 10, padding: 10) {
            VStack(spacing: 8) {
                Text("Permanently delete \(mgr.contents.itemCount) items?")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 8) {
                    DeckActionButton(variant: .neutral, cornerRadius: 8, verticalPadding: 7, fullWidth: true) {
                        withAnimation(.easeOut(duration: 0.15)) { isConfirming = false }
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .medium))
                    }

                    DeckActionButton(variant: .solid(.red), cornerRadius: 8, verticalPadding: 7, fullWidth: true) {
                        isConfirming = false
                        mgr.empty()
                    } label: {
                        Text("Delete")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
            }
        }
    }

    // MARK: – Denied

    private var permissionState: some View {
        DeckEmptyState(
            symbol: "lock.fill",
            tint: .orange,
            title: "Full Disk Access needed",
            subtitle: "macOS protects the Trash folder even inside your home directory.",
            minHeight: DeckMetrics.moduleHeight - 24
        ) {
            DeckActionButton(variant: .tinted(.orange), cornerRadius: 16, horizontalPadding: 12, verticalPadding: 6) {
                mgr.openFullDiskAccessSettings()
            } label: {
                Text("Open Privacy settings")
                    .font(.system(size: 10.5, weight: .semibold))
            }
        }
    }
}
