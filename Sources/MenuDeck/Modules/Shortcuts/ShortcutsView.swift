import AppKit
import SwiftUI

struct ShortcutsView: View {
    @ObservedObject private var mgr = ShortcutsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().opacity(0.08)

            if mgr.isLoading && mgr.items.isEmpty {
                ProgressView().controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
            } else if mgr.items.isEmpty {
                emptyState
            } else {
                ForEach(mgr.items) { item in
                    row(item)
                    if item.id != mgr.items.last?.id {
                        Divider().padding(.leading, 12).opacity(0.06)
                    }
                }
            }

            statusLine
        }
        .padding(.bottom, 4)
        .onAppear { mgr.loadIfNeeded() }
    }

    private var toolbar: some View {
        HStack {
            Text("\(mgr.items.count) shortcuts")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button { mgr.reload() } label: {
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

    private func row(_ item: ShortcutsManager.Item) -> some View {
        ShortcutRow(item: item, state: mgr.runState) { mgr.run(item) }
    }

    @ViewBuilder
    private var statusLine: some View {
        switch mgr.runState {
        case .idle, .running:
            EmptyView()
        case .succeeded(let name):
            status(icon: "checkmark.circle.fill", tint: .green, text: Text("\(name) finished"))
        case .failed(_, let message):
            status(icon: "exclamationmark.triangle.fill", tint: .orange, text: Text(message))
        }
    }

    private func status(icon: String, tint: Color, text: Text) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(tint)
            text
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 24, weight: .light))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tertiary)
            Text("No shortcuts yet")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Button {
                NSWorkspace.shared.open(URL(string: "shortcuts://")!)
            } label: {
                Text("Open Shortcuts")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.purple)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

// MARK: – Row

private struct ShortcutRow: View {
    let item: ShortcutsManager.Item
    let state: ShortcutsManager.RunState
    let onRun: () -> Void

    @State private var isHovered = false

    private var isRunning: Bool {
        if case .running(let name) = state { return name == item.name }
        return false
    }

    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 9) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 11))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.purple)
                    .frame(width: 16)

                Text(item.name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if isRunning {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                } else if isHovered {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isHovered ? Color.primary.opacity(0.04) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
