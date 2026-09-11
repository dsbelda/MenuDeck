import SwiftUI

struct ColorPickerView: View {
    @ObservedObject private var mgr = ColorPickerManager.shared
    @State private var copiedId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            pickButton
            Divider().opacity(0.08)
            if mgr.history.isEmpty {
                emptyState
            } else {
                header
                swatchGrid
            }
        }
    }

    // MARK: – Pick

    private var pickButton: some View {
        Button {
            mgr.pick()
            // The loupe is a system overlay; leaving the popover up behind it
            // just steals the first click when the user comes back.
            NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 14, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text("Pick a colour")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.purple)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.20), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: – History

    private var header: some View {
        HStack {
            Text("Recent")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.4)
            Spacer()
            Button {
                mgr.clear()
            } label: {
                Text("Clear all")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.purple)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private var swatchGrid: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
        return LazyVGrid(columns: cols, spacing: 6) {
            ForEach(mgr.history) { swatch in
                Button {
                    mgr.copy(swatch)
                    copiedId = swatch.id
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        if copiedId == swatch.id { copiedId = nil }
                    }
                } label: {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(swatch.color)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .overlay {
                            if copiedId == swatch.id {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(swatch.hex)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("No colours yet")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Picked colours are copied as HEX")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}
