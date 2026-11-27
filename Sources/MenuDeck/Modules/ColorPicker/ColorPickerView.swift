import SwiftUI

struct ColorPickerView: View {
    @ObservedObject private var mgr = ColorPickerManager.shared
    @State private var copiedId: UUID?
    @State private var hoveredSwatch: ColorPickerManager.Swatch?

    var body: some View {
        VStack(spacing: 10) {
            pickButton

            if mgr.history.isEmpty {
                DeckEmptyState(
                    symbol: "eyedropper",
                    tint: .purple,
                    title: "No colours yet",
                    subtitle: "Picked colours are copied as HEX",
                    minHeight: 175
                )
            } else {
                historyCard
            }
        }
        .padding(DeckMetrics.horizontalPadding)
    }

    // MARK: – Pick

    private var pickButton: some View {
        DeckActionButton(
            variant: .tinted(.purple),
            cornerRadius: 11,
            verticalPadding: 11,
            fullWidth: true
        ) {
            mgr.pick()
            NotificationCenter.default.post(name: .menuDeckClosePopover, object: nil)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "eyedropper.halffull")
                    .font(.system(size: 14, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text("Pick a colour")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    // MARK: – History

    private var historyCard: some View {
        DeckCard(padding: 11) {
            VStack(spacing: 9) {
                HStack(spacing: 6) {
                    if let hovered = hoveredSwatch {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(hovered.color)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().strokeBorder(.primary.opacity(0.2), lineWidth: 0.5))
                            Text(hovered.hex)
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                    } else {
                        Text("Recent")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { mgr.clear() }
                    } label: {
                        Text("Clear all")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                }

                let cols = Array(repeating: GridItem(.flexible(), spacing: 7), count: 6)
                LazyVGrid(columns: cols, spacing: 7) {
                    ForEach(mgr.history) { swatch in
                        SwatchCell(
                            swatch: swatch,
                            isCopied: copiedId == swatch.id,
                            onHover: { hovering in
                                hoveredSwatch = hovering ? swatch : (hoveredSwatch?.id == swatch.id ? nil : hoveredSwatch)
                            }
                        ) {
                            mgr.copy(swatch)
                            copiedId = swatch.id
                            Task {
                                try? await Task.sleep(for: .seconds(1.2))
                                if copiedId == swatch.id { copiedId = nil }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct SwatchCell: View {
    let swatch: ColorPickerManager.Swatch
    let isCopied: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(swatch.color)
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.primary.opacity(isHovered ? 0.35 : 0.14), lineWidth: isHovered ? 1 : 0.5)
                )
                .overlay {
                    if isCopied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9.5, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.45), in: Circle())
                    }
                }
                .scaleEffect(isHovered ? 1.07 : 1)
        }
        .buttonStyle(DeckPressStyle(scale: 0.93))
        .help(swatch.hex)
        .onHover { hovering in
            isHovered = hovering
            onHover(hovering)
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
