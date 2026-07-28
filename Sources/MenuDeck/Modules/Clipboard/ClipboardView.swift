import SwiftUI

struct ClipboardView: View {
    @ObservedObject private var mgr = ClipboardManager.shared
    @State private var copiedId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if mgr.history.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
    }

    // MARK: – Toolbar

    private var toolbar: some View {
        HStack {
            Text("\(mgr.history.count) elemento\(mgr.history.count == 1 ? "" : "s")")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3)) { mgr.clear() }
            } label: {
                Text("Borrar todo")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.pink)
            }
            .buttonStyle(.plain)
            .opacity(mgr.history.isEmpty ? 0.3 : 1)
            .disabled(mgr.history.isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    // MARK: – Item list

    private var itemList: some View {
        VStack(spacing: 0) {
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
                if item.id != mgr.history.last?.id {
                    Divider().padding(.leading, 14).opacity(0.07)
                }
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            Text("Historial vacío")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Copia algo para verlo aquí")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

// MARK: – Row

private struct ClipboardRow: View {
    let item: ClipboardItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    /// Allocating a formatter is expensive, and this is read from body — once
    /// per row, per frame. Built once instead.
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
        HStack(spacing: 0) {
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.system(size: 11))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundStyle(.primary)
                Text(relativeTime)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)

            // Action buttons (appear on hover)
            if isHovered {
                HStack(spacing: 4) {
                    // Copy
                    Button(action: onCopy) {
                        Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(isCopied ? .green : .secondary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .contentTransition(.symbolEffect(.replace))

                    // Delete
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .padding(.horizontal, 14)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture(perform: onCopy)
        .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
