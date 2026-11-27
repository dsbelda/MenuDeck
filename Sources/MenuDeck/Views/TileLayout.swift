import SwiftUI

/// How the module tiles are arranged on the main panel.
enum TileLayout: String, CaseIterable, Identifiable {
    /// Icon over a label, four to a row. The most legible, and the default.
    case grid
    /// Icons only, six to a row — half the height of `grid`.
    case icons
    /// One module per row, icon beside label. Reads like a native menu.
    case list
    /// A single icons-only strip that scrolls sideways. The smallest the panel
    /// can get: the tiles never take more than one row however many are on.
    case row

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .grid:  "Grid"
        case .icons: "Icons only"
        case .list:  "List"
        case .row:   "Single row"
        }
    }

    var sfSymbol: String {
        switch self {
        case .grid:  "square.grid.2x2"
        case .icons: "square.grid.3x3"
        case .list:  "list.bullet"
        case .row:   "rectangle.split.3x1"
        }
    }

    var columns: Int {
        switch self {
        case .grid:  4
        case .icons: 6
        case .list:  1
        case .row:   0   // not a grid
        }
    }
}

// MARK: – Tiles

/// Control Center–style card tile: tinted icon badge over a crisp label.
struct ModuleGridTile: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: module.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(module.tintColor)
                    .frame(width: 28, height: 28)
                    .background(
                        module.tintColor.opacity(isSelected ? 0.22 : (isHovered ? 0.18 : 0.13)),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .contentTransition(.symbolEffect(.replace))

                Text(module.name)
                    .font(.system(size: 9.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || isHovered ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 3)
            .background(TileSurface(
                tint: module.tintColor,
                isSelected: isSelected,
                isHovered: isHovered,
                cornerRadius: 10,
                hasRestingCard: true
            ))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(DeckPressStyle(scale: 0.96))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

/// Icon alone in a tactile squircle — or, with `showsName`, an active pill with the name beside it.
struct ModuleIconTile: View {
    let module: any Module
    let isSelected: Bool
    var showsName = false
    var compact = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: module.sfSymbol)
                    .font(.system(size: compact ? 13.5 : 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(module.tintColor)
                if showsName {
                    Text(module.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, showsName ? 9 : 0)
            .frame(maxWidth: showsName ? nil : .infinity)
            .frame(height: compact ? 30 : 34)
            .background(TileSurface(
                tint: module.tintColor,
                isSelected: isSelected,
                isHovered: isHovered,
                cornerRadius: 8,
                hasRestingCard: !compact
            ))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(DeckPressStyle(scale: 0.95))
        .help(Text(module.name))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

/// Icon badge beside label, one per row.
struct ModuleListRow: View {
    let module: any Module
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                DeckIconBadge(
                    symbol: module.sfSymbol,
                    tint: module.tintColor,
                    size: 22,
                    iconSize: 11,
                    isActive: true,
                    cornerRadius: 6
                )

                Text(module.name)
                    .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected || isHovered ? .primary : .secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isSelected ? 90 : 0))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(TileSurface(
                tint: module.tintColor,
                isSelected: isSelected,
                isHovered: isHovered,
                cornerRadius: 8,
                hasRestingCard: false
            ))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(DeckPressStyle(scale: 0.985))
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.10), value: isHovered)
    }
}

// MARK: – Adaptive Tile Surface

private struct TileSurface: View {
    @Environment(\.colorScheme) private var scheme

    let tint: Color
    let isSelected: Bool
    let isHovered: Bool
    let cornerRadius: CGFloat
    let hasRestingCard: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(fillColor)
            .overlay(shape.strokeBorder(borderColor, lineWidth: 0.5))
            .shadow(
                color: (!isSelected && hasRestingCard && scheme == .light)
                    ? Color.black.opacity(0.035)
                    : .clear,
                radius: 2,
                y: 1
            )
    }

    private var fillColor: Color {
        if isSelected {
            return tint.opacity(scheme == .dark ? 0.18 : 0.15)
        }
        if isHovered {
            return scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.92)
        }
        if hasRestingCard {
            return scheme == .dark ? Color.white.opacity(0.048) : Color.white.opacity(0.68)
        }
        return .clear
    }

    private var borderColor: Color {
        if isSelected {
            return tint.opacity(scheme == .dark ? 0.36 : 0.30)
        }
        if isHovered {
            return scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.10)
        }
        if hasRestingCard {
            return scheme == .dark ? Color.white.opacity(0.085) : Color.black.opacity(0.07)
        }
        return .clear
    }
}
