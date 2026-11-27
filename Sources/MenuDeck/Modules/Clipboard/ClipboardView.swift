import SwiftUI

struct ClipboardView: View {
    @ObservedObject private var mgr = ClipboardManager.shared
    @State private var copiedId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            DeckModuleToolbar {
                Text("\(mgr.history.count) items")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.secondary)
            } trailing: {
                Button {
                    withAnimation(.spring(response: 0.3)) { mgr.clear() }
                } label: {
                    Text("Clear all")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(.pink)
                }
                .buttonStyle(.plain)
                .opacity(mgr.history.isEmpty ? 0.35 : 1)
                .disabled(mgr.history.isEmpty)
            }

            if mgr.history.isEmpty {
                DeckEmptyState(
                    symbol: "doc.on.clipboard",
                    tint: .pink,
                    title: "No history yet",
                    subtitle: "Copy something to see it here",
                    minHeight: 220
                )
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 2) {
                        ForEach(mgr.history) { item in
                            ClipboardRow(
                                item: item,
                                isCopied: copiedId == item.id,
                                onCopy: {
                                    mgr.copy(item)
                                    withAnimation(.spring(response: 0.25)) { copiedId = item.id }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                        withAnimation { if copiedId == item.id { copiedId = nil } }
                                    }
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3)) { mgr.delete(item) }
                                }
                            )
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }
}

// MARK: – Row

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @MainActor
    private static let timeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private var relativeTime: String {
        Self.timeFormatter.localizedString(for: item.date, relativeTo: Date())
    }

    var body: some View {
        DeckHoverRow(
            horizontalPadding: 9,
            verticalPadding: 7,
            horizontalInset: 6,
            isSelected: isCopied,
            tint: .green
        ) { isHovered in
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2.5) {
                    Text(item.text)
                        .font(.system(size: 11.5))
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .foregroundStyle(.primary)
                    Text(relativeTime)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isCopied {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                        .transition(.scale.combined(with: .opacity))
                } else if isHovered {
                    HStack(spacing: 4) {
                        DeckIconButton(
                            symbol: "doc.on.doc",
                            size: 22,
                            iconSize: 10.5,
                            hoverTint: .pink,
                            action: onCopy
                        )

                        DeckIconButton(
                            symbol: "trash",
                            size: 22,
                            iconSize: 10.5,
                            hoverTint: .red,
                            action: onDelete
                        )
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
        }
        .onTapGesture(perform: onCopy)
    }
}
